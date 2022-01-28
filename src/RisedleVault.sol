// SPDX-License-Identifier: GPL-3.0-or-later

// Risedle Vault Contract
// It implements money market for Risedle RISE tokens and DROP tokens.
//
// Copyright (c) 2021 Bayu - All rights reserved
// github: pyk
// email: bayu@risedle.com
pragma solidity >=0.8.9;
pragma experimental ABIEncoderV2;

import { ERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import { IERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { SafeERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import { Ownable } from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import { ReentrancyGuard } from "lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";

/// @title Risedle Vault
contract RisedleVault is ERC20, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    /// @notice Vault's underlying token address
    address internal underlyingToken;
    /// @notice Optimal utilization rate in ether units
    uint256 internal optimalUtilizationRateInEther = 0.9 ether; // 90% utilization
    /// @notice Interest slope 1 in ether units
    uint256 internal interestSlope1InEther = 0.2 ether; // 20% slope 1
    /// @notice Interest slop 2 in ether units
    uint256 internal interestSlope2InEther = 0.6 ether; // 60% slope 2
    /// @notice Number of seconds in a year (approximation)
    uint256 internal immutable totalSecondsInAYear = 31536000;
    /// @notice Maximum borrow rate per second in ether units
    uint256 internal maxBorrowRatePerSecondInEther = 50735667174; // 0.000000050735667174% Approx 393% APY
    /// @notice Performance fee for the lender
    uint256 internal performanceFeeInEther = 0.1 ether; // 10% performance fee
    /// @notice Timestamp that interest was last accrued at
    uint256 internal lastTimestampInterestAccrued;
    /// @notice The total amount of principal borrowed plus interest accrued
    uint256 public totalOutstandingDebt;
    /// @notice The total amount of pending fees to be collected in the vault
    uint256 public totalPendingFees;
    /// @notice The total debt proportion issued by the vault, the usage is similar to the vault token supply. In order to track the outstanding debt of the RISE/DROP token
    uint256 internal totalDebtProportion;
    /// @notice Max vault's total deposit
    uint256 public maxTotalDeposit;
    /// @notice Fee recipient
    address public FEE_RECIPIENT;

    /// @notice Mapping RISE/DROP token to their debt proportion of totalOutstandingDebt
    /// @dev debt = debtProportion[token] * debtProportionRate
    mapping(address => uint256) internal debtProportion;

    /// @notice Event emitted when the interest succesfully accrued
    event InterestAccrued(uint256 previousTimestamp, uint256 currentTimestamp, uint256 previousVaultTotalOutstandingDebt, uint256 previousVaultTotalPendingFees, uint256 borrowRatePerSecondInEther, uint256 elapsedSeconds, uint256 interestAmount, uint256 totalOutstandingDebt, uint256 totalPendingFees);
    /// @notice Event emitted when lender add supply to the vault
    event SupplyAdded(address indexed account, uint256 amount, uint256 ExchangeRateInEther, uint256 mintedAmount);
    /// @notice Event emitted when lender remove supply from the vault
    event SupplyRemoved(address indexed account, uint256 amount, uint256 ExchangeRateInEther, uint256 redeemedAmount);
    /// @notice Event emitted when vault parameters are updated
    event ParametersUpdated(address indexed updater, uint256 u, uint256 s1, uint256 s2, uint256 mr, uint256 fee);
    /// @notice Event emitted when the collected fees are withdrawn
    event FeeCollected(address collector, uint256 total, address feeRecipient);
    /// @notice Event emitted when the fee recipient is updated
    event FeeRecipientUpdated(address updater, address newFeeRecipient);

    /// @notice Construct new RisedleVault
    constructor(
        string memory name, // The name of the vault's token (e.g. Risedle USDC Vault)
        string memory symbol, // The symbol of the vault's token (e.g rvUSDC)
        address underlying, // The ERC20 address of the vault's underlying token (e.g. address of USDC token)
        address feeRecipient // Fee recipient
    ) ERC20(name, symbol) {
        underlyingToken = underlying; // Set the vault underlying token
        lastTimestampInterestAccrued = block.timestamp; // Set the last timestamp accrued
        totalOutstandingDebt = 0; // Set the initial state
        totalPendingFees = 0;
        FEE_RECIPIENT = feeRecipient;
        maxTotalDeposit = 0;
    }

    /// @notice Vault's token use the same decimals as the underlying
    function decimals() public view virtual override returns (uint8) {
        return IERC20Metadata(underlyingToken).decimals();
    }

    /// @notice getUnderlying returns the underlying token of the vault
    function getUnderlying() external view returns (address underlying) {
        underlying = underlyingToken;
    }

    /// @notice getTotalAvailableCash returns the total amount of vault's underlying token that available to borrow
    function getTotalAvailableCash() public view returns (uint256) {
        uint256 vaultBalance = IERC20(underlyingToken).balanceOf(address(this));
        if (totalPendingFees >= vaultBalance) return 0;
        return vaultBalance - totalPendingFees;
    }

    /// @notice calculateUtilizationRateInEther calculates the utilization rate of the vault.
    function calculateUtilizationRateInEther(uint256 available, uint256 outstandingDebt) internal pure returns (uint256) {
        if (outstandingDebt == 0) return 0; // Utilization rate is 0% when there is no outstandingDebt
        if (available == 0 && outstandingDebt > 0) return 1 ether; // Utilization rate is 100% when there is no cash available
        uint256 rateInEther = (outstandingDebt * 1 ether) / (outstandingDebt + available); // utilization rate = amount outstanding debt / (amount available + amount outstanding debt)
        return rateInEther;
    }

    /// @notice getUtilizationRateInEther for external use
    function getUtilizationRateInEther() public view returns (uint256 utilizationRateInEther) {
        uint256 totalAvailable = getTotalAvailableCash(); // Get total available asset
        utilizationRateInEther = calculateUtilizationRateInEther(totalAvailable, totalOutstandingDebt);
    }

    /// @notice calculateBorrowRatePerSecondInEther calculates the borrow rate per second in ether units
    function calculateBorrowRatePerSecondInEther(uint256 utilizationRateInEther) internal view returns (uint256) {
        // utilizationRateInEther should in range [0, 1e18], Otherwise return max borrow rate
        if (utilizationRateInEther >= 1 ether) return maxBorrowRatePerSecondInEther;

        // Calculate the borrow rate
        // See the formula here: https://observablehq.com/@pyk  /ethrise
        if (utilizationRateInEther <= optimalUtilizationRateInEther) {
            // Borrow rate per year = (utilization rate/optimal utilization rate) * interest slope 1
            // Borrow rate per seconds = Borrow rate per year / seconds in a year
            uint256 rateInEther = (utilizationRateInEther * 1 ether) / optimalUtilizationRateInEther;
            uint256 borrowRatePerYearInEther = (rateInEther * interestSlope1InEther) / 1 ether;
            uint256 borrowRatePerSecondInEther = borrowRatePerYearInEther / totalSecondsInAYear;
            return borrowRatePerSecondInEther;
        } else {
            // Borrow rate per year = interest slope 1 + ((utilization rate - optimal utilization rate)/(1-utilization rate)) * interest slope 2
            // Borrow rate per seconds = Borrow rate per year / seconds in a year
            uint256 aInEther = utilizationRateInEther - optimalUtilizationRateInEther;
            uint256 bInEther = 1 ether - utilizationRateInEther;
            uint256 cInEther = (aInEther * 1 ether) / bInEther;
            uint256 dInEther = (cInEther * interestSlope2InEther) / 1 ether;
            uint256 borrowRatePerYearInEther = interestSlope1InEther + dInEther;
            uint256 borrowRatePerSecondInEther = borrowRatePerYearInEther / totalSecondsInAYear;
            // Cap the borrow rate
            if (borrowRatePerSecondInEther >= maxBorrowRatePerSecondInEther) {
                return maxBorrowRatePerSecondInEther;
            }

            return borrowRatePerSecondInEther;
        }
    }

    /// @notice getBorrowRatePerSecondInEther returns the current borrow rate per seconds
    function getBorrowRatePerSecondInEther() public view returns (uint256 borrowRateInEther) {
        uint256 utilizationRateInEther = getUtilizationRateInEther();
        borrowRateInEther = calculateBorrowRatePerSecondInEther(utilizationRateInEther);
    }

    /// @notice getSupplyRatePerSecondInEther calculates the supply rate per second in ether units
    function getSupplyRatePerSecondInEther() public view returns (uint256 supplyRateInEther) {
        uint256 utilizationRateInEther = getUtilizationRateInEther();
        uint256 borrowRateInEther = calculateBorrowRatePerSecondInEther(utilizationRateInEther);
        uint256 nonFeeInEther = 1 ether - performanceFeeInEther;
        uint256 rateForSupplyInEther = (borrowRateInEther * nonFeeInEther) / 1 ether;
        supplyRateInEther = (utilizationRateInEther * rateForSupplyInEther) / 1 ether;
    }

    /// @notice getInterestAmount calculate amount of interest based on the total outstanding debt and borrow rate per second.
    function getInterestAmount(
        uint256 outstandingDebt, // Total of outstanding debt, in underlying decimals
        uint256 borrowRatePerSecondInEther, // Borrow rates per second in ether units
        uint256 elapsedSeconds // Number of seconds elapsed since last accrued
    ) internal pure returns (uint256) {
        if (outstandingDebt == 0 || borrowRatePerSecondInEther == 0 || elapsedSeconds == 0) return 0;
        uint256 interestAmount = (borrowRatePerSecondInEther * elapsedSeconds * outstandingDebt) / 1 ether; // Calculate the amount of interest
        return interestAmount;
    }

    /// @notice setVaultStates update the totalOutstandingDebt and totalPendingFees
    function setVaultStates(uint256 interestAmount, uint256 currentTimestamp) internal {
        uint256 feeAmount = (performanceFeeInEther * interestAmount) / 1 ether; // Get the fee
        totalOutstandingDebt += interestAmount; // Update the states
        totalPendingFees += feeAmount;
        lastTimestampInterestAccrued = currentTimestamp;
    }

    /// @notice accrueInterest accrues interest to totalOutstandingDebt and totalPendingFees
    function accrueInterest() public {
        uint256 currentTimestamp = block.timestamp; // Get the current timestamp, get last timestamp accrued and set the last time accrued
        uint256 previousTimestamp = lastTimestampInterestAccrued;
        if (currentTimestamp == previousTimestamp) return; // If currentTimestamp and previousTimestamp is similar then return early
        uint256 previousVaultTotalOutstandingDebt = totalOutstandingDebt; // For event logging purpose
        uint256 previousVaultTotalPendingFees = totalPendingFees;
        uint256 borrowRatePerSecondInEther = getBorrowRatePerSecondInEther(); // Get borrow rate per second
        uint256 elapsedSeconds = currentTimestamp - previousTimestamp; // Get time elapsed since last accrued
        uint256 interestAmount = getInterestAmount(totalOutstandingDebt, borrowRatePerSecondInEther, elapsedSeconds); // Get the interest amount
        setVaultStates(interestAmount, currentTimestamp); // Update the vault states based on the interest amount:

        emit InterestAccrued(previousTimestamp, currentTimestamp, previousVaultTotalOutstandingDebt, previousVaultTotalPendingFees, borrowRatePerSecondInEther, elapsedSeconds, interestAmount, totalOutstandingDebt, totalPendingFees);
    }

    /// @notice getExchangeRateInEther get the current exchange rate of vault token in term of Vault's underlying token.
    function getExchangeRateInEther() public view returns (uint256) {
        uint256 totalSupply = totalSupply();
        if (totalSupply == 0) {
            // If there is no supply, exchange rate is 1:1
            return 1 ether;
        } else {
            // Otherwise: exchangeRate = (totalAvailable + totalOutstandingDebt) / totalSupply
            uint256 totalAvailable = getTotalAvailableCash();
            uint256 totalAllUnderlyingAsset = totalAvailable + totalOutstandingDebt;
            uint256 exchangeRateInEther = (totalAllUnderlyingAsset * 1 ether) / totalSupply;
            return exchangeRateInEther;
        }
    }

    /// @notice Lender supplies underlying token into the vault and receives vault tokens in exchange
    function addSupply(uint256 amount) external nonReentrant {
        accrueInterest(); // Accrue interest
        if (maxTotalDeposit != 0) require(getTotalAvailableCash() + totalOutstandingDebt + amount < maxTotalDeposit, "!MCR"); // Max cap reached
        uint256 exchangeRateInEther = getExchangeRateInEther(); // Get the exchange rate
        uint256 mintedAmount = (amount * 1 ether) / exchangeRateInEther; // Calculate how much vault token we need to send to the lender
        IERC20(underlyingToken).safeTransferFrom(msg.sender, address(this), amount); // Transfer asset from lender to the vault
        _mint(msg.sender, mintedAmount); // Send vault token to the lender
        emit SupplyAdded(msg.sender, amount, exchangeRateInEther, mintedAmount);
    }

    /// @notice Lender burn vault tokens and receives underlying tokens in exchange
    function removeSupply(uint256 amount) external nonReentrant {
        accrueInterest(); // Accrue interest
        uint256 exchangeRateInEther = getExchangeRateInEther(); // Get the exchange rate
        uint256 redeemedAmount = (exchangeRateInEther * amount) / 1 ether; // Calculate how much underlying token we need to send to the lender
        IERC20(underlyingToken).safeTransfer(msg.sender, redeemedAmount); // Transfer Vault's underlying token from the vault to the lender
        _burn(msg.sender, amount); // Burn the vault tokens from the lender
        emit SupplyRemoved(msg.sender, amount, exchangeRateInEther, redeemedAmount);
    }

    /// @notice getDebtProportionRateInEther returns the proportion of borrow amount relative to the totalOutstandingDebt
    function getDebtProportionRateInEther() internal view returns (uint256 debtProportionRateInEther) {
        if (totalOutstandingDebt == 0 || totalDebtProportion == 0) {
            return 1 ether;
        }
        debtProportionRateInEther = (totalOutstandingDebt * 1 ether) / totalDebtProportion;
    }

    /// @notice getOutstandingDebt returns the debt owed by the RISE/DROP tokens
    function getOutstandingDebt(address token) public view returns (uint256) {
        // If there is no debt, return 0
        if (totalOutstandingDebt == 0) return 0;
        // Calculate the outstanding debt
        // outstanding debt = debtProportion * debtProportionRate
        uint256 debtProportionRateInEther = getDebtProportionRateInEther();
        uint256 a = (debtProportion[token] * debtProportionRateInEther);
        uint256 b = 1 ether;
        uint256 outstandingDebt = a / b + (a % b == 0 ? 0 : 1); // Rounds up instead of rounding down
        return outstandingDebt;
    }

    /// @notice setBorrowStates sets the debt of the RISE/DROP token
    function setBorrowStates(address token, uint256 borrowAmount) internal {
        uint256 debtProportionRateInEther = getDebtProportionRateInEther();
        totalOutstandingDebt += borrowAmount;
        uint256 borrowProportion = (borrowAmount * 1 ether) / debtProportionRateInEther;
        totalDebtProportion += borrowProportion;
        debtProportion[token] = debtProportion[token] + borrowProportion;
    }

    /// @notice setRepayStates repay the debt of the RISE tokens
    function setRepayStates(address token, uint256 repayAmount) internal {
        uint256 debtProportionRateInEther = getDebtProportionRateInEther();
        // Handle repay amount larger than existing total debt
        if (repayAmount > totalOutstandingDebt) {
            totalOutstandingDebt = 0;
        } else {
            totalOutstandingDebt -= repayAmount;
        }
        uint256 repayProportion = (repayAmount * 1 ether) / debtProportionRateInEther;
        if (repayProportion > totalDebtProportion) {
            totalDebtProportion = 0;
        } else {
            totalDebtProportion -= repayProportion;
        }
        if (repayProportion > debtProportion[token]) {
            debtProportion[token] -= 0;
        } else {
            debtProportion[token] -= repayProportion;
        }
    }

    /// @notice setVaultParameters updates the vault parameters.
    function setVaultParameters(
        uint256 u,
        uint256 s1,
        uint256 s2,
        uint256 mr,
        uint256 fee
    ) external onlyOwner {
        // Update vault parameters
        optimalUtilizationRateInEther = u;
        interestSlope1InEther = s1;
        interestSlope2InEther = s2;
        maxBorrowRatePerSecondInEther = mr;
        performanceFeeInEther = fee;

        emit ParametersUpdated(msg.sender, u, s1, s2, mr, fee);
    }

    /// @notice getVaultParameters returns the current vault parameters.
    function getVaultParameters()
        external
        view
        returns (
            uint256 _optimalUtilizationRateInEther,
            uint256 _interestSlope1InEther,
            uint256 _interestSlope2InEther,
            uint256 _maxBorrowRatePerSecondInEther,
            uint256 _performanceFeeInEther
        )
    {
        _optimalUtilizationRateInEther = optimalUtilizationRateInEther;
        _interestSlope1InEther = interestSlope1InEther;
        _interestSlope2InEther = interestSlope2InEther;
        _maxBorrowRatePerSecondInEther = maxBorrowRatePerSecondInEther;
        _performanceFeeInEther = performanceFeeInEther;
    }

    /// @notice setFeeRecipient sets the fee recipient address.
    function setFeeRecipient(address account) external onlyOwner {
        FEE_RECIPIENT = account;
        emit FeeRecipientUpdated(msg.sender, account);
    }

    /// @notice collectVaultPendingFees withdraws collected fees to the FEE_RECIPIENT address
    function collectVaultPendingFees() external {
        accrueInterest(); // Accrue interest
        uint256 collectedFees = totalPendingFees;
        IERC20(underlyingToken).safeTransfer(FEE_RECIPIENT, collectedFees);
        totalPendingFees = 0;

        emit FeeCollected(msg.sender, collectedFees, FEE_RECIPIENT);
    }

    /// @notice setVaultMaxTotalDeposit sets the max total deposit of the vault
    function setVaultMaxTotalDeposit(uint256 amount) external onlyOwner {
        maxTotalDeposit = amount;
    }
}
