// SPDX-License-Identifier: GPL-3.0-or-later

// Risedle ERC20 Contract
// ERC20 contract to leverage and hedge token.
// It allows the owner to mint/burn token. On the production setup,
// only Risedle Vault can mint/burn this token.
// It's been validated using dapp tools HEVM verification.
//
// Copyright (c) 2021 Bayu - All rights reserved
// github: pyk
// email: bayu@risedle.com

pragma solidity >=0.8.9;
pragma experimental ABIEncoderV2;

import { ERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

/// @notice Risedle ERC20 implementation
contract RisedleERC20 is ERC20, Ownable {
    uint8 private _decimals;

    /// @notice Construct new Risedle ERC20 token
    /// @param name The ERC20 token name
    /// @param symbol The ERC20 token symbol
    /// @param owner The ERC20 owner contract
    /// @param decimals_ The ERC20 token decimals
    constructor(
        string memory name,
        string memory symbol,
        address owner,
        uint8 decimals_
    ) ERC20(name, symbol) {
        // Set the owner
        transferOwnership(owner);

        // Set the decimals
        _decimals = decimals_;
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    /// @notice mint mints new token to the specified address
    /// @dev Used when user deposit asset in the vault or mint new leverage/hedge
    ///      token. Only owner can call this function.
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    /// @notice burn burns the token from the specified address
    /// @dev Used when user withdraw asset in the vault or redeem  leverage/hedge
    ///      token. Only owner can call this function.
    function burn(address from, uint256 amount) external onlyOwner {
        _burn(from, amount);
    }
}
