// SPDX-License-Identifier: GPL-3.0-or-later

// Risedle's Vault External Test
// Test & validate user/contract interaction with Risedle's Vault

pragma solidity 0.8.9;
pragma experimental ABIEncoderV2;

import "lib/ds-test/src/test.sol";

import {RisedleVault} from "../../vaults/RisedleVault.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

import {Hevm} from "../Hevm.sol";

import {USDC_ADDRESS} from "chain/Constants.sol";

/// @notice Dummy contract to simulate the lender
contract Lender {
    using SafeERC20 for IERC20;

    // Vault
    RisedleVault private _vault;

    constructor(RisedleVault vault) {
        _vault = vault;
    }

    /// @notice lender supply asset
    function lend(uint256 amount) public {
        // Approve the vault to spend underlying token
        IERC20(_vault.getUnderlying()).safeApprove(address(_vault), amount);

        // Supply asset
        _vault.addSupply(amount);

        // Reset approval to zero
        IERC20(_vault.getUnderlying()).safeApprove(address(_vault), 0);
    }
}

/**
 * @notice Test the RisedleVault implementation
 */
contract RisedleVaultExternalTest is DSTest {
    Hevm hevm;

    /// @notice Run the test setup
    function setUp() public {
        hevm = new Hevm();
    }

    /// @notice utility to create new vault
    function createNewVault() internal returns (RisedleVault) {
        return new RisedleVault("Risedle USDC Vault", "rvUSDC", USDC_ADDRESS);
    }

    /// @notice Make sure the rvToken public properties is correct
    function test_VaultTokenPublicProperties() public {
        // Create new vault
        RisedleVault vault = createNewVault();

        // Make sure the underlying is USDC
        assertEq(vault.getUnderlying(), USDC_ADDRESS);

        // Make sure it have the same decimals as the underlying
        assertEq(vault.decimals(), 6); // USDC have 6 decimals
    }

    /// @notice Make sure anyone can supply asset to the vault
    function test_AnyoneCanAddSupplytToTheVault() public {
        // Create new vault
        RisedleVault vault = createNewVault();

        // Create new lender
        Lender lender = new Lender(vault);

        // Set the lender USDC balance
        uint256 amount = 1000 * 1e6; // 1000 USDC
        hevm.setUSDCBalance(address(lender), amount);

        // Lender add supply to the vault
        lender.lend(amount);

        // Lender should receive the same amount of vault token
        // Because the initial exchange rate is 1:1
        uint256 lenderVaultTokenBalance = vault.balanceOf(address(lender));
        assertEq(lenderVaultTokenBalance, amount);

        // The vault should receive the USDC
        assertEq(IERC20(USDC_ADDRESS).balanceOf(address(vault)), amount);

        // The vault borrow rate and supply rate should be zero
        assertEq(vault.getBorrowRatePerSecondInEther(), 0);
        assertEq(vault.getSupplyRatePerSecondInEther(), 0);

        // The total available cash should be equal to amount
        assertEq(vault.getTotalAvailableCash(), amount);

        // The exchange rate should be 1:1
        assertEq(vault.getExchangeRateInEther(), 1 ether);
    }
}
