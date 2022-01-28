// SPDX-License-Identifier: GPL-3.0-or-later

// Risedle's Vault External Test
// Test & validate user/contract interaction with Risedle's Vault

pragma solidity >=0.8.9;
pragma experimental ABIEncoderV2;

import "lib/ds-test/src/test.sol";

import { RisedleVault } from "../RisedleVault.sol";
import { IERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

import { Hevm } from "./Hevm.sol";

import { USDC_ADDRESS } from "chain/Constants.sol";

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

    /// @notice lender remove asset
    function withdraw(uint256 amount) public {
        // Approve the vault to spend the vault token
        IERC20(address(_vault)).safeApprove(address(_vault), amount);

        // Supply asset
        _vault.removeSupply(amount);

        // Reset approval to zero
        IERC20(address(_vault)).safeApprove(address(_vault), 0);
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
        return new RisedleVault("Risedle USDC Vault", "rvUSDC", USDC_ADDRESS, address(this));
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
    function test_AnyoneCanAddSupplyToTheVault() public {
        // Create new vault
        RisedleVault vault = createNewVault();

        // Create new lender
        Lender lender = new Lender(vault);

        // Set the lender USDC balance
        uint256 amount = 1000 * 1e6; // 1000 USDC
        hevm.setUSDCBalance(address(lender), amount);

        // Lender add supply to the vault
        lender.lend(amount);

        // Set timestamp to next 5 days
        hevm.warp(block.timestamp + (60 * 24 * 5));

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

    /// @notice Make sure subsquent supply yield the same amount of rvToken
    function test_SubsequentSupplyToTheVault() public {
        // Create new vault
        RisedleVault vault = createNewVault();

        // Create new lender
        Lender lender = new Lender(vault);

        // Set the lender USDC balance
        uint256 amount = 1000 * 1e6; // 1000 USDC
        hevm.setUSDCBalance(address(lender), amount);

        // Lender add supply to the vault
        uint256 depositAmount = 500 * 1e6;
        lender.lend(depositAmount); // 500 USDC first

        // Lender should receive the same amount of vault token
        // Because the initial exchange rate is 1:1
        uint256 lenderVaultTokenBalance = vault.balanceOf(address(lender));
        assertEq(lenderVaultTokenBalance, depositAmount);

        // The vault should receive the USDC
        assertEq(IERC20(USDC_ADDRESS).balanceOf(address(vault)), depositAmount);

        // Lender add supply once again
        lender.lend(depositAmount); // 500 USDC second
        assertEq(vault.balanceOf(address(lender)), depositAmount * 2);
        assertEq(IERC20(USDC_ADDRESS).balanceOf(address(vault)), depositAmount * 2);
    }

    /// @notice Make sure anyone can remove asset from the vault
    function test_AnyoneCanRemoveSupplyFromTheVault() public {
        // Create new vault
        RisedleVault vault = createNewVault();

        // Create new lender
        Lender lender = new Lender(vault);

        // Set the lender USDC balance
        uint256 amount = 1000 * 1e6; // 1000 USDC
        hevm.setUSDCBalance(address(lender), amount);

        // Lender add supply to the vault
        lender.lend(amount);

        // Set timestamp to next 5 days
        hevm.warp(block.timestamp + (60 * 24 * 5));

        // Lender remove supply from the vault
        lender.withdraw(amount);

        // The vault's token should be burned
        assertEq(IERC20(address(vault)).totalSupply(), 0);
        assertEq(IERC20(address(vault)).balanceOf(address(lender)), 0);

        // Because the exchange rate is 1:1 lender should receive all
        // the USDC back
        assertEq(IERC20(USDC_ADDRESS).balanceOf(address(lender)), amount);

        // The vault should have zero USDC
        assertEq(IERC20(USDC_ADDRESS).balanceOf(address(vault)), 0);

        // The vault borrow rate and supply rate should be zero
        assertEq(vault.getBorrowRatePerSecondInEther(), 0);
        assertEq(vault.getSupplyRatePerSecondInEther(), 0);

        // The total available cash should be equal to zero
        assertEq(vault.getTotalAvailableCash(), 0);

        // The exchange rate should be 1:1
        assertEq(vault.getExchangeRateInEther(), 1 ether);
    }

    /// @notice Make sure the max cap is working
    function testFail_CannotAddSupplyWhenCapIsReached() public {
        // Create new vault
        RisedleVault vault = createNewVault();

        // Set max cap to 20_000 USDC
        vault.setVaultMaxTotalDeposit(20_000 * 1e6);

        // Create new lender
        Lender lender = new Lender(vault);

        // Set the lender USDC balance
        uint256 amount = 19_000 * 1e6; // 19_000 USDC
        hevm.setUSDCBalance(address(lender), amount);

        // Lender add supply to the vault
        lender.lend(amount);

        // Supply again this should be failed
        lender.lend(amount);
    }

    /// @notice Make sure subsequent redeem is working correctly
    function test_SubsequentRemoveSupply() public {
        // Create new vault
        RisedleVault vault = createNewVault();

        // Create new lender
        Lender lender = new Lender(vault);

        // Set the lender USDC balance
        uint256 amount = 1_000_000 * 1e6; // 1M USDC
        hevm.setUSDCBalance(address(lender), amount);

        // Lender add supply to the vault
        lender.lend(amount);

        // Set timestamp to next 5 days
        hevm.warp(block.timestamp + (60 * 24 * 5));

        // Lender remove supply from the vault
        lender.withdraw(0.5 * 1e6);

        // The vault's token should be burned
        assertEq(IERC20(address(vault)).totalSupply(), amount - (0.5 * 1e6));
        assertEq(IERC20(address(vault)).balanceOf(address(lender)), amount - (0.5 * 1e6));
        assertEq(IERC20(USDC_ADDRESS).balanceOf(address(lender)), 0.5 * 1e6);

        // Withdraw once again
        lender.withdraw(400_000 * 1e6);
        assertEq(IERC20(address(vault)).totalSupply(), amount - ((0.5 * 1e6) + (400_000 * 1e6)));
        assertEq(IERC20(address(vault)).balanceOf(address(lender)), amount - ((0.5 * 1e6) + (400_000 * 1e6)));
        assertEq(IERC20(USDC_ADDRESS).balanceOf(address(lender)), ((0.5 * 1e6) + (400_000 * 1e6)));
    }
}
