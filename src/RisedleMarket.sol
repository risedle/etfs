// SPDX-License-Identifier: GPL-3.0-or-later

// Risedle Market Contract
// It allows the owner to create new Risedle Vault, Risedle Leverage Token and
// Risedle Hedge Token.
//
// Copyright (c) 2021 Bayu - All rights reserved
// github: pyk
// email: bayu@risedle.com

pragma solidity 0.8.9;
pragma experimental ABIEncoderV2;

import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {IERC20Metadata} from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {RisedleERC20} from "./tokens/RisedleERC20.sol";

/// @title Risedle Market
contract RisedleMarket is Ownable {
    /// @notice VaultMetadata contains the metadata and states of the vault
    struct VaultMetadata {
        address token; // Address of vault token ERC20, make sure this vault can mint & burn the token
        address underlying; // Vault underlying asset (e.g. USDC)
        address feed; // Vault underlying chainlink feed (e.g. USDC/USD)
        address feeRecipient; // Address of the vault fee recipient
        address implementation; // Address of the vault implementation
    }

    /// @notice Mapping Vault token to their metadata
    mapping(address => VaultMetadata) internal vaults;

    /// @notice Event emitted when new vault is created
    event NewVaultCreated(address indexed creator, address vaultToken);

    /**
     * @notice Consturct new Risedle market
     */
    constructor() {}

    /**
     * @notice createNewVault creates new Risedle Vault
     * @param tokenName The name of the vault's token (e.g. Risedle USDC Vault)
     * @param tokenSymbol The symbol of the vault's token (e.g. rvUSDC)
     * @param underlying The ERC20 address of the vault's underlying token (e.g. address of USDC token)
     * @param feed The Chainlink feed of the vault's underlying token (e.g. Chainlink USDC/USD feed)
     * @param feeRecipient The address of vault's fee recipient
     * @param implementation The address of the vault's implementation
     * @return The address of the vault token
     */
    function createNewVault(
        string memory tokenName,
        string memory tokenSymbol,
        address underlying,
        address feed,
        address feeRecipient,
        address implementation
    ) external onlyOwner returns (address) {
        // Get the decimals of the underlying token
        uint8 decimals = IERC20Metadata(underlying).decimals();

        // Create new Risedle Vault token and set this contract as the owner
        RisedleERC20 vaultToken = new RisedleERC20(
            tokenName,
            tokenSymbol,
            address(this),
            decimals
        );

        // Create new vault metadata
        address vaultTokenAddress = address(vaultToken);
        VaultMetadata memory vaultMetadata = VaultMetadata(
            vaultTokenAddress,
            underlying,
            feed,
            feeRecipient,
            implementation
        );

        // Map new vault's metadata to their token
        vaults[vaultTokenAddress] = vaultMetadata;

        // Emit the event
        emit NewVaultCreated(msg.sender, vaultTokenAddress);

        // Returns new created vault
        return vaultTokenAddress;
    }

    /**
     * @notice getVault gets vault metadata
     * @param vaultToken The address of the vault token
     * @return The vault metadata
     */
    function getVault(address vaultToken)
        external
        view
        returns (VaultMetadata memory)
    {
        return vaults[vaultToken];
    }
}
