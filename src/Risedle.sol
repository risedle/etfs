// SPDX-License-Identifier: GPL-3.0-or-later

// Risedle Contract
// It implements money market, ETF creation, redemption and rebalancing mechanism.
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
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";

/// @title Risedle
contract Risedle is ERC20, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice To keep track the authorized borrower
    mapping(address => bool) private _isBorrower;

    /// @notice The underlying assets address contract (ERC20)
    address public immutable underlying;

    /// @notice The Vault's fee recipient address
    address internal feeRecipient;

    /// @notice The vault token decimals
    uint8 private immutable _decimals;

    /// @notice The total debt proportion issued by the vault, the usage is
    ///         similar to the vault token supply. In order to track the
    ///         outstanding debt of the borrower
    uint256 internal totalDebtProportion;

    /// @notice Mapping borrower to their debt proportion of totalOutstandingDebt
    /// @dev debt = _debtProportion[borrower] * debtProportionRate
    mapping(address => uint256) private _debtProportion;

    /// @notice Optimal utilization rate in ether units
    uint256 internal OPTIMAL_UTILIZATION_RATE_IN_ETHER = 0.9 ether; // 90% utilization

    /// @notice Interest slope 1 in ether units
    uint256 internal INTEREST_SLOPE_1_IN_ETHER = 0.2 ether; // 20% slope 1

    /// @notice Interest slop 2 in ether units
    uint256 internal INTEREST_SLOPE_2_IN_ETHER = 0.6 ether; // 60% slope 2

    /// @notice Number of seconds in a year (approximation)
    uint256 internal immutable TOTAL_SECONDS_IN_A_YEAR = 31536000;

    /// @notice Maximum borrow rate per second in ether units
    uint256 internal MAX_BORROW_RATE_PER_SECOND_IN_ETHER = 50735667174; // 0.000000050735667174% Approx 393% APY

    /// @notice Performance fee for the lender
    uint256 internal PERFORMANCE_FEE_IN_ETHER = 0.1 ether; // 10% performance fee

    /// @notice The total amount of principal borrowed plus interest accrued
    uint256 public totalOutstandingDebt;

    /// @notice The total amount of pending fees to be collected in the vault
    uint256 public totalPendingFees;

    /// @notice Timestamp that interest was last accrued at
    uint256 internal lastTimestampInterestAccrued;

    /// @notice ETFInfo contains information of the ETF
    struct ETFInfo {
        address token; // Address of ETF token ERC20, make sure this vault can mint & burn this token
        address underlying; // ETF underlying asset (e.g. WETH address)
        address feed; // Chainlink feed (e.g. ETH/USD)
        uint256 initialPrice; // In term of vault's underlying asset (e.g. 100 USDC -> 100 * 1e6, coz is 6 decimals for USDC)
        uint256 feeInEther; // Creation and redemption fee in ether units
    }

    /// @notice Mapping ETF token to their information
    mapping(address => ETFInfo) etfs;

    /// @notice Event emitted when the interest succesfully accrued
    event InterestAccrued(
        uint256 previousTimestamp,
        uint256 currentTimestamp,
        uint256 previousTotalOutstandingDebt,
        uint256 previoustotalPendingFees,
        uint256 borrowRatePerSecondInEther,
        uint256 elapsedSeconds,
        uint256 interestAmount,
        uint256 totalOutstandingDebt,
        uint256 totalPendingFees
    );

    /// @notice Event emitted when lender add supply to the vault
    event SupplyAdded(
        address indexed account,
        uint256 amount,
        uint256 ExchangeRateInEther,
        uint256 mintedAmount
    );

    /// @notice Event emitted when lender remove supply from the vault
    event SupplyRemoved(
        address indexed account,
        uint256 amount,
        uint256 ExchangeRateInEther,
        uint256 redeemedAmount
    );

    /// @notice Event emitted when borrower borrow from the vault
    event Borrowed(
        address indexed account,
        uint256 amount,
        uint256 debtProportionRateInEther
    );

    /// @notice Event emitted when borrower repay to the vault
    event Repaid(
        address indexed account,
        uint256 amount,
        uint256 debtProportionRateInEther
    );

    /// @notice Event emitted when vault parameters are updated
    event VaultParametersUpdated(
        address indexed updater,
        uint256 u,
        uint256 s1,
        uint256 s2,
        uint256 mr,
        uint256 fee
    );

    /// @notice Event emitted when the collected fees are withdrawn
    event FeeCollected(address collector, uint256 total, address feeRecipient);

    /// @notice Event emitted when the fee recipient is updated
    event FeeRecipientUpdated(address updater, address newFeeRecipient);

    /**
     * @notice Contruct new vault
     * @param name The Vault's token name
     * @param symbol The Vault's token symbol
     * @param underlying_ The ERC20 contract address of underlying asset
     * @param underlyingDecimals_ The ERC20 decimals of underlying asset
     */
    constructor(
        string memory name,
        string memory symbol,
        address underlying_,
        uint8 underlyingDecimals_
    ) ERC20(name, symbol) {
        // Sanity check
        IERC20(underlying_).totalSupply();

        // Set underlying asset contract address
        underlying = underlying_;

        // Set vault token decimals similar to the underlying
        _decimals = underlyingDecimals_;

        // Set contract deployer as fee recipient address
        feeRecipient = msg.sender;

        // Initialize the last timestamp accrued
        lastTimestampInterestAccrued = block.timestamp;
    }

    /// @notice Overwrite the vault token decimals
    /// @dev https://docs.openzeppelin.com/contracts/4.x/erc20
    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    /**
     * @notice onlyBorrower modifier
     * @dev Use this for borrow and repay function
     */
    modifier onlyBorrower() {
        require(_isBorrower[msg.sender]);
        _;
    }

    /**
     * @notice setAsBorrower grants account to borrow the underlying asset
     * @dev Only governor can call this function
     * @param account The contract address granted to borrow
     */
    function setAsBorrower(address account) external onlyOwner {
        _isBorrower[account] = true;
    }

    /**
     * @notice isBorrower returns true if account is borrower
     * @param account The account/contract address
     * @return True if account have been granted as borrower
     */
    function isBorrower(address account) external view returns (bool) {
        return _isBorrower[account];
    }

    /**
     * @notice getTotalAvailableCash returns the total amount of underlying asset
     *         that available to borrow
     * @return The amount of underlying asset ready to borrow
     */
    function getTotalAvailableCash() public view returns (uint256) {
        IERC20 underlyingToken = IERC20(underlying);
        uint256 underlyingBalance = underlyingToken.balanceOf(address(this));
        if (totalPendingFees >= underlyingBalance) return 0;
        return underlyingBalance - totalPendingFees;
    }

    /**
     * @notice calculateUtilizationRateInEther calculates the utilization rate of
     *         the vault.
     * @param available The amount of cash available to borrow in the vault
     * @param outstandingDebt The amount of outstanding debt in the vault
     * @return The utilization rate in ether units
     */
    function calculateUtilizationRateInEther(
        uint256 available,
        uint256 outstandingDebt
    ) internal pure returns (uint256) {
        // Utilization rate is 0% when there is no outstandingDebt asset
        if (outstandingDebt == 0) return 0;

        // Utilization rate is 100% when there is no cash available
        if (available == 0 && outstandingDebt > 0) return 1 ether;

        // utilization rate = amount outstanding debt / (amount available + amount outstanding debt)
        uint256 rateInEther = (outstandingDebt * 1 ether) /
            (outstandingDebt + available);
        return rateInEther;
    }

    /**
     * @notice getUtilizationRateInEther for external use
     * @return utilizationRateInEther The utilization rate in ether units
     */
    function getUtilizationRateInEther()
        public
        view
        returns (uint256 utilizationRateInEther)
    {
        // Get total available asset
        uint256 totalAvailable = getTotalAvailableCash();
        utilizationRateInEther = calculateUtilizationRateInEther(
            totalAvailable,
            totalOutstandingDebt
        );
    }

    /**
     * @notice calculateBorrowRatePerSecondInEther calculates the borrow rate per second
     *         in ether units
     * @param utilizationRateInEther The current utilization rate in ether units
     * @return The borrow rate per second in ether units
     */
    function calculateBorrowRatePerSecondInEther(uint256 utilizationRateInEther)
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
     * @notice getBorrowRatePerSecondInEther for external use
     * @return borrowRateInEther The borrow rate per second in ether units
     */
    function getBorrowRatePerSecondInEther()
        public
        view
        returns (uint256 borrowRateInEther)
    {
        uint256 utilizationRateInEther = getUtilizationRateInEther();
        borrowRateInEther = calculateBorrowRatePerSecondInEther(
            utilizationRateInEther
        );
    }

    /**
     * @notice getSupplyRatePerSecondInEther calculates the supply rate per second
     *         in ether units
     * @return supplyRateInEther The supply rate per second in ether units
     */
    function getSupplyRatePerSecondInEther()
        public
        view
        returns (uint256 supplyRateInEther)
    {
        uint256 utilizationRateInEther = getUtilizationRateInEther();
        uint256 borrowRateInEther = calculateBorrowRatePerSecondInEther(
            utilizationRateInEther
        );
        uint256 nonFeeInEther = 1 ether - PERFORMANCE_FEE_IN_ETHER;
        uint256 rateForSupplyInEther = (borrowRateInEther * nonFeeInEther) /
            1 ether;
        supplyRateInEther =
            (utilizationRateInEther * rateForSupplyInEther) /
            1 ether;
    }

    /**
     * @notice getInterestAmount calculate amount of interest based on the total
     *         outstanding debt and borrow rate per second.
     * @param outstandingDebt Total of outstanding debt, in underlying decimals
     * @param borrowRatePerSecondInEther Borrow rates per second in ether units
     * @param elapsedSeconds Number of seconds elapsed since last accrued
     * @return The total interest amount, it have similar decimals with
     *         totalOutstandingDebt and totalPendingFees.
     */
    function getInterestAmount(
        uint256 outstandingDebt,
        uint256 borrowRatePerSecondInEther,
        uint256 elapsedSeconds
    ) internal pure returns (uint256) {
        // Early returns
        if (
            outstandingDebt == 0 ||
            borrowRatePerSecondInEther == 0 ||
            elapsedSeconds == 0
        ) {
            return 0;
        }

        // Calculate the amount of interest
        // interest amount = borrowRatePerSecondInEther * elapsedSeconds * outstandingDebt
        uint256 interestAmount = (borrowRatePerSecondInEther *
            elapsedSeconds *
            outstandingDebt) / 1 ether;
        return interestAmount;
    }

    /**
     * @notice setVaultStates update the totalOutstandingDebt and totalPendingFees
     * @param interestAmount The total of interest amount to be splitted, the decimals
     *        is similar to totalOutstandingDebt and totalPendingFees.
     * @param currentTimestamp The current timestamp when the interest is accrued
     */
    function setVaultStates(uint256 interestAmount, uint256 currentTimestamp)
        internal
    {
        // Get the fee
        uint256 feeAmount = (PERFORMANCE_FEE_IN_ETHER * interestAmount) /
            1 ether;

        // Update the states
        totalOutstandingDebt = totalOutstandingDebt + interestAmount;
        totalPendingFees = totalPendingFees + feeAmount;
        lastTimestampInterestAccrued = currentTimestamp;
    }

    /**
     * @notice accrueInterest accrues interest to totalOutstandingDebt and totalPendingFees
     * @dev This calculates interest accrued from the last checkpointed timestamp
     *      up to the current timestamp and update the totalOutstandingDebt and totalPendingFees
     */
    function accrueInterest() public {
        // Get the current timestamp, get last timestamp accrued and set the last time accrued
        uint256 currentTimestamp = block.timestamp;
        uint256 previousTimestamp = lastTimestampInterestAccrued;

        // If currentTimestamp and previousTimestamp is similar then return early
        if (currentTimestamp == previousTimestamp) return;

        // For logging purpose
        uint256 previousTotalOutstandingDebt = totalOutstandingDebt;
        uint256 previoustotalPendingFees = totalPendingFees;

        // Get borrow rate per second
        uint256 borrowRatePerSecondInEther = getBorrowRatePerSecondInEther();

        // Get time elapsed since last accrued
        uint256 elapsedSeconds = currentTimestamp - previousTimestamp;

        // Get the interest amount
        uint256 interestAmount = getInterestAmount(
            totalOutstandingDebt,
            borrowRatePerSecondInEther,
            elapsedSeconds
        );

        // Update the vault states based on the interest amount:
        // totalOutstandingDebt & totalPendingFees
        setVaultStates(interestAmount, currentTimestamp);

        // Emit the event
        emit InterestAccrued(
            previousTimestamp,
            currentTimestamp,
            previousTotalOutstandingDebt,
            previoustotalPendingFees,
            borrowRatePerSecondInEther,
            elapsedSeconds,
            interestAmount,
            totalOutstandingDebt,
            totalPendingFees
        );
    }

    /**
     * @notice getExchangeRateInEther get the current exchange rate of vault token
     *         in term of underlying asset.
     * @return The exchange rates in ether units
     */
    function getExchangeRateInEther() public view returns (uint256) {
        uint256 totalSupply = totalSupply();

        if (totalSupply == 0) {
            // If there is no supply, exchange rate is 1:1
            return 1 ether;
        } else {
            // Otherwise: exchangeRate = (totalAvailable + totalOutstandingDebt) / totalSupply
            uint256 totalAvailable = getTotalAvailableCash();
            uint256 totalAllUnderlyingAsset = totalAvailable +
                totalOutstandingDebt;
            uint256 exchangeRateInEther = (totalAllUnderlyingAsset * 1 ether) /
                totalSupply;
            return exchangeRateInEther;
        }
    }

    /**
     * @notice Lender supplies underlying assets into the vault and receives
     *         vault tokens in exchange
     * @param amount The amount of the underlying asset to supply
     */
    function mint(uint256 amount) external nonReentrant {
        // Accrue interest
        accrueInterest();

        // Get the exchange rate
        uint256 exchangeRateInEther = getExchangeRateInEther();

        // Transfer underlying asset from lender to the vault
        IERC20 underlyingToken = IERC20(underlying);
        underlyingToken.safeTransferFrom(msg.sender, address(this), amount);

        // Calculate how much vault token we need to send to the lender
        uint256 mintedAmount = (amount * 1 ether) / exchangeRateInEther;

        // Send vault token to the lender
        _mint(msg.sender, mintedAmount);

        // Emit event
        emit SupplyAdded(msg.sender, amount, exchangeRateInEther, mintedAmount);
    }

    /**
     * @notice Lender burn vault tokens and receives underlying tokens in exchange
     * @param amount The amount of the vault tokens
     */
    function burn(uint256 amount) external nonReentrant {
        // Accrue interest
        accrueInterest();

        // Get the exchange rate
        uint256 exchangeRateInEther = getExchangeRateInEther();

        // Burn the vault tokens from the lender
        _burn(msg.sender, amount);

        // Calculate how much underlying token we need to send to the lender
        uint256 redeemedAmount = (exchangeRateInEther * amount) / 1 ether;

        // Transfer underlying asset from the vault to the lender
        IERC20 underlyingToken = IERC20(underlying);
        underlyingToken.safeTransfer(msg.sender, redeemedAmount);

        // Emit event
        emit SupplyRemoved(
            msg.sender,
            amount,
            exchangeRateInEther,
            redeemedAmount
        );
    }

    /**
     * @notice getDebtProportionRateInEther returns the proportion of borrow
     *         amount relative to the totalOutstandingDebt
     * @return The debt proportion rate in ether units
     */
    function getDebtProportionRateInEther() internal view returns (uint256) {
        if (totalOutstandingDebt == 0 || totalDebtProportion == 0) {
            return 1 ether;
        }
        uint256 debtProportionRateInEther = (totalOutstandingDebt * 1 ether) /
            totalDebtProportion;
        return debtProportionRateInEther;
    }

    /**
     * @notice getOutstandingDebt returns the debt owed by the borrower
     * @param account The borrower address
     */
    function getOutstandingDebt(address account)
        external
        view
        returns (uint256)
    {
        // If there is no debt, return 0
        if (totalOutstandingDebt == 0) {
            return 0;
        }

        // Calculate the outstanding debt
        // outstanding debt = debtProportion * debtProportionRate
        uint256 debtProportionRateInEther = getDebtProportionRateInEther();
        uint256 a = (_debtProportion[account] * debtProportionRateInEther);
        uint256 b = 1 ether;
        uint256 outstandingDebt = a / b + (a % b == 0 ? 0 : 1); // Rounds up instead of rounding down

        return outstandingDebt;
    }

    /**
     * @notice Borrower borrow asset from the vault
     * @dev Only authorized borrowers are allowed to borrow
     * @param amount The amount of underlying asset to borrow
     */
    function borrow(uint256 amount) external nonReentrant onlyBorrower {
        // Accrue interest
        accrueInterest();

        // Get the debt proportion rate first
        uint256 debtProportionRateInEther = getDebtProportionRateInEther();

        // Get the borrower amount proportion to existing totalOutstandingDebt
        uint256 borrowProportion = (amount * 1 ether) /
            debtProportionRateInEther;

        // Do the accounting first before transfering any asset
        totalOutstandingDebt = totalOutstandingDebt + amount;
        totalDebtProportion = totalDebtProportion + borrowProportion;
        _debtProportion[msg.sender] =
            _debtProportion[msg.sender] +
            borrowProportion;

        // Transfer underlying asset from the vault to the borrower
        IERC20 underlyingToken = IERC20(underlying);
        underlyingToken.safeTransfer(msg.sender, amount);

        // Emit event
        emit Borrowed(msg.sender, amount, debtProportionRateInEther);
    }

    /**
     * @notice Borrower repay asset to the vault
     * @dev Only authotized borrowers are allowed to repay
     * @param amount The amount of underlying asset to repay
     */
    function repay(uint256 amount) external nonReentrant onlyBorrower {
        // Accrue interest
        accrueInterest();

        // Transfer underlying asset from the borrower to the vault
        IERC20 underlyingToken = IERC20(underlying);
        underlyingToken.safeTransferFrom(msg.sender, address(this), amount);

        // Get the debt proportion rate first
        uint256 debtProportionRateInEther = getDebtProportionRateInEther();

        // Calculate how many debtProportion we need to substract from borrower
        // and totalDebtProportion based on the repay amount
        uint256 repayProportion = (amount * 1 ether) /
            debtProportionRateInEther;

        // Do the accounting
        totalOutstandingDebt = totalOutstandingDebt - amount;
        totalDebtProportion = totalDebtProportion - repayProportion;
        _debtProportion[msg.sender] =
            _debtProportion[msg.sender] -
            repayProportion;

        // Emit event
        emit Repaid(msg.sender, amount, debtProportionRateInEther);
    }

    /**
     * @notice getVaultParameters returns the current vault parameters.
     * @return All vault parameters
     */
    function getVaultParameters()
        external
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        return (
            OPTIMAL_UTILIZATION_RATE_IN_ETHER,
            INTEREST_SLOPE_1_IN_ETHER,
            INTEREST_SLOPE_2_IN_ETHER,
            MAX_BORROW_RATE_PER_SECOND_IN_ETHER,
            PERFORMANCE_FEE_IN_ETHER
        );
    }

    /**
     * @notice setVaultParameters updates the vault parameters.
     * @dev Only governor can call this function
     * @param u The optimal utilization rate in ether units
     * @param s1 The interest slope 1 in ether units
     * @param s2 The interest slope 2 in ether units
     * @param mr The maximum borrow rate per second in ether units
     * @param fee The performance sharing fee for the lender in ether units
     */
    function setVaultParameters(
        uint256 u,
        uint256 s1,
        uint256 s2,
        uint256 mr,
        uint256 fee
    ) external onlyOwner {
        // Update vault parameters
        OPTIMAL_UTILIZATION_RATE_IN_ETHER = u;
        INTEREST_SLOPE_1_IN_ETHER = s1;
        INTEREST_SLOPE_2_IN_ETHER = s2;
        MAX_BORROW_RATE_PER_SECOND_IN_ETHER = mr;
        PERFORMANCE_FEE_IN_ETHER = fee;

        emit VaultParametersUpdated(msg.sender, u, s1, s2, mr, fee);
    }

    /**
     * @notice collectPendingFees withdraws collected fees to the feeRecipient address
     * @dev Anyone can call this function
     */
    function collectPendingFees() external nonReentrant {
        // Accrue interest
        accrueInterest();

        // For logging purpose
        uint256 collectedFees = totalPendingFees;

        // Transfer underlying asset from the vault to the fee recipient
        IERC20 underlyingToken = IERC20(underlying);
        underlyingToken.safeTransfer(feeRecipient, collectedFees);

        // Reset the totalPendingFees
        totalPendingFees = 0;

        emit FeeCollected(msg.sender, collectedFees, feeRecipient);
    }

    /**
     * @notice setFeeRecipient sets the fee recipient address.
     * @dev Only governor can call this function
     */
    function setFeeRecipient(address account) external onlyOwner {
        feeRecipient = account;

        emit FeeRecipientUpdated(msg.sender, account);
    }

    /**
     * @notice createNewETF creates new ETF
     * @dev Only governance can create new ETF
     * @param token The ETF token, this contract should have access to mint & burn
     * @param underlying_ The underlying token of ETF (e.g. WETH)
     * @param chainlinkFeed Chainlink feed (e.g. ETH/USD)
     * @param initialPrice Initial price of the ETF based on the Vault's underlying asset (e.g. 100 USDC => 100 * 1e6)
     * @param feeInEther Creation and redemption fee in ether units
     */
    function createNewETF(
        address token,
        address underlying_,
        address chainlinkFeed,
        uint256 initialPrice,
        uint256 feeInEther
    ) external onlyOwner {
        // Create new ETF info
        ETFInfo memory info = ETFInfo(
            token,
            underlying_,
            chainlinkFeed,
            initialPrice,
            feeInEther
        );

        // Map new info to their token
        etfs[token] = info;
    }

    /**
     * @notice getETFInfo returns information about the etf
     * @param etf The address of the ETF token
     * @return info The ETF information
     */
    function getETFInfo(address etf) external view returns (ETFInfo memory) {
        return etfs[etf];
    }
}
