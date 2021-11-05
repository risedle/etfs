// SPDX-License-Identifier: GPL-3.0-or-later

// Risedle Market Contract
// It implements money market, ETF creation, redemption and rebalancing mechanism.
//
// ┌───────Risedle Market────────┐    ┌─────────┐
// │                             ├───►│Chainlink│
// │ ┌───────────┐ ┌───────────┐ │    └─────────┘
// │ │Risedle ETF│ │Risedle ETF│ │
// │ └───────────┘ └───────────┘ │    ┌──────────┐
// │                             ├───►│Uniswap V3│
// │ ┌─────────────────────────┐ │    └──────────┘
// │ │      Risedle Vault      │ │
// │ └─────────────────────────┘ │
// └─────────────────────────────┘
//
// The interest rate model is available here: https://observablehq.com/@pyk/ethrise
// Risedle uses ether units (1e18) precision to represent the interest rates.
// Learn more here: https://docs.soliditylang.org/en/v0.8.7/units-and-global-variables.html
//
// I wrote this for ETHOnline Hackathon 2021. Enjoy.

// Copyright (c) 2021 Bayu - All rights reserved
// github: pyk

pragma solidity 0.8.9;
pragma experimental ABIEncoderV2;

import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import {IChainlinkAggregatorV3} from "./interfaces/Chainlink.sol";
import {ISwapRouter} from "./interfaces/UniswapV3.sol";

import {IRisedleETFToken} from "./RisedleETFToken.sol";

