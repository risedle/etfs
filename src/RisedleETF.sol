// SPDX-License-Identifier: GPL-3.0-or-later

// Risedle's ETF Contract
// The 2x Leveraged version of any ERC20
//
// I wrote this for ETHOnline Hackathon 2021. Enjoy.

// Copyright (c) 2021 Bayu - All rights reserved
// github: pyk

pragma solidity ^0.8.7;
pragma experimental ABIEncoderV2;

import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessControl} from "lib/openzeppelin-contracts/contracts/access/AccessControl.sol";

import "./IRisedleVault.sol";

/// @title Risedle ETF
contract RisedleETF is ERC20, AccessControl {
    using SafeERC20 for IERC20;

    /// @notice The underlying assets address contract (ERC20)
    address public immutable underlying;

    /// @notice The ETF's governor address
    address public governor;

    /// @notice The ETF's fee receiver address
    address public feeReceiver;

    /// @notice The Risedle Vault address
    address public vault;

    /// @notice To make sure that setupVault only run once
    bool private vaultAdded;

    /// @notice The ETF's initial price in term of vault's underlying address
    /// @dev For example 100 USDT would be 100 * 1e6, coz USDT have 6 decimals
    uint256 public immutable INITIAL_ETF_PRICE;

    /**
     * @notice Construct new ETF
     * @param name The ETF's name
     * @param symbol The ETF's token symbol
     * @param underlying_ The ERC20 contract address of underlying asset
     * @param governor_ The account address that govern the ETF
     * @param feeReceiver_ The account address that receive the ETF fee
     * @param initialETFPrice The initial ETF price in term of vault's underlying asset
     */
    constructor(
        string memory name,
        string memory symbol,
        address underlying_,
        address governor_,
        address feeReceiver_,
        uint256 initialETFPrice
    ) ERC20(name, symbol) {
        // Sanity checks
        IERC20(underlying_).totalSupply();

        // Set the underlying ETF's asset
        underlying = underlying_;

        // Set the governor role
        governor = governor_;
        _setupRole(DEFAULT_ADMIN_ROLE, governor_);

        // Set the fee receiver address
        feeReceiver = feeReceiver_;

        // Set the initial price
        INITIAL_ETF_PRICE = initialETFPrice;
    }

    /**
     * @notice setVault sets the ETF's vault
     * @param vault_ The Risedle Vault address
     */
    function setVault(address vault_) public {
        require(!vaultAdded, "ALREADY_INITIALIZED");

        // Set vaultAdded to true
        vaultAdded = true;

        // Sanity check
        IRisedleVault(vault_).totalOutstandingDebt();

        // Set the vault address
        vault = vault_;
    }

    /// @notice getTotalSupply returns the total supply of the ETF token
    function getTotalSupply() internal view returns (uint256) {
        IERC20 etfToken = IERC20(address(this));
        return etfToken.totalSupply();
    }
}
