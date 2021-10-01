// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.7;
pragma experimental ABIEncoderV2;

import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

import {RisedleVault} from "../RisedleVault.sol";

/// @notice Dummy contract to simulate the borrower
contract Borrower {
    using SafeERC20 for IERC20;

    // Vault
    RisedleVault private _vault;
    IERC20 underlying;

    constructor(RisedleVault vault) {
        _vault = vault;
        underlying = IERC20(vault.underlying());
    }

    function borrow(uint256 amount) public {
        _vault.borrow(amount);
    }

    function repay(uint256 amount) public {
        // approve vault to spend the underlying asset
        underlying.safeApprove(address(_vault), type(uint256).max);

        // Repay underlying asset
        _vault.repay(amount);
    }
}
