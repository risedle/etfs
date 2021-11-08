// SPDX-License-Identifier: GPL-3.0-or-later

// Risedle Vault Contract
// It implements money market for Risedle RISE tokens and DROP tokens.
//
// Copyright (c) 2021 Bayu - All rights reserved
// github: pyk
// email: bayu@risedle.com
pragma solidity 0.8.9;
pragma experimental ABIEncoderV2;

import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {IERC20Metadata} from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

/// @title Risedle Vault
contract RisedleVault is ERC20, Ownable {
    /// @notice Vault's underlying token address
    address internal vaultUnderlyingToken;

    /**
     * @notice Consturct new RisedleVault
     * @param name The name of the vault's token (e.g. Risedle USDC Vault)
     * @param symbol The symbol of the vault's token (e.g rvUSDC)
     * @param underlying The ERC20 address of the vault's underlying token (e.g. address of USDC token)
     */
    constructor(
        string memory name,
        string memory symbol,
        address underlying
    ) ERC20(name, symbol) {
        // Set the vault underlying token
        vaultUnderlyingToken = underlying;
    }

    /**
     * @notice Vault's token use the same decimals as the underlying
     */
    function decimals() public view virtual override returns (uint8) {
        return IERC20Metadata(vaultUnderlyingToken).decimals();
    }
}
