// SPDX-License-Identifier: GPL-3.0-or-later

// Risedle's Vault Contract Interface
// The money market protocol that powers Risedle ETFs.
//
// Risedle uses ether units (1e18) precision to represent the interest rates.
// Learn more here: https://docs.soliditylang.org/en/v0.8.7/units-and-global-variables.html
//
// I wrote this for ETHOnline Hackathon 2021. Enjoy.

// Copyright (c) 2021 Bayu - All rights reserved
// github: pyk

pragma solidity ^0.8.7;
pragma experimental ABIEncoderV2;

interface IRisedleVault {
    /// @notice The Vault's underlying ERC20 contract
    function underlying() external view returns (address);

    /// @notice The Vault's governor address
    function governor() external view returns (address);

    /// @notice The Vault's fee receiver address
    function feeReceiver() external view returns (address);

    /// @notice The Vault's total outstanding debt
    function totalOutstandingDebt() external view returns (address);

    /// @notice The Vault's pending fees
    function totalPendingFees() external view returns (uint256);

    /// @notice The Vault's optimal utilization rate in ether units
    function OPTIMAL_UTILIZATION_RATE_IN_ETHER()
        external
        view
        returns (uint256);

    /// @notice The Vault's interest rate model slope 1 in ether units
    function INTEREST_SLOPE_1_IN_ETHER() external view returns (uint256);

    /// @notice The Vault's interest rate model slope 2 in ether units
    function INTEREST_SLOPE_2_IN_ETHER() external view returns (uint256);

    /// @notice The Vault's max borrow rate per second in ether units
    function MAX_BORROW_RATE_PER_SECOND_IN_ETHER()
        external
        view
        returns (uint256);

    /// @notice The Vault's performance fee for the lender in ether units
    function PERFORMANCE_FEE_IN_ETHER() external view returns (uint256);

    /// @notice The Vault's last timestamp accrued
    function lastTimestampInterestAccrued() external view returns (uint256);

    /// @notice The Vault's token decimals
    function decimals() external view returns (uint256);

    /// @notice isBorrower returns true if account is borrower
    function isBorrower(address account) external view returns (bool);

    /// @notice getTotalAvailableCash returns the total cash available to borrow
    function getTotalAvailableCash() external view returns (uint256);

    /// @notice getUtilizationRateInEther returns current utilization rate in ether units
    function getUtilizationRateInEther(address account)
        external
        view
        returns (uint256);

    /// @notice getBorrowRatePerSecondInEther returns current vault's borrow rate per second in ether units
    function getBorrowRatePerSecondInEther(address account)
        external
        view
        returns (uint256);

    /// @notice accrueInterest accrue the vault's interest
    function accrueInterest() external;

    /// @notice Add supply to the vault
    function mint(uint256 amount) external;

    /// @notice Remove asset from the vault
    function burn(uint256 amount) external;

    /// @notice getOutstandingDebt returns the debt owed by the borrower
    function getOutstandingDebt(address account)
        external
        view
        returns (uint256);

    /// @notice getDebtProportion returns the debt proportion of total outstanding debt owed by the borrower
    function getDebtProportion(address account) external view returns (uint256);

    /// @notice Borrow asset from the vault
    /// @dev Only authorized borrower can call this function
    function borrow(uint256 amount) external;

    /// @notice Repay asset to the vault
    /// @dev Only authorized borrower can call this function
    function repay(uint256 amount) external;

    /// @notice Collect pending fees and send it to the fee receiver address
    /// @dev Only authorized borrower can call this function
    function collectPendingFees() external;

    /// @notice updateFeeReceiver updates the fee receiver address
    /// @dev Only governor can call this function
    function updateFeeReceiver(address account) external;
}
