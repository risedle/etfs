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
    /// @notice The Vault's total outstanding debt
    function totalOutstandingDebt() external view returns (address);

    /// @notice The Vault's pending fees
    function totalPendingFees() external view returns (uint256);

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

    /// @notice serFeeRecipient updates the fee receiver address
    /// @dev Only governor can call this function
    function serFeeRecipient(address account) external;
}