/// @title Risedle Market
contract RisedleMarket is ERC20, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice The Vault's underlying token
    address public immutable vaultUnderlyingTokenAddress;

    /// @notice The Vault's underlying token Chainlink feed per USD (e.g. USDC/USD)
    address internal immutable vaultUnderlyingTokenFeedAddress;

    /// @notice The fee recipient address
    address internal feeRecipient;

    /// @notice The Uniswap V3 router address
    address internal immutable uniswapV3SwapRouter;

    /// @notice The Vault's token decimals
    uint8 private immutable vaultTokenDecimals;

    /// @notice The total debt proportion issued by the vault, the usage is
    ///         similar to the vault token supply. In order to track the
    ///         outstanding debt of the ETF
    uint256 internal vaultTotalDebtProportion;

    /// @notice Mapping ETF to their debt proportion of totalOutstandingDebt
    /// @dev debt = debtProportion[ETF] * debtProportionRate
    mapping(address => uint256) internal vaultDebtProportion;

    /// @notice Optimal utilization rate in ether units
    uint256 internal VAULT_OPTIMAL_UTILIZATION_RATE_IN_ETHER = 0.9 ether; // 90% utilization

    /// @notice Interest slope 1 in ether units
    uint256 internal VAULT_INTEREST_SLOPE_1_IN_ETHER = 0.2 ether; // 20% slope 1

    /// @notice Interest slop 2 in ether units
    uint256 internal VAULT_INTEREST_SLOPE_2_IN_ETHER = 0.6 ether; // 60% slope 2

    /// @notice Number of seconds in a year (approximation)
    uint256 internal immutable TOTAL_SECONDS_IN_A_YEAR = 31536000;

    /// @notice Maximum borrow rate per second in ether units
    uint256 internal VAULT_MAX_BORROW_RATE_PER_SECOND_IN_ETHER = 50735667174; // 0.000000050735667174% Approx 393% APY

    /// @notice Performance fee for the lender
    uint256 internal VAULT_PERFORMANCE_FEE_IN_ETHER = 0.1 ether; // 10% performance fee

    /// @notice The total amount of principal borrowed plus interest accrued
    uint256 public vaultTotalOutstandingDebt;

    /// @notice The total amount of pending fees to be collected in the vault
    uint256 public vaultTotalPendingFees;

    /// @notice Timestamp that interest was last accrued at
    uint256 internal lastTimestampInterestAccrued;

    /// @notice ETFInfo contains information of the ETF
    struct ETFInfo {
        address token; // Address of ETF token ERC20, make sure this vault can mint & burn this token
        address collateral; // ETF underlying asset (e.g. WETH address)
        uint8 collateralDecimals;
        address feed; // Chainlink feed (e.g. ETH/USD)
        uint256 initialPrice; // In term of vault's underlying asset (e.g. 100 USDC -> 100 * 1e6, coz is 6 decimals for USDC)
        uint256 feeInEther; // Creation and redemption fee in ether units (e.g. 0.1% is 0.001 ether)
        uint256 totalCollateral; // Total amount of underlying managed by this ETF
        uint256 totalPendingFees; // Total amount of creation and redemption pending fees in ETF underlying
        uint24 uniswapV3PoolFee; // Uniswap V3 Pool fee https://docs.uniswap.org/sdk/reference/enums/FeeAmount
    }

    /// @notice Mapping ETF token to their information
    mapping(address => ETFInfo) etfs;

    /// @notice Event emitted when the interest succesfully accrued
    event InterestAccrued(
        uint256 previousTimestamp,
        uint256 currentTimestamp,
        uint256 previousVaultTotalOutstandingDebt,
        uint256 previousVaultTotalPendingFees,
        uint256 borrowRatePerSecondInEther,
        uint256 elapsedSeconds,
        uint256 interestAmount,
        uint256 vaultTotalOutstandingDebt,
        uint256 vaultTotalPendingFees
    );

    /// @notice Event emitted when lender add supply to the vault
    event VaultSupplyAdded(
        address indexed account,
        uint256 amount,
        uint256 ExchangeRateInEther,
        uint256 mintedAmount
    );

    /// @notice Event emitted when lender remove supply from the vault
    event VaultSupplyRemoved(
        address indexed account,
        uint256 amount,
        uint256 ExchangeRateInEther,
        uint256 redeemedAmount
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

    /// @notice Event emitted when new ETF is created
    event ETFCreated(address indexed creator, address etfToken);

    /// @notice Event emitted when new ETF token minted
    event ETFMinted(
        address indexed investor,
        address indexed etf,
        uint256 amount
    );

    /// @notice Event emitted when new ETF token burned
    event ETFBurned(
        address indexed investor,
        address indexed etf,
        uint256 amount
    );

    /**
     * @notice Construct new Risedle Market
     * @param vaultTokenName The Vault's token name
     * @param vaultTokenSymbol The Vault's token symbol
     * @param vaultUnderlyingTokenAddress_ The Vault's underlying token address (ERC20)
     * @param vaultUnderlyingTokenFeedAddress_ The Vault's underlying token Chainlink feed per USD (e.g. USDC/USD)
     * @param vaultTokenDecimals_ The Vault's token decimal
     * @param uniswapV3SwapRouter_ The Uniswap V3 router address
     */
    constructor(
        string memory vaultTokenName,
        string memory vaultTokenSymbol,
        address vaultUnderlyingTokenAddress_,
        address vaultUnderlyingTokenFeedAddress_,
        uint8 vaultTokenDecimals_,
        address uniswapV3SwapRouter_
    ) ERC20(vaultTokenName, vaultTokenSymbol) {
        // Set the vault's underlying token address (ERC20)
        vaultUnderlyingTokenAddress = vaultUnderlyingTokenAddress_;

        // Set the vault's underlying token chainlink feed address (e.g. USDC/USD)
        vaultUnderlyingTokenFeedAddress = vaultUnderlyingTokenFeedAddress_;

        // Set vault token decimals similar to the supply
        vaultTokenDecimals = vaultTokenDecimals_;

        // Set contract deployer as fee recipient address
        feeRecipient = msg.sender;

        // Initialize the last timestamp interest accrued
        lastTimestampInterestAccrued = block.timestamp;

        // Set Uniswap V3 router address
        uniswapV3SwapRouter = uniswapV3SwapRouter_;
    }

    /// @notice Overwrite the vault token decimals
    /// @dev https://docs.openzeppelin.com/contracts/4.x/erc20
    function decimals() public view virtual override returns (uint8) {
        return vaultTokenDecimals;
    }

    /**
     * @notice getTotalAvailableCash returns the total amount of vault's
     *         underlying token that available to borrow
     * @return The amount of vault's underlying token available to borrow
     */
    function getTotalAvailableCash() public view returns (uint256) {
        uint256 vaultBalance = IERC20(vaultUnderlyingTokenAddress).balanceOf(
            address(this)
        );
        if (vaultTotalPendingFees >= vaultBalance) return 0;
        return vaultBalance - vaultTotalPendingFees;
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
            vaultTotalOutstandingDebt
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
            return VAULT_MAX_BORROW_RATE_PER_SECOND_IN_ETHER;
        }

        // Calculate the borrow rate
        // See the formula here: https://observablehq.com/@pyk  /ethrise
        if (utilizationRateInEther <= VAULT_OPTIMAL_UTILIZATION_RATE_IN_ETHER) {
            // Borrow rate per year = (utilization rate/optimal utilization rate) * interest slope 1
            // Borrow rate per seconds = Borrow rate per year / seconds in a year
            uint256 rateInEther = (utilizationRateInEther * 1 ether) /
                VAULT_OPTIMAL_UTILIZATION_RATE_IN_ETHER;
            uint256 borrowRatePerYearInEther = (rateInEther *
                VAULT_INTEREST_SLOPE_1_IN_ETHER) / 1 ether;
            uint256 borrowRatePerSecondInEther = borrowRatePerYearInEther /
                TOTAL_SECONDS_IN_A_YEAR;
            return borrowRatePerSecondInEther;
        } else {
            // Borrow rate per year = interest slope 1 + ((utilization rate - optimal utilization rate)/(1-utilization rate)) * interest slope 2
            // Borrow rate per seconds = Borrow rate per year / seconds in a year
            uint256 aInEther = utilizationRateInEther -
                VAULT_OPTIMAL_UTILIZATION_RATE_IN_ETHER;
            uint256 bInEther = 1 ether - utilizationRateInEther;
            uint256 cInEther = (aInEther * 1 ether) / bInEther;
            uint256 dInEther = (cInEther * VAULT_INTEREST_SLOPE_2_IN_ETHER) /
                1 ether;
            uint256 borrowRatePerYearInEther = VAULT_INTEREST_SLOPE_1_IN_ETHER +
                dInEther;
            uint256 borrowRatePerSecondInEther = borrowRatePerYearInEther /
                TOTAL_SECONDS_IN_A_YEAR;
            // Cap the borrow rate
            if (
                borrowRatePerSecondInEther >=
                VAULT_MAX_BORROW_RATE_PER_SECOND_IN_ETHER
            ) {
                return VAULT_MAX_BORROW_RATE_PER_SECOND_IN_ETHER;
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
        uint256 nonFeeInEther = 1 ether - VAULT_PERFORMANCE_FEE_IN_ETHER;
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
     *         totalOutstandingDebt and totalVaultPendingFees.
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
     * @notice setVaultStates update the vaultTotalOutstandingDebt and vaultTotalOutstandingDebt
     * @param interestAmount The total of interest amount to be splitted, the decimals
     *        is similar to vaultTotalOutstandingDebt and vaultTotalOutstandingDebt.
     * @param currentTimestamp The current timestamp when the interest is accrued
     */
    function setVaultStates(uint256 interestAmount, uint256 currentTimestamp)
        internal
    {
        // Get the fee
        uint256 feeAmount = (VAULT_PERFORMANCE_FEE_IN_ETHER * interestAmount) /
            1 ether;

        // Update the states
        vaultTotalOutstandingDebt = vaultTotalOutstandingDebt + interestAmount;
        vaultTotalPendingFees = vaultTotalPendingFees + feeAmount;
        lastTimestampInterestAccrued = currentTimestamp;
    }

    /**
     * @notice accrueInterest accrues interest to vaultTotalOutstandingDebt and vaultTotalPendingFees
     * @dev This calculates interest accrued from the last checkpointed timestamp
     *      up to the current timestamp and update the vaultTotalOutstandingDebt and vaultTotalPendingFees
     */
    function accrueInterest() public {
        // Get the current timestamp, get last timestamp accrued and set the last time accrued
        uint256 currentTimestamp = block.timestamp;
        uint256 previousTimestamp = lastTimestampInterestAccrued;

        // If currentTimestamp and previousTimestamp is similar then return early
        if (currentTimestamp == previousTimestamp) return;

        // For event logging purpose
        uint256 previousVaultTotalOutstandingDebt = vaultTotalOutstandingDebt;
        uint256 previousVaultTotalPendingFees = vaultTotalPendingFees;

        // Get borrow rate per second
        uint256 borrowRatePerSecondInEther = getBorrowRatePerSecondInEther();

        // Get time elapsed since last accrued
        uint256 elapsedSeconds = currentTimestamp - previousTimestamp;

        // Get the interest amount
        uint256 interestAmount = getInterestAmount(
            vaultTotalOutstandingDebt,
            borrowRatePerSecondInEther,
            elapsedSeconds
        );

        // Update the vault states based on the interest amount:
        // vaultTotalOutstandingDebt & vaultTotalPendingFees
        setVaultStates(interestAmount, currentTimestamp);

        // Emit the event
        emit InterestAccrued(
            previousTimestamp,
            currentTimestamp,
            previousVaultTotalOutstandingDebt,
            previousVaultTotalPendingFees,
            borrowRatePerSecondInEther,
            elapsedSeconds,
            interestAmount,
            vaultTotalOutstandingDebt,
            vaultTotalPendingFees
        );
    }

    /**
     * @notice getExchangeRateInEther get the current exchange rate of vault token
     *         in term of Vault's underlying token.
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
                vaultTotalOutstandingDebt;
            uint256 exchangeRateInEther = (totalAllUnderlyingAsset * 1 ether) /
                totalSupply;
            return exchangeRateInEther;
        }
    }

    /**
     * @notice Lender supplies underlying token into the vault and receives
     *         vault tokens in exchange
     * @param amount The amount of the underlying token to supply
     */
    function addSupply(uint256 amount) external nonReentrant {
        // Accrue interest
        accrueInterest();

        // Transfer asset from lender to the vault
        IERC20(vaultUnderlyingTokenAddress).safeTransferFrom(
            msg.sender,
            address(this),
            amount
        );

        // Get the exchange rate
        uint256 exchangeRateInEther = getExchangeRateInEther();

        // Calculate how much vault token we need to send to the lender
        uint256 mintedAmount = (amount * 1 ether) / exchangeRateInEther;

        // Send vault token to the lender
        _mint(msg.sender, mintedAmount);

        // Emit event
        emit VaultSupplyAdded(
            msg.sender,
            amount,
            exchangeRateInEther,
            mintedAmount
        );
    }

    /**
     * @notice Lender burn vault tokens and receives underlying tokens in exchange
     * @param amount The amount of the vault tokens
     */
    function removeSupply(uint256 amount) external nonReentrant {
        // Accrue interest
        accrueInterest();

        // Burn the vault tokens from the lender
        _burn(msg.sender, amount);

        // Get the exchange rate
        uint256 exchangeRateInEther = getExchangeRateInEther();

        // Calculate how much underlying token we need to send to the lender
        uint256 redeemedAmount = (exchangeRateInEther * amount) / 1 ether;

        // Transfer Vault's underlying token from the vault to the lender
        IERC20(vaultUnderlyingTokenAddress).safeTransfer(
            msg.sender,
            redeemedAmount
        );

        // Emit event
        emit VaultSupplyRemoved(
            msg.sender,
            amount,
            exchangeRateInEther,
            redeemedAmount
        );
    }

    /**
     * @notice getDebtProportionRateInEther returns the proportion of borrow
     *         amount relative to the vaultTotalOutstandingDebt
     * @return debtProportionRateInEther The debt proportion rate in ether units
     */
    function getDebtProportionRateInEther()
        internal
        view
        returns (uint256 debtProportionRateInEther)
    {
        if (vaultTotalOutstandingDebt == 0 || vaultTotalDebtProportion == 0) {
            return 1 ether;
        }
        debtProportionRateInEther =
            (vaultTotalOutstandingDebt * 1 ether) /
            vaultTotalDebtProportion;
    }

    /**
     * @notice getOutstandingDebt returns the debt owed by the ETF
     * @param etf The ETF address
     */
    function getOutstandingDebt(address etf) public view returns (uint256) {
        // If there is no debt, return 0
        if (vaultTotalOutstandingDebt == 0) {
            return 0;
        }

        // Calculate the outstanding debt
        // outstanding debt = debtProportion * debtProportionRate
        uint256 debtProportionRateInEther = getDebtProportionRateInEther();
        uint256 a = (vaultDebtProportion[etf] * debtProportionRateInEther);
        uint256 b = 1 ether;
        uint256 outstandingDebt = a / b + (a % b == 0 ? 0 : 1); // Rounds up instead of rounding down

        return outstandingDebt;
    }

    /**
     * @notice getVaultParameters returns the current vault parameters.
     * @return optimalUtilizationRateInEther Optimal utilization rate in ether units.
     * @return interestSlope1InEther Interest slope #1 in ether units.
     * @return interestSlope2InEther Interest slope #2 in ether units.
     * @return maxBorrowRatePerSecondInEther Maximum borrow rate per second in ether units.
     * @return performanceFeeInEther Performance fee in ether units.
     */
    function getVaultParameters()
        external
        view
        returns (
            uint256 optimalUtilizationRateInEther,
            uint256 interestSlope1InEther,
            uint256 interestSlope2InEther,
            uint256 maxBorrowRatePerSecondInEther,
            uint256 performanceFeeInEther
        )
    {
        optimalUtilizationRateInEther = VAULT_OPTIMAL_UTILIZATION_RATE_IN_ETHER;
        interestSlope1InEther = VAULT_INTEREST_SLOPE_1_IN_ETHER;
        interestSlope2InEther = VAULT_INTEREST_SLOPE_2_IN_ETHER;
        maxBorrowRatePerSecondInEther = VAULT_MAX_BORROW_RATE_PER_SECOND_IN_ETHER;
        performanceFeeInEther = VAULT_PERFORMANCE_FEE_IN_ETHER;
    }

    /**
     * @notice setVaultParameters updates the vault parameters.
     * @dev Only governance can call this function
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
        VAULT_OPTIMAL_UTILIZATION_RATE_IN_ETHER = u;
        VAULT_INTEREST_SLOPE_1_IN_ETHER = s1;
        VAULT_INTEREST_SLOPE_2_IN_ETHER = s2;
        VAULT_MAX_BORROW_RATE_PER_SECOND_IN_ETHER = mr;
        VAULT_PERFORMANCE_FEE_IN_ETHER = fee;

        emit VaultParametersUpdated(msg.sender, u, s1, s2, mr, fee);
    }

    /**
     * @notice collectPendingFees withdraws collected fees to the feeRecipient
     *         address
     * @dev Anyone can call this function
     * TODO (bayu): Implement collectPendingFees(etf)
     */
    function collectPendingFees() external nonReentrant {
        // Accrue interest
        accrueInterest();

        // For logging purpose
        uint256 collectedFees = vaultTotalPendingFees;

        // Transfer Vault's underlying token from the vault to the fee recipient
        IERC20(vaultUnderlyingTokenAddress).safeTransfer(
            feeRecipient,
            collectedFees
        );

        // Reset the vaultTotalPendingFees
        vaultTotalPendingFees = 0;

        emit FeeCollected(msg.sender, collectedFees, feeRecipient);
    }

    /**
     * @notice setFeeRecipient sets the fee recipient address.
     * @dev Only governance can call this function
     */
    function setFeeRecipient(address account) external onlyOwner {
        feeRecipient = account;

        emit FeeRecipientUpdated(msg.sender, account);
    }

    /**
     * @notice getFeeRecipient returns the fee recipient address.
     * @return recipientAddress The address of the fee recipient.
     */
    function getFeeRecipient()
        external
        view
        returns (address recipientAddress)
    {
        recipientAddress = feeRecipient;
    }

    /**
     * @notice createNewETF creates new ETF
     * @dev Only governance can create new ETF
     * @param token The ETF token, this contract should have access to mint & burn
     * @param collateral The underlying token of ETF (e.g. WETH)
     * @param chainlinkFeed Chainlink feed (e.g. ETH/USD)
     * @param initialPrice Initial price of the ETF based on the Vault's underlying asset (e.g. 100 USDC => 100 * 1e6)
     * @param feeInEther Creation and redemption fee in ether units (e.g. 0.001 ether = 0.1%)
     */
    function createNewETF(
        address token,
        address collateral,
        address chainlinkFeed,
        uint256 initialPrice,
        uint256 feeInEther,
        uint24 uniswapV3PoolFee
    ) external onlyOwner {
        // Get collateral decimals
        uint8 collateralDecimals = IERC20Metadata(collateral).decimals();

        // Create new ETF info
        ETFInfo memory info = ETFInfo(
            token,
            collateral,
            collateralDecimals,
            chainlinkFeed,
            initialPrice,
            feeInEther,
            0,
            0,
            uniswapV3PoolFee
        );

        // Map new info to their token
        etfs[token] = info;

        // Emit event
        emit ETFCreated(msg.sender, token);
    }

    /**
     * @notice getETFInfo returns information about the etf
     * @param etf The address of the ETF token
     * @return info The ETF information
     */
    function getETFInfo(address etf) external view returns (ETFInfo memory) {
        return etfs[etf];
    }

    /**
     * @notice getCollateralAndFeeAmount splits collateral and fee amount
     * @param amount The amount of ETF underlying asset deposited by the investor
     * @param feeInEther The ETF fee in ether units (e.g. 0.001 ether = 0.1%)
     * @return collateralAmount The collateral amount
     * @return feeAmount The fee amount collected by the protocol
     */
    function getCollateralAndFeeAmount(uint256 amount, uint256 feeInEther)
        internal
        pure
        returns (uint256 collateralAmount, uint256 feeAmount)
    {
        feeAmount = (amount * feeInEther) / 1 ether;
        collateralAmount = amount - feeAmount;
    }

    /**
     * @notice getChainlinkPriceInGwei returns the latest price from chainlink in term of USD
     * @return priceInGwei The USD price in Gwei units
     */
    function getChainlinkPriceInGwei(address feed)
        internal
        view
        returns (uint256 priceInGwei)
    {
        // Get latest price
        (, int256 price, , , ) = IChainlinkAggregatorV3(feed).latestRoundData();

        // Get feed decimals representation
        uint8 feedDecimals = IChainlinkAggregatorV3(feed).decimals();

        // Scaleup or scaledown the decimals
        if (feedDecimals != 9) {
            priceInGwei = (uint256(price) * 1 gwei) / 10**feedDecimals;
        } else {
            priceInGwei = uint256(price);
        }
    }

    /**
     * @notice getCollateralPrice returns the latest price of the collateral in term of
     *         Vault's underlying token (e.g ETH most likely trading around 3000 UDSC or 3000*1e6)
     * @param collateralFeed The Chainlink collateral feed against USD (e.g. ETH/USD)
     * @param supplyFeed The Chainlink vault's underlying token feed against USD (e.g. USDC/USD)
     * @return collateralPrice Price of collateral in term of Vault's underlying token
     */
    function getCollateralPrice(address collateralFeed, address supplyFeed)
        internal
        view
        returns (uint256 collateralPrice)
    {
        uint256 collateralPriceInGwei = getChainlinkPriceInGwei(collateralFeed);
        uint256 supplyPriceInGwei = getChainlinkPriceInGwei(supplyFeed);
        uint256 priceInGwei = (collateralPriceInGwei * 1 gwei) /
            supplyPriceInGwei;

        // Convert gwei to supply decimals
        collateralPrice = (priceInGwei * (10**vaultTokenDecimals)) / 1 gwei;
    }

    /**
     * @notice swapExactOutputSingle swaps assets via Uniswap V3
     * @param tokenIn The token that we need to transfer to Uniswap V3
     * @param tokenOut The token that we want to get from the Uniswap V3
     * @param amountOut The amount of tokenOut that we need to buy
     * @param amountInMaximum The maximum of tokenIn that we want to pay to get amountOut
     * @param poolFee The uniswap pool fee: [10000, 3000, 500]
     * @return amountIn The amount tokenIn that we send to Uniswap V3 to get amountOut
     */
    function swapExactOutputSingle(
        address tokenIn,
        address tokenOut,
        uint256 amountOut,
        uint256 amountInMaximum,
        uint24 poolFee
    ) internal returns (uint256 amountIn) {
        // Approve Uniswap V3 router to spend maximum amount of the supply
        IERC20(tokenIn).safeApprove(uniswapV3SwapRouter, amountInMaximum);

        // Set the params, we want to get exact amount of collateral with
        // minimal supply out as possible
        ISwapRouter.ExactOutputSingleParams memory params = ISwapRouter
            .ExactOutputSingleParams({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                fee: poolFee,
                recipient: address(this), // Set to this contract
                deadline: block.timestamp,
                amountOut: amountOut,
                amountInMaximum: amountInMaximum, // Max supply we want to pay or max collateral we want to sold
                sqrtPriceLimitX96: 0
            });

        // Execute the swap
        amountIn = ISwapRouter(uniswapV3SwapRouter).exactOutputSingle(params);

        // Set approval back to zero
        IERC20(tokenIn).safeApprove(uniswapV3SwapRouter, 0);
    }

    /**
     * @notice getCollateralPerETF returns the collateral shares per ETF
     * @param etfTotalSupply The total supply of the ETF token
     * @param etfTotalCollateral The total collateral managed by the ETF
     * @param etfTotalETFPendingFees The total pending fees in the ETF
     * @param etfCollateralDecimals The collateral decimals
     * @return collateralPerETF The amount of collateral per ETF (e.g. 0.5 ETH is 0.5*1e18)
     */
    function getCollateralPerETF(
        uint256 etfTotalSupply,
        uint256 etfTotalCollateral,
        uint256 etfTotalETFPendingFees,
        uint8 etfCollateralDecimals
    ) internal pure returns (uint256 collateralPerETF) {
        if (etfTotalSupply == 0) return 0;

        // Get collateral per etf
        collateralPerETF =
            ((etfTotalCollateral - etfTotalETFPendingFees) *
                (10**etfCollateralDecimals)) /
            etfTotalSupply;
    }

    /**
     * @notice getDebtPerETF returns the debt shares per ETF
     * @param etfToken The address of ETF token (ERC20)
     * @param etfTotalSupply The current total supply of the ETF token
     * @param etfCollateralDecimals The decimals of the collateral token
     * @return debtPerETF The amount of debt per ETF (e.g. 80 USDC is 80*1e6)
     */
    function getDebtPerETF(
        address etfToken,
        uint256 etfTotalSupply,
        uint8 etfCollateralDecimals
    ) internal view returns (uint256 debtPerETF) {
        if (etfTotalSupply == 0) return 0;

        // Get total ETF debt
        uint256 totalDebt = getOutstandingDebt(etfToken);
        if (totalDebt == 0) return 0;

        // Get collateral per etf
        debtPerETF = (totalDebt * (10**etfCollateralDecimals)) / etfTotalSupply;
    }

    /**
     * @notice calculateETFNAV calculates the net-asset value of the ETF
     * @param collateralPerETF The amount of collateral per ETF (e.g 0.5 ETH is 0.5*1e18)
     * @param debtPerETF The amount of debt per ETF (e.g. 50 USDC is 50*1e6)
     * @param collateralPrice The collateral price in term of supply asset (e.g 100 USDC is 100*1e6)
     * @param etfInitialPrice The initial price of the ETF in terms od supply asset (e.g. 100 USDC is 100*1e6)
     * @param etfCollateralDecimals The decimals of the collateral token
     * @return etfNAV The NAV price of the ETF in term of vault underlying asset (e.g. 50 USDC is 50*1e6)
     */
    function calculateETFNAV(
        uint256 collateralPerETF,
        uint256 debtPerETF,
        uint256 collateralPrice,
        uint256 etfInitialPrice,
        uint8 etfCollateralDecimals
    ) internal pure returns (uint256 etfNAV) {
        if (collateralPerETF == 0 || debtPerETF == 0) return etfInitialPrice;

        // Get the collateral value in term of the supply
        uint256 collateralValuePerETF = (collateralPerETF * collateralPrice) /
            (10**etfCollateralDecimals);

        // Calculate the NAV
        etfNAV = collateralValuePerETF - debtPerETF;
    }

    /**
     * @notice getETFNAV gets the ETF net-asset value
     * @dev This function is mainly used for the interface (front-end)
     * @param etf The ETF token address
     * @return etfNAV The NAV price of the ETF in term of vault's underlying token (e.g. 50 USDC is 50*1e6)
     */
    function getETFNAV(address etf) public view returns (uint256 etfNAV) {
        ETFInfo memory etfInfo = etfs[etf];
        if (etfInfo.feeInEther == 0) return 0;

        // Get the current price of ETF underlying token (collateral)
        // in term of vault underlying token (supply) (e.g. ETH/USDC)
        uint256 collateralPrice = getCollateralPrice(
            etfInfo.feed,
            vaultUnderlyingTokenFeedAddress
        );

        // Get collateral per etf and debt per etf
        uint256 etfTotalSupply = IERC20(etfInfo.token).totalSupply();
        uint256 collateralPerETF = getCollateralPerETF(
            etfTotalSupply,
            etfInfo.totalCollateral,
            etfInfo.totalPendingFees,
            etfInfo.collateralDecimals
        );
        uint256 debtPerETF = getDebtPerETF(
            etfInfo.token,
            etfTotalSupply,
            etfInfo.collateralDecimals
        );

        etfNAV = calculateETFNAV(
            collateralPerETF,
            debtPerETF,
            collateralPrice,
            etfInfo.initialPrice,
            etfInfo.collateralDecimals
        );
    }

    /**
     * @notice setETFBorrowStates sets the debt of the ETF token
     * @param etf The address of the ETF token
     * @param borrowAmount The amount that borrowed by the ETF
     */
    function setETFBorrowStates(address etf, uint256 borrowAmount) internal {
        uint256 debtProportionRateInEther = getDebtProportionRateInEther();
        vaultTotalOutstandingDebt += borrowAmount;
        uint256 borrowProportion = (borrowAmount * 1 ether) /
            debtProportionRateInEther;
        vaultTotalDebtProportion += borrowProportion;
        vaultDebtProportion[etf] = vaultDebtProportion[etf] + borrowProportion;
    }

    /**
     * @notice getETFMintAmount returns the amount of ETF token need to be minted
     * @param collateralAmount The amount of collateral
     * @param collateralPrice The price of the collateral in term of supply (e.g. ETH/USDC)
     * @param borrowAmount The amount of supply borrowed to 2x leverage the collateralAmount
     * @return mintedAmount The amount of ETF token need to be minted
     */
    function getETFMintAmount(
        ETFInfo memory etfInfo,
        uint256 collateralAmount,
        uint256 collateralPrice,
        uint256 borrowAmount
    ) internal view returns (uint256 mintedAmount) {
        // Calculate the net-asset value of the ETF in term of underlying
        uint256 etfNAV = getETFNAV(etfInfo.token);

        // Calculate the total investment
        // totalInvestment = 2 x collateralValue - borrowAmount
        uint256 totalInvestment = ((2 * collateralAmount * collateralPrice) /
            (10**etfInfo.collateralDecimals)) - borrowAmount;

        // Get minted amount
        mintedAmount =
            (totalInvestment * (10**etfInfo.collateralDecimals)) /
            etfNAV;
    }

    /**
     * @notice borrowAndSwap borrow supply asset from the vault and buy more collateral
     * @param etfInfo The ETF information
     * @param collateralAmount The amount of collateral
     * @param collateralPrice The price of colalteral relative to the supply (e.g. ETH/USDC)
     * @return borrowAmount The amount of supply borrowed to 2x leverage the collateralAmount
     */
    function borrowAndSwap(
        ETFInfo memory etfInfo,
        uint256 collateralAmount,
        uint256 collateralPrice
    ) internal returns (uint256 borrowAmount) {
        // Maximum plus +1% from the chainlink oracle
        uint256 maximumCollateralPrice = collateralPrice +
            ((0.01 ether * collateralPrice) / 1 ether);

        // Get the collateral value
        uint256 maxSupplyOut = (collateralAmount * maximumCollateralPrice) /
            (10**etfInfo.collateralDecimals);

        // Make sure we do have enough supply available
        require(getTotalAvailableCash() > maxSupplyOut, "!NotEnoughSupply");

        // Buy more collateral from Uniswap V3
        borrowAmount = swapExactOutputSingle(
            vaultUnderlyingTokenAddress,
            etfInfo.collateral,
            collateralAmount,
            maxSupplyOut,
            etfInfo.uniswapV3PoolFee
        );
    }

    /**
     * @notice Mint new ETF token
     * @param etf The address of registered ETF token
     * @param amount The collateral amount
     */
    function invest(address etf, uint256 amount) external nonReentrant {
        // Accrue interest
        accrueInterest();
        // Get the ETF info
        ETFInfo memory etfInfo = etfs[etf];
        require(etfInfo.feeInEther > 0, "!ETF"); // Make sure the ETF is exists

        // Transfer the collateral to the vault
        IERC20(etfInfo.collateral).safeTransferFrom(
            msg.sender,
            address(this),
            amount
        );

        // Get the collateral and fee amount
        (
            uint256 collateralAmount,
            uint256 feeAmount
        ) = getCollateralAndFeeAmount(amount, etfInfo.feeInEther);

        // Update the ETF info
        etfs[etfInfo.token].totalCollateral += ((2 * collateralAmount) +
            feeAmount);
        etfs[etfInfo.token].totalPendingFees += feeAmount;

        // Get the current price of ETF underlying asset (collateral)
        // in term of vault underlying asset (supply) (e.g. ETH/USDC)
        uint256 collateralPrice = getCollateralPrice(
            etfInfo.feed,
            vaultUnderlyingTokenFeedAddress
        );

        // Get the borrow amount
        uint256 borrowAmount = borrowAndSwap(
            etfInfo,
            collateralAmount,
            collateralPrice
        );

        // Set ETF debt states
        setETFBorrowStates(etfInfo.token, borrowAmount);

        uint256 mintedAmount = getETFMintAmount(
            etfInfo,
            collateralAmount,
            collateralPrice,
            borrowAmount
        );

        // Transfer ETF token to the caller
        IRisedleETFToken(etf).mint(msg.sender, mintedAmount);

        emit ETFMinted(msg.sender, etf, mintedAmount);
    }

    /**
     * @notice setETFRepayStates repay the debt of the ETF
     * @param etf The address of the ETF token
     * @param repayAmount The amount that borrowed by the ETF
     */
    function setETFRepayStates(address etf, uint256 repayAmount) internal {
        uint256 debtProportionRateInEther = getDebtProportionRateInEther();
        vaultTotalOutstandingDebt -= repayAmount;
        uint256 repayProportion = (repayAmount * 1 ether) /
            debtProportionRateInEther;
        vaultTotalDebtProportion -= repayProportion;
        vaultDebtProportion[etf] -= repayProportion;
    }

    /**
     * @notice getRepayAmount get the amount need to be repayed to the vault
     * @param etfInfo The ETF Info
     * @param totalSupply The total supply of the ETF token
     * @param amount The ETF token amount
     * @return repayAmount The amount of vault's underlying token that need to be repay
     */
    function getRepayAmount(
        ETFInfo memory etfInfo,
        uint256 totalSupply,
        uint256 amount
    ) internal view returns (uint256 repayAmount) {
        uint256 debtPerETF = getDebtPerETF(
            etfInfo.token,
            totalSupply,
            etfInfo.collateralDecimals
        );

        repayAmount = (debtPerETF * amount) / (10**etfInfo.collateralDecimals);
    }

    /**
     * @notice redeem Burn the ETF token then send the ETF's collateral token to the sender.
     * @param etf The address of the ETF token
     * @param amount The amount of ETF token need to be burned
     */
    function redeem(address etf, uint256 amount) external nonReentrant {
        // Accrue interest
        accrueInterest();

        // Get the ETF info
        ETFInfo memory etfInfo = etfs[etf];
        require(etfInfo.feeInEther > 0, "!ETF"); // Make sure the ETF is exists

        // Get collateral per ETF and debt per ETF
        uint256 etfTotalSupply = IERC20(etfInfo.token).totalSupply();
        uint256 collateralPerETF = getCollateralPerETF(
            etfTotalSupply,
            etfInfo.totalCollateral,
            etfInfo.totalPendingFees,
            etfInfo.collateralDecimals
        );

        // Burn the ETF token
        IRisedleETFToken(etf).burn(msg.sender, amount);

        // The amount we need to repay (e.g. 100 USDC)
        uint256 repayAmount = getRepayAmount(etfInfo, etfTotalSupply, amount);

        // Set the repay states
        setETFRepayStates(etf, repayAmount);

        // Get the collateral price
        uint256 collateralPrice = getCollateralPrice(
            etfInfo.feed,
            vaultUnderlyingTokenFeedAddress
        );
        // Maximum minus -1% from the chainlink oracle
        uint256 minimumCollateralPrice = collateralPrice -
            ((0.01 ether * collateralPrice) / 1 ether);

        // Get the collateral value
        uint256 collateralAmount = (amount * collateralPerETF) /
            (10**etfInfo.collateralDecimals);
        uint256 collateralValue = (collateralAmount * minimumCollateralPrice) /
            (10**etfInfo.collateralDecimals);

        // Get the amount of collateral that we need to sell in order to repay
        // the debt
        // collateral need to sold = (repayAmount / colalteralValue) * collateralAmount
        uint256 collateralRepay = (((repayAmount * (1 ether)) /
            collateralValue) * collateralAmount) / 1 ether;

        // Sell the collateral to repay the asset
        uint256 collateralSold = swapExactOutputSingle(
            etfInfo.collateral,
            vaultUnderlyingTokenAddress,
            repayAmount,
            collateralRepay,
            etfInfo.uniswapV3PoolFee
        );

        // Deduct fee and send collateral to the user
        (uint256 redeemAmount, uint256 feeAmount) = getCollateralAndFeeAmount(
            collateralAmount - collateralSold,
            etfInfo.feeInEther
        );
        etfs[etfInfo.token].totalCollateral -= (collateralAmount - feeAmount);
        etfs[etfInfo.token].totalPendingFees += feeAmount;

        // Send the remaining collateral to the investor minus the fee
        IERC20(etfInfo.collateral).safeTransfer(msg.sender, redeemAmount);

        emit ETFBurned(msg.sender, etf, redeemAmount);
    }
}
