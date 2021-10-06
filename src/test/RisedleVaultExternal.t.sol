// SPDX-License-Identifier: GPL-3.0-or-later

// Risedle's Vault External Test
// Test & validate user/contract interaction with Risedle's Vault

pragma solidity ^0.8.7;
pragma experimental ABIEncoderV2;

import "lib/ds-test/src/test.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

// chain/* is replaced by DAPP_REMAPPINGS at compile time,
// this allow us to use custom address on specific chain
// See .dapprc
import {USDT_ADDRESS} from "chain/Constants.sol";

import {Hevm} from "./Hevm.sol";
import {Lender} from "./Lender.sol";
import {Borrower} from "./Borrower.sol";
import {RisedleVault} from "../RisedleVault.sol";

contract RisedleVaultExternalTest is DSTest {
    // Test utils
    IERC20 constant USDT = IERC20(USDT_ADDRESS);
    Hevm hevm;

    /// @notice Run the test setup
    function setUp() public {
        hevm = new Hevm();
    }

    /// @notice Utility function to create new vault
    function createNewVault() internal returns (RisedleVault) {
        // Create new vault
        RisedleVault vault = new RisedleVault(
            "Risedle USDT Vault",
            "rvUSDT",
            USDT_ADDRESS,
            6
        );
        return vault;
    }

    /// @notice Make sure the lender can supply asset to the vault
    function test_LenderCanAddSupplytToTheVault() public {
        // Create new vault
        RisedleVault vault = createNewVault();

        // Create new lender
        Lender lender = new Lender(vault);

        // Set the lender USDT balance
        uint256 amount = 1000 * 1e6; // 1000 USDT
        hevm.setUSDTBalance(address(lender), amount);

        // Lender add supply to the vault
        lender.lend(amount);

        // Lender should receive the same amount of vault token
        uint256 lenderVaultTokenBalance = vault.balanceOf(address(lender));
        assertEq(lenderVaultTokenBalance, amount);

        // The vault should receive the USDT
        assertEq(USDT.balanceOf(address(vault)), amount);
    }

    /// @notice Make sure the lender can remove asset from the vault
    function test_LenderCanRemoveSupplyFromTheVault() public {
        // Create new vault
        RisedleVault vault = createNewVault();

        // Create new lender
        Lender lender = new Lender(vault);

        // Set the lender USDT balance
        uint256 amount = 1000 * 1e6; // 1000 USDT
        hevm.setUSDTBalance(address(lender), amount);

        // Lender add supply to the vault
        lender.lend(amount);

        // Make sure the vault receive the asset
        assertEq(USDT.balanceOf(address(vault)), amount);

        // Lender remove supply from the vault
        lender.withdraw(amount);

        // Lender vault token should be burned
        uint256 lenderVaultTokenBalance = vault.balanceOf(address(lender));
        assertEq(lenderVaultTokenBalance, 0);

        // The lender should receive the USDT back
        assertEq(USDT.balanceOf(address(lender)), amount);

        // Not the vault should have zero USDT
        assertEq(USDT.balanceOf(address(vault)), 0);
    }

    /// @notice Make sure the lender earn interest
    function test_LenderShouldEarnInterest() public {
        // Create new vault
        RisedleVault vault = createNewVault();

        // Set the timestamp
        uint256 previousTimestamp = block.timestamp;
        hevm.warp(previousTimestamp);

        // Create new lender and borrower
        Lender lender = new Lender(vault);
        Borrower borrower = new Borrower(vault);

        // Set lender balance
        hevm.setUSDTBalance(address(lender), 100 * 1e6); // 100 USDT

        // Supply asset to the vault
        lender.lend(100 * 1e6);

        // Grant borrower access
        vault.setAsBorrower(address(borrower));

        // Borrow 80 USDT
        borrower.borrow(80 * 1e6);

        // Utilization rate is 80%, borrow APY 19.45%
        // After 5 days, the vault token should worth 100.175 USDT
        hevm.warp(previousTimestamp + (60 * 60 * 24 * 5));
        uint256 expectedLenderVaultTokenWorth = 100175342;

        // Get the current exchange rate
        vault.accrueInterest();
        uint256 exhangeRateInEther = vault.getExchangeRateInEther();
        uint256 lenderVaultTokenBalance = vault.balanceOf(address(lender));
        uint256 lenderVaultTokenWorth = (lenderVaultTokenBalance *
            exhangeRateInEther) / 1 ether;

        // Make sure the lender earn interest
        assertEq(lenderVaultTokenWorth, expectedLenderVaultTokenWorth);
    }

    /// @notice Make sure the lenders earn interest proportionally
    function test_LendersShouldEarnInterestProportionally() public {
        // Create new vault
        RisedleVault vault = createNewVault();

        // Set the timestamp
        uint256 previousTimestamp = block.timestamp;
        hevm.warp(previousTimestamp);

        // Create new lender and borrower
        Lender lenderA = new Lender(vault);
        Lender lenderB = new Lender(vault);
        Borrower borrower = new Borrower(vault);

        // Set lender balance
        hevm.setUSDTBalance(address(lenderA), 100 * 1e6); // 100 USDT
        hevm.setUSDTBalance(address(lenderB), 100 * 1e6); // 100 USDT

        // Lender A lend asset to the vault
        lenderA.lend(100 * 1e6);

        // Grant borrower access
        vault.setAsBorrower(address(borrower));

        // Borrow 80 USDT
        borrower.borrow(80 * 1e6);

        // Utilization rate is 80%, borrow APY 19.45%
        // After 5 days, then accrue interest
        hevm.warp(previousTimestamp + (60 * 60 * 24 * 5));

        // Lend & withdraw in the same timestamp
        // The lender B should not get the interest
        // Interest should automatically accrued when lender lend asset
        lenderB.lend(100 * 1e6); // 100 USDT
        uint256 lenderBVaultTokenBalance = vault.balanceOf(address(lenderB));

        // Lender B redeem all vault tokens
        lenderB.withdraw(lenderBVaultTokenBalance);

        // The lender B USDT balance should be back without interest
        uint256 lenderBUSDTBalance = USDT.balanceOf(address(lenderB));
        assertEq(lenderBUSDTBalance, 99999999); // 99.99 USDT Rounding down shares
    }

    /// @notice Borrower debt should increased when the interest is accrued
    function test_BorrowersDebtShouldIncreasedProportionally() public {
        // Create new vault
        RisedleVault vault = createNewVault();

        // Set the timestamp
        uint256 previousTimestamp = block.timestamp;
        hevm.warp(previousTimestamp);

        // Add supply to the vault
        Lender lender = new Lender(vault);
        hevm.setUSDTBalance(address(lender), 100 * 1e6); // 100 USDT
        lender.lend(100 * 1e6); // 100 USDT

        // Create new authorized borrowers
        Borrower borrowerA = new Borrower(vault);
        Borrower borrowerB = new Borrower(vault);
        vault.setAsBorrower(address(borrowerA));
        vault.setAsBorrower(address(borrowerB));

        // Borrower A borrow 40 USDT
        borrowerA.borrow(40 * 1e6);
        assertEq(vault.getOutstandingDebt(address(borrowerA)), 40 * 1e6);

        // Total debt should be correct
        assertEq(vault.totalOutstandingDebt(), 40 * 1e6); // 40 USDT so far

        // Total collected fees should be correct
        assertEq(vault.totalPendingFees(), 0); // 0 USDT so far

        // After 5 days, then accrue interest
        hevm.warp(previousTimestamp + (60 * 60 * 24 * 5));
        previousTimestamp = previousTimestamp + (60 * 60 * 24 * 5);

        // Accrue interest
        vault.accrueInterest();

        // The debt of borrower A should be increased
        assertEq(vault.getOutstandingDebt(address(borrowerA)), 40048706);

        // Total debt should be correct
        assertEq(vault.totalOutstandingDebt(), 40048706); // 40.04870624 USDT so far

        // Borrower B borrow 50 USDT
        borrowerB.borrow(50 * 1e6);

        // The debt should correct
        assertEq(vault.getOutstandingDebt(address(borrowerB)), 50 * 1e6);

        // Total debt should be correct
        assertEq(vault.totalOutstandingDebt(), 40048706 + (50 * 1e6)); // 90.04870624 USDT so far

        // Total collected fees should be correct
        assertEq(vault.totalPendingFees(), 4870); // 0.004870624049 USDT so far

        // Next 5 days again
        hevm.warp(previousTimestamp + (60 * 60 * 24 * 5));

        // Accrue interest
        vault.accrueInterest();

        // Total outstanding debt should be correct
        assertEq(vault.totalOutstandingDebt(), 90296100);
        assertEq(
            vault.totalOutstandingDebt() + 1, // Rounding error 0.000001 USDT expected
            vault.getOutstandingDebt(address(borrowerA)) +
                vault.getOutstandingDebt(address(borrowerB))
        );

        // Total outstanding debt for borrower A should be correct
        assertEq(vault.getOutstandingDebt(address(borrowerA)), 40158734); // 40.15873349 USDT

        // Total outstanding debt for borrower A should be correct
        assertEq(vault.getOutstandingDebt(address(borrowerB)), 50137367); // 50.1373668 USDT
    }
}
