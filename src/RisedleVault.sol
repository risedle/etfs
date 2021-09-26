// SPDX-License-Identifier: GPL-3.0-or-later

// Risedle's Vault Contract
// The money market protocol that powers Risedle ETFs.
//
// The interest rate model is available here: https://observablehq.com/@pyk/ethrise
// Risedle uses ether units (1e18) precision to represent the interest rates.
// Learn more here: https://docs.soliditylang.org/en/v0.8.7/units-and-global-variables.html
//
// I wrote this for ETHOnline Hackathon 2021. Enjoy.

// Copyright (c) 2021 Bayu - All rights reserved
// github: pyk

pragma solidity ^0.8.7;
pragma experimental ABIEncoderV2;

import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessControl} from "lib/openzeppelin-contracts/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import {DSMath} from "lib/meth/src/math.sol";

/// @title Risedle's Vault
contract RisedleVault is ERC20, AccessControl, DSMath, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice Only valid borrower can borrow and repay underlying assets
    bytes32 public constant BORROWER_ROLE = keccak256("BORROWER_ROLE");

    /// @notice The underlying assets address contract (ERC20)
    address public immutable underlying;

    /// @notice The vault's admin address
    address public admin;

    /// @notice The vault token decimals
    uint8 private immutable _decimals;

    /// @notice The total amount of borrowed assets in the vault
    uint256 public totalBorrowed;

    /// @notice The total amount of collected fees in the vault
    uint256 public totalCollectedFees;

    /// @notice Optimal utilization rate in ether units
    uint256 public OPTIMAL_UTILIZATION_RATE_IN_ETHER;

    /// @notice Interest slope 1, stored in wad
    uint256 public INTEREST_SLOPE_1_IN_ETHER;

    /// @notice Interest slop 2, stored in wad
    uint256 public INTEREST_SLOPE_2_IN_ETHER;

    /// @notice Number of seconds in a year (approximation)
    uint256 public immutable TOTAL_SECONDS_IN_A_YEAR = 31536000;

    /// @notice 1.0 stored as wad, 1e18 precision
    uint256 public immutable ONE_WAD = 1000000000000000000;

    /// @notice Maximum borrow rate per second in ether units
    uint256 public immutable MAX_BORROW_RATE_PER_SECOND_IN_ETHER = 50735667174; // 0.000000050735667174% Approx 393% APY

    /// @notice Performance fee for the lender
    uint256 public PERFORMANCE_FEE_IN_ETHER = 0.1 ether; // 10% performance fee

    /// @notice Timestamp that interest was last accrued at
    uint256 public lastTimestampInterestAccrued;

    /// @notice Event emitted when the interest amount is invalid
    event InterestAmountInvalid(
        uint256 totalBorrowed,
        uint256 borrowRatePerSecondInEther,
        uint256 elapsedSeconds
    );

    /// @notice Event emitted when the vault states invalid
    event UpdateVaultStateFailed(uint256 interestAmount);

    /// @notice Event emitted when the interest succesfully accrued
    event InterestAccrued(
        uint256 previousTimestamp,
        uint256 currentTimestamp,
        uint256 previousTotalBorrowed,
        uint256 previousTotalCollectedFees,
        uint256 totalAvailable,
        uint256 utilizationRateInEther,
        uint256 borrowRatePerSecondInEther,
        uint256 elapsedSeconds,
        uint256 interestAmount,
        uint256 totalBorrowed,
        uint256 totalCollectedFees
    );

    /// @notice Event emitted when lender add supply to the vault
    event SupplyAdded(
        address indexed account,
        uint256 amount,
        uint256 exchangeRateWad,
        uint256 mintedAmount
    );

    /**
     * @notice Contruct new vault
     * @param name The vault's token name
     * @param symbol The vault's token symbol
     * @param underlying_ The ERC20 contract address of underlying asset
     * @param admin_ The vault's admin address
     */
    constructor(
        string memory name,
        string memory symbol,
        address underlying_,
        address admin_
    ) ERC20(name, symbol) {
        // Sanity check
        IERC20(underlying_).totalSupply();

        // Set underlying asset contract address
        underlying = underlying_;

        // Set vault token decimals similar to the underlying
        _decimals = IERC20Metadata(underlying_).decimals();

        // Setup admin role
        admin = admin_;
        _setupRole(DEFAULT_ADMIN_ROLE, admin_);

        // Set initial interest rate model parameters
        // See visualization here: https://observablehq.com/@pyk/ethrise
        OPTIMAL_UTILIZATION_RATE_IN_ETHER = 0.9 ether; // 90% utilization
        INTEREST_SLOPE_1_IN_ETHER = 0.2 ether; // 20% slope 1
        INTEREST_SLOPE_2_IN_ETHER = 0.6 ether; // 60% slope 2
    }

    /// @notice Overwrite the vault token decimals
    /// @dev https://docs.openzeppelin.com/contracts/4.x/erc20
    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    /**
     * @notice grantAsBorrower grants account access to borrow the underlying asset of RisedleUSD
     * @dev Only admin can call this function
     * @param account The contract address granted access to borrow
     */
    function grantAsBorrower(address account)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _setupRole(BORROWER_ROLE, account);
    }

    /**
     * @notice isBorrower returns true if account is borrower
     * @param account The contract address
     */
    function isBorrower(address account) public view returns (bool) {
        return hasRole(BORROWER_ROLE, account);
    }

    /**
     * @notice getTotalAvailableCash returns the total amount of underlying asset
     *         that available to borrow
     * @return The amount of underlying asset ready to borrow
     */
    function getTotalAvailableCash() internal view returns (uint256) {
        IERC20 underlyingToken = IERC20(underlying);
        uint256 underlyingBalance = underlyingToken.balanceOf(address(this));
        if (totalCollectedFees >= underlyingBalance) return 0;
        return underlyingBalance - totalCollectedFees;
    }

    /**
     * @notice getUtilizationRateInEther calculates the utilization rate of
     *         the vault.
     * @param available The amount of cash available to borrow in the vault
     * @param borrowed The amount of borrowed asset in the vault
     * @return The utilization rate in ether units
     */
    function getUtilizationRateInEther(uint256 available, uint256 borrowed)
        internal
        pure
        returns (uint256)
    {
        // Utilization rate is 0% when there is no borrowed asset
        if (borrowed == 0) return 0;

        // Utilization rate is 100% when there is no cash available
        if (available == 0 && borrowed > 0) return 1 ether;

        // utilization rate = amount borrowed / (amount available + amount borrowed)
        uint256 rateInEther = (borrowed * 1 ether) / (borrowed + available);
        return rateInEther;
    }

    /**
     * @notice getBorrowRatePerSecondInEther calculates the borrow rate per second
     *         in ether units
     * @param utilizationRateInEther The current utilization rate in ether units
     * @return The borrow rate per second in ether units
     */
    function getBorrowRatePerSecondInEther(uint256 utilizationRateInEther)
        internal
        view
        returns (uint256)
    {
        // utilizationRateInEther should in range [0, 1e18], Otherwise return max borrow rate
        if (utilizationRateInEther >= 1 ether) {
            return MAX_BORROW_RATE_PER_SECOND_IN_ETHER;
        }

        // Calculate the borrow rate
        // See the formula here: https://observablehq.com/@pyk  /ethrise
        if (utilizationRateInEther <= OPTIMAL_UTILIZATION_RATE_IN_ETHER) {
            // Borrow rate per year = (utilization rate/optimal utilization rate) * interest slope 1
            // Borrow rate per seconds = Borrow rate per year / seconds in a year
            uint256 rateInEther = (utilizationRateInEther * 1 ether) /
                OPTIMAL_UTILIZATION_RATE_IN_ETHER;
            uint256 borrowRatePerYearInEther = (rateInEther *
                INTEREST_SLOPE_1_IN_ETHER) / 1 ether;
            uint256 borrowRatePerSecondInEther = borrowRatePerYearInEther /
                TOTAL_SECONDS_IN_A_YEAR;
            return borrowRatePerSecondInEther;
        } else {
            // Borrow rate per year = interest slope 1 + ((utilization rate - optimal utilization rate)/(1-utilization rate)) * interest slope 2
            // Borrow rate per seconds = Borrow rate per year / seconds in a year
            uint256 aInEther = utilizationRateInEther -
                OPTIMAL_UTILIZATION_RATE_IN_ETHER;
            uint256 bInEther = 1 ether - utilizationRateInEther;
            uint256 cInEther = (aInEther * 1 ether) / bInEther;
            uint256 dInEther = (cInEther * INTEREST_SLOPE_2_IN_ETHER) / 1 ether;
            uint256 borrowRatePerYearInEther = INTEREST_SLOPE_1_IN_ETHER +
                dInEther;
            uint256 borrowRatePerSecondInEther = borrowRatePerYearInEther /
                TOTAL_SECONDS_IN_A_YEAR;
            // Cap the borrow rate
            if (
                borrowRatePerSecondInEther >=
                MAX_BORROW_RATE_PER_SECOND_IN_ETHER
            ) {
                return MAX_BORROW_RATE_PER_SECOND_IN_ETHER;
            }

            return borrowRatePerSecondInEther;
        }
    }

    /**
     * @notice getInterestAmount calculate amount of interest based on the total
     *         borrowed and borrow rate per second.
     * @param borrowedAmount Total of borrowed amount, in underlying decimals
     * @param borrowRatePerSecondInEther Borrow rates per second in ether units
     * @param elapsedSeconds Number of seconds elapsed since last accrued
     * @return The total interest amount, it have similar decimals with
     *         totalBorrowed and totalCollectedFees.
     */
    function getInterestAmount(
        uint256 borrowedAmount,
        uint256 borrowRatePerSecondInEther,
        uint256 elapsedSeconds
    ) internal pure returns (uint256) {
        // Early returns
        if (
            borrowedAmount == 0 ||
            borrowRatePerSecondInEther == 0 ||
            elapsedSeconds == 0
        ) {
            return 0;
        }

        // Calculate the amount of interest
        // interest amount = borrowRatePerSecondInEther * elapsedSeconds * borrowedAmount
        uint256 interestAmount = (borrowRatePerSecondInEther *
            elapsedSeconds *
            borrowedAmount) / 1 ether;
        return interestAmount;
    }

    /**
     * @notice updateVaultStates update the totalBorrowed and totalCollectedFees
     * @param interestAmount The total of interest amount to be splitted, the decimals
     *        is similar to totalBorrowed and totalCollectedFees.
     */
    function updateVaultStates(uint256 interestAmount) internal {
        // Get the fee
        uint256 feeAmount = (PERFORMANCE_FEE_IN_ETHER * interestAmount) /
            1 ether;

        // Get the borrow interest
        uint256 borrowInterestAmount = interestAmount - feeAmount;

        // Update the states
        totalBorrowed = totalBorrowed + borrowInterestAmount;
        totalCollectedFees = totalCollectedFees + feeAmount;
    }

    /**
     * @notice accrueInterest accrues interest to totalBorrowed and totalCollectedFees
     * @dev This calculates interest accrued from the last checkpointed timestamp
     *      up to the current timestamp and writes new checkpoint to storage.
     */
    function accrueInterest() public returns (bool invalid) {
        // Get the current timestamp, get last timestamp accrued and set the last time accrued
        uint256 currentTimestamp = block.timestamp;
        uint256 previousTimestamp = lastTimestampInterestAccrued;

        // If currentTimestamp and previousTimestamp is similar then return early
        if (currentTimestamp == previousTimestamp) return false;

        // For logging purpose
        uint256 previousTotalBorrowed = totalBorrowed;
        uint256 previousTotalCollectedFees = totalCollectedFees;

        // Get total amount available to borrow
        uint256 totalAvailable = getTotalAvailableCash();

        // Get current utilization rate
        uint256 utilizationRateInEther = getUtilizationRateInEther(
            totalAvailable,
            totalBorrowed
        );

        // Get borrow rate per second
        uint256 borrowRatePerSecondInEther = getBorrowRatePerSecondInEther(
            utilizationRateInEther
        );

        // Get time elapsed since last accrued
        uint256 elapsedSeconds = currentTimestamp - previousTimestamp;

        // Get the interest amount
        uint256 interestAmount = getInterestAmount(
            totalBorrowed,
            borrowRatePerSecondInEther,
            elapsedSeconds
        );

        // Update the vault states based on the interest amount:
        // totalBorrow & totalCollectedFees
        updateVaultStates(interestAmount);

        // Otherwise set the timestamp last accrued and emit event
        lastTimestampInterestAccrued = currentTimestamp;
        emit InterestAccrued(
            previousTimestamp,
            currentTimestamp,
            previousTotalBorrowed,
            previousTotalCollectedFees,
            totalAvailable,
            utilizationRateInEther,
            borrowRatePerSecondInEther,
            elapsedSeconds,
            interestAmount,
            totalBorrowed,
            totalCollectedFees
        );
        // Set invalid as false
        return false;
    }

    /// @notice getVaultTokenSupply returns the total supply of the vault token
    function getVaultTokenTotalSupply() internal view returns (uint256) {
        IERC20 vaultToken = IERC20(address(this));
        return vaultToken.totalSupply();
    }

    /**
     * @notice getExchangeRateWad get the current exchange rate from the
     *         underlying asset to the token vault.
     *         The transaction will revert if there is overflow/underflow.
     * @return exchangeRateWad The exchange rate stored as wad.
     *         exchangeRateWad=0 if invalid=true
     */
    function getExchangeRateWad()
        internal
        view
        returns (uint256 exchangeRateWad)
    {
        uint256 totalSupply = getVaultTokenTotalSupply();

        if (totalSupply == 0) {
            // If there is no supply, exchange rate is 1:1
            return ONE_WAD;
        } else {
            // Otherwise: exchangeRate = (totalAvailable + totalBorrowed) / totalSupply
            uint256 totalAvailable = getTotalAvailableCash();
            uint256 totalAllUnderlyingAssetAmount = add(
                totalAvailable,
                totalBorrowed
            );
            exchangeRateWad = wdiv(totalAllUnderlyingAssetAmount, totalSupply);
            return exchangeRateWad;
        }
    }

    /**
     * @notice getCurrentExchangeRateWad returns the up-to-date exchange rate
     * @return Exchange rate represented as wad
     */
    function getCurrentExchangeRateWad()
        external
        nonReentrant
        returns (uint256)
    {
        bool invalid = accrueInterest();
        require(invalid == false, "FAILED_TO_ACCRUE_INTEREST");
        return getExchangeRateWad();
    }

    /**
     * @notice Lender supplies underlying assets into the vault and receives
     *         rvTokens in exchange
     * @dev Accrues interest whether or not the operation succeeds, emit
     *      error events if failed
     * @param amount The amount of the underlying asset to supply
     */
    function mint(uint256 amount) external nonReentrant {
        // Accrue interest, emit events if something bad happen
        accrueInterest();

        // Get the exchange rate
        uint256 exchangeRateWad = getExchangeRateWad();

        // Transfer underlying asset from lender to contract
        IERC20 underlyingToken = IERC20(underlying);
        underlyingToken.safeTransferFrom(msg.sender, address(this), amount);

        // Calculate how much vault token we need to send to the lender
        uint256 amountWad = mul(amount, ONE_WAD);
        uint256 mintedAmountWad = wdiv(amountWad, exchangeRateWad);
        uint256 mintedAmount = mintedAmountWad / ONE_WAD; // Scale down again

        // Send vault token to the lender
        _mint(msg.sender, mintedAmount); // rvToken is 18 decimals

        // Emit event
        emit SupplyAdded(msg.sender, amount, exchangeRateWad, mintedAmount);
    }
}
