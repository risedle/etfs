// SPDX-License-Identifier: GPL-3.0-or-later

// RisedleUSD is a lending pool
// The interest rate model is available here: https://observablehq.com/@pyk/ethrise
// I wrote this for ETHOnline Hackathon 2021. Enjoy.

// Copyright (c) 2021 Bayu - All rights reserved
// github: pyk

pragma solidity ^0.8.7;
pragma experimental ABIEncoderV2;

import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessControl} from "lib/openzeppelin-contracts/contracts/access/AccessControl.sol";

/// @title Risedle's Lending Pool Contract
contract RisedleUSD is ERC20, AccessControl {
    using SafeERC20 for IERC20;

    /// @notice Only valid borrower can borrow and repay underlying assets
    bytes32 public constant BORROWER_ROLE = keccak256("BORROWER_ROLE");

    /// @notice The underlying assets address contract (ERC20)
    address public immutable underlying;

    /// @notice The admin address
    address public immutable admin;

    /**
     * @notice Construct new lending pool
     * @param name The token name
     * @param symbol The token symbol
     * @param underlying_ The ERC20 contract address of underlying asset
     * @param admin_ The admin address
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

        // Setup admin role
        admin = admin_;
        _setupRole(DEFAULT_ADMIN_ROLE, admin_);
    }

    /**
     * @notice Similar to cToken decimals
     * @dev https://docs.openzeppelin.com/contracts/4.x/erc20#a-note-on-decimals
     */
    function decimals() public view virtual override returns (uint8) {
        return 8;
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
}
