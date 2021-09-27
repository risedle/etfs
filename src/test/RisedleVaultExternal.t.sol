// SPDX-License-Identifier: GPL-3.0-or-later

// Risedle's Vault External Test
// Test & validate user/contract interaction with Risedle's Vault

pragma solidity ^0.8.7;
pragma experimental ABIEncoderV2;

import "lib/ds-test/src/test.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

import {HEVM} from "./utils/HEVM.sol";
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

/// @notice Dummy contract to simulate the lender
contract Lender {
    using SafeERC20 for IERC20;

    // Vault
    RisedleVault private _vault;
    IERC20 underlying;

    constructor(RisedleVault vault) {
        _vault = vault;
        underlying = IERC20(vault.underlying());
    }

    /// @notice lender supply asset
    function lend(uint256 amount) public {
        // approve vault to spend the underlying asset
        underlying.safeApprove(address(_vault), type(uint256).max);

        // Supply asset
        _vault.mint(amount);
    }

    /// @notice lender remove asset
    function withdraw(uint256 amount) public {
        // approve vault to spend the vault token
        _vault.approve(address(_vault), type(uint256).max);

        // Withdraw asset
        _vault.burn(amount);
    }
}

contract RisedleVaultExternalTest is DSTest {
    // Test utils
    address constant USDT_ADDRESS = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    IERC20 constant USDT = IERC20(USDT_ADDRESS);
    HEVM hevm;

    /// @notice Run the test setup
    function setUp() public {
        hevm = new HEVM();
    }

    /// @notice Utility function to create new vault
    function createNewVault() internal returns (RisedleVault) {
        // Create new vault
        address vaultAdmin = address(this); // Set this contract as admin
        RisedleVault vault = new RisedleVault(
            "Risedle USDT Vault",
            "rvUSDT",
            USDT_ADDRESS,
            vaultAdmin
        );
        return vault;
    }

    /// @notice Make sure the admin is properly set
    function test_AdminIsProperlySet() public {
        // Create new vault
        RisedleVault vault = createNewVault();

        // Make sure the admin is set
        assertTrue(vault.hasRole(vault.DEFAULT_ADMIN_ROLE(), vault.admin()));

        // Check with non-admin address
        address nonAdmin = hevm.addr(2); // random address
        assertFalse(vault.hasRole(vault.DEFAULT_ADMIN_ROLE(), nonAdmin));
    }

    /// @notice Make sure admin can grant borrower role
    function test_AdminCanGrantBorrower() public {
        // Create new vault
        RisedleVault vault = createNewVault();

        // Create new borrower actor
        Borrower borrower = new Borrower(vault);

        // Grant borrower
        vault.grantAsBorrower(address(borrower));

        // Make sure the role has been set
        assertTrue(vault.isBorrower(address(borrower)));

        // Even the admin itself is not borrower
        assertFalse(vault.isBorrower(vault.admin()));
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
        uint256 lenderBalance = USDT.balanceOf(address(lender));
        assertEq(amount, lenderBalance);

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
        uint256 lenderBalance = USDT.balanceOf(address(lender));
        assertEq(amount, lenderBalance);

        // Lender add supply to the vault
        lender.lend(amount);
        assertEq(USDT.balanceOf(address(vault)), amount);

        // Lender remove supply from the vault
        lender.withdraw(amount);

        // Lender vault token should be burned
        uint256 lenderVaultTokenBalance = vault.balanceOf(address(lender));
        assertEq(lenderVaultTokenBalance, 0);

        // The lender should receive the USDT back
        assertEq(USDT.balanceOf(address(lender)), amount);
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
        vault.grantAsBorrower(address(borrower));

        // Borrow 80 USDT
        borrower.borrow(80 * 1e6);

        // Utilization rate is 80%, borrow APY 19.45%
        // After 5 days, the vault token should worth 100.175 USDT
        hevm.warp(previousTimestamp + (60 * 60 * 24 * 5));
        uint256 expectedLenderVaultTokenWorth = 100175342;

        // Get the current exchange rate
        uint256 exhangeRateInEther = vault.getCurrentExchangeRateInEther();
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
        vault.grantAsBorrower(address(borrower));

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

    /// @notice Make sure unauthorized borrower cannot borrow
    function testFail_UnauthorizedBorrowerCannotBorrowFromTheVault() public {
        // Create new vault
        RisedleVault vault = createNewVault();

        // Add supply to the vault
        Lender lender = new Lender(vault);
        hevm.setUSDTBalance(address(lender), 1000 * 1e6); // 1000 USDT
        lender.lend(1000 * 1e6); // 1000 USDT

        // Unauthorized borrower borrow from the vault
        Borrower unauthorizedBorrower = new Borrower(vault);
        unauthorizedBorrower.borrow(100 * 1e6); // 100 USDT
    }

    /// @notice Make sure authorized borrower can borrow
    function test_AuthorizedBorrowerCanBorrowFromTheVault() public {
        // Create new vault
        RisedleVault vault = createNewVault();

        // Add supply to the vault
        Lender lender = new Lender(vault);
        hevm.setUSDTBalance(address(lender), 1000 * 1e6); // 1000 USDT
        lender.lend(1000 * 1e6); // 1000 USDT

        // Authorized borrower borrow from the vault
        Borrower authorizedBorrower = new Borrower(vault);
        vault.grantAsBorrower(address(authorizedBorrower));

        // Borrow underlying asset
        uint256 borrowAmount = 100 * 1e6;
        authorizedBorrower.borrow(borrowAmount); // 100 USDT

        // Make sure the vault states are updated
        assertEq(vault.totalOutstandingDebt(), borrowAmount);
        assertEq(vault.totalPrincipalBorrowed(), borrowAmount);
        assertEq(
            vault.getOutstandingDebt(address(authorizedBorrower)),
            borrowAmount
        );

        // Make sure the underlying asset is transfered to the borrower
        assertEq(USDT.balanceOf(address(authorizedBorrower)), borrowAmount);
    }

    /// @notice Make sure unauthorized borrower cannot repay
    function testFail_UnauthorizedBorrowerCannotRepayToTheVault() public {
        // Create new vault
        RisedleVault vault = createNewVault();

        // Unauthorized borrower repay from the vault
        Borrower unauthorizedBorrower = new Borrower(vault);
        hevm.setUSDTBalance(address(unauthorizedBorrower), 100 * 1e6); // 100 USDT
        unauthorizedBorrower.repay(100 * 1e6); // 100 USDT
    }

    /// @notice Make sure authorized borrower can borrow
    function test_AuthorizedBorrowerCanRepayToTheVault() public {
        // Although we do the borrow & repay, it does accrue the interest
        // But it doesn't change the outstanding debt due to the delta timestamp
        // or elapses seconds is zero

        // Create new vault
        RisedleVault vault = createNewVault();

        // Add supply to the vault
        uint256 supplyAmount = 1000 * 1e6;
        Lender lender = new Lender(vault);
        hevm.setUSDTBalance(address(lender), supplyAmount); // 1000 USDT
        lender.lend(supplyAmount); // 1000 USDT

        // Authorized borrower borrow from the vault
        Borrower authorizedBorrower = new Borrower(vault);
        vault.grantAsBorrower(address(authorizedBorrower));

        // Borrow underlying asset
        uint256 borrowAmount = 100 * 1e6; // 100 USDT
        uint256 repayAmount = 50 * 1e6; // 50 USDT
        authorizedBorrower.borrow(borrowAmount);
        authorizedBorrower.repay(repayAmount);

        // Make sure the underlying asset is transfered to the borrower & the vault
        assertEq(
            USDT.balanceOf(address(authorizedBorrower)),
            borrowAmount - repayAmount
        );
        assertEq(
            USDT.balanceOf(address(vault)),
            supplyAmount - (borrowAmount - repayAmount)
        );

        // Make sure the outstanding debt is correct
        assertEq(
            vault.getOutstandingDebt(address(authorizedBorrower)),
            borrowAmount - repayAmount
        );
    }
}
