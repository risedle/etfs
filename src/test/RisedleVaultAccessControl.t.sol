// SPDX-License-Identifier: GPL-3.0-or-later

// Risedle's Vault Access Control Test
// Make sure the Governor ownership is working as expected

pragma solidity ^0.7.6;
pragma experimental ABIEncoderV2;

import "lib/ds-test/src/test.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/SafeERC20.sol";

// chain/* is replaced by DAPP_REMAPPINGS at compile time,
// this allow us to use custom address on specific chain
// See .dapprc
import {USDC_ADDRESS} from "chain/Constants.sol";

import {Hevm} from "./Hevm.sol";
import {Lender} from "./Lender.sol";
import {Borrower} from "./Borrower.sol";
import {RisedleVault} from "../RisedleVault.sol";

/// @notice Dummy contract to simulate random account to execute collect fee
contract FeeCollector {
    RisedleVault _vault;

    constructor(RisedleVault vault) {
        _vault = vault;
    }

    function collectPendingFees() public {
        _vault.collectPendingFees();
    }
}

contract RisedleVaultAccessControlTest is DSTest {
    // Test utils
    IERC20 constant USDC = IERC20(USDC_ADDRESS);
    Hevm hevm;

    /// @notice Run the test setup
    function setUp() public {
        hevm = new Hevm();
    }

    /// @notice Utility function to create new vault
    function createNewVault() internal returns (RisedleVault) {
        // Create new vault
        RisedleVault vault = new RisedleVault(
            "Risedle USDC Vault",
            "rvUSDC",
            USDC_ADDRESS
        );
        return vault;
    }

    /// @notice Make sure the governor is properly set
    function test_GovernorIsProperlySet() public {
        // Create new vault
        RisedleVault vault = createNewVault();

        // The governor is the one who create/deploy the vault
        assertEq(vault.owner(), address(this));
    }

    /// @notice Make sure governor can grant borrower role
    function test_GovernorCanSetAsBorrower() public {
        // Create new vault
        RisedleVault vault = createNewVault();

        // Create new borrower actor
        Borrower borrower = new Borrower(vault);

        // Grant borrower
        vault.setAsBorrower(address(borrower));

        // Make sure the role has been set
        assertTrue(vault.isBorrower(address(borrower)));

        // Even the governor itself is not borrower
        assertFalse(vault.isBorrower(vault.owner()));
    }

    /// @notice Make sure non-governor cannot grant borrower role
    function testFail_NonGovernorCannotSetAsBorrower() public {
        // Create new vault
        RisedleVault vault = createNewVault();

        // Set random address as governor
        address governor = hevm.addr(1);
        vault.transferOwnership(governor);

        // This should be failed
        address borrower = hevm.addr(2);
        vault.setAsBorrower(borrower);
    }

    /// @notice Make sure unauthorized borrower cannot borrow
    function testFail_UnauthorizedBorrowerCannotBorrowFromTheVault() public {
        // Create new vault
        RisedleVault vault = createNewVault();

        // Add supply to the vault
        Lender lender = new Lender(vault);
        hevm.setUSDCBalance(address(lender), 1000 * 1e6); // 1000 USDC
        lender.lend(1000 * 1e6); // 1000 USDC

        // Unauthorized borrower borrow from the vault
        // This should be failed
        Borrower unauthorizedBorrower = new Borrower(vault);
        unauthorizedBorrower.borrow(100 * 1e6); // 100 USDC
    }

    /// @notice Make sure authorized borrower can borrow
    function test_AuthorizedBorrowerCanBorrowFromTheVault() public {
        // Create new vault
        RisedleVault vault = createNewVault();

        // Add supply to the vault
        Lender lender = new Lender(vault);
        uint256 supplyAmount = 1000 * 1e6; // 1000 USDC
        hevm.setUSDCBalance(address(lender), supplyAmount);
        lender.lend(supplyAmount);

        // Authorized borrower borrow from the vault
        Borrower authorizedBorrower = new Borrower(vault);
        vault.setAsBorrower(address(authorizedBorrower));

        // Borrow underlying asset
        uint256 borrowAmount = 100 * 1e6;
        authorizedBorrower.borrow(borrowAmount); // 100 USDC

        // Make sure the vault states are updated
        assertEq(vault.totalOutstandingDebt(), borrowAmount);
        assertEq(
            vault.getOutstandingDebt(address(authorizedBorrower)),
            borrowAmount
        );

        // Make sure the underlying asset is transfered to the borrower
        assertEq(USDC.balanceOf(address(authorizedBorrower)), borrowAmount);

        // Make sure the vault USDC is reduced
        assertEq(USDC.balanceOf(address(vault)), supplyAmount - borrowAmount);
    }

    /// @notice Make sure unauthorized borrower cannot repay
    function testFail_UnauthorizedBorrowerCannotRepayToTheVault() public {
        // Create new vault
        RisedleVault vault = createNewVault();

        // Unauthorized borrower repay from the vault
        Borrower unauthorizedBorrower = new Borrower(vault);
        hevm.setUSDCBalance(address(unauthorizedBorrower), 100 * 1e6); // 100 USDC

        // This should be failed
        unauthorizedBorrower.repay(100 * 1e6); // 100 USDC
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
        hevm.setUSDCBalance(address(lender), supplyAmount); // 1000 USDC
        lender.lend(supplyAmount); // 1000 USDC

        // Authorized borrower borrow from the vault
        Borrower authorizedBorrower = new Borrower(vault);
        vault.setAsBorrower(address(authorizedBorrower));

        // Borrow underlying asset
        uint256 borrowAmount = 100 * 1e6; // 100 USDC
        uint256 repayAmount = 50 * 1e6; // 50 USDC
        authorizedBorrower.borrow(borrowAmount);

        // Repay underlying asset
        authorizedBorrower.repay(repayAmount);

        // Make sure the underlying asset is transfered to the borrower & the vault
        assertEq(
            USDC.balanceOf(address(authorizedBorrower)),
            borrowAmount - repayAmount
        );
        assertEq(
            USDC.balanceOf(address(vault)),
            supplyAmount - (borrowAmount - repayAmount)
        );

        // Make sure the outstanding debt is correct
        assertEq(
            vault.getOutstandingDebt(address(authorizedBorrower)),
            borrowAmount - repayAmount
        );
    }

    /// @notice Make sure non-governor account cannot set vault parameters
    function testFail_NonGovernorCannotSetVaultParameters() public {
        address governor = hevm.addr(2); // Use random address as governor
        RisedleVault vault = createNewVault();
        vault.transferOwnership(governor);

        // Make sure this is fail
        vault.setVaultParameters(
            0.1 ether,
            0.2 ether,
            0.3 ether,
            0.4 ether,
            0.1 ether
        );
    }

    /// @notice Make sure governor can update the vault parameters
    function test_GovernorCanSetVaultParameters() public {
        // This contract is the governor by default
        RisedleVault vault = createNewVault();

        // Update vault's parameters
        uint256 optimalUtilizationRate = 0.8 ether;
        uint256 slope1 = 0.4 ether;
        uint256 slope2 = 0.9 ether;
        uint256 maxBorrowRatePerSeconds = 0.7 ether;
        uint256 fee = 0.9 ether;
        vault.setVaultParameters(
            optimalUtilizationRate,
            slope1,
            slope2,
            maxBorrowRatePerSeconds,
            fee
        );

        // Make sure the parameters is updated
        (uint256 u, uint256 s1, uint256 s2, uint256 mr, uint256 f) = vault
            .getVaultParameters();

        assertEq(u, optimalUtilizationRate);
        assertEq(s1, slope1);
        assertEq(s2, slope2);
        assertEq(mr, maxBorrowRatePerSeconds);
        assertEq(f, fee);
    }

    /// @notice Make sure non-governor account cannot change the fee recipient
    function testFail_NonGovernorCannotSetFeeRecipientAddress() public {
        // Set governor
        address governor = hevm.addr(2);
        RisedleVault vault = createNewVault();
        vault.transferOwnership(governor);

        // Make sure it fails
        vault.setFeeRecipient(hevm.addr(3));
    }

    /// @notice Make sure governor can update the fee recipient
    function test_GovernorCanSetFeeRecipientAddress() public {
        // Set the new fee recipient
        address newReceiver = hevm.addr(2);

        // Create new vault
        RisedleVault vault = createNewVault();

        // Update the fee recipient
        vault.setFeeRecipient(newReceiver);

        // If we are then the operation is succeed
        // Need to make sure via other external test tho
        assertTrue(true);
    }

    /// @notice Make sure anyone can collect pending fees to fee recipient
    function test_AnyoneCanCollectPendingFeesToFeeRecipient() public {
        // Set the fee recipient
        address feeRecipient = hevm.addr(3);

        // Create new vault
        RisedleVault vault = createNewVault();
        vault.setFeeRecipient(feeRecipient);

        // Simulate the borrowing activities

        // Set the timestamp
        uint256 previousTimestamp = block.timestamp;
        hevm.warp(previousTimestamp);

        // Add supply to the vault
        Lender lender = new Lender(vault);
        hevm.setUSDCBalance(address(lender), 100 * 1e6); // 100 USDC
        lender.lend(100 * 1e6); // 100 USDC

        // Create new authorized borrowers
        Borrower borrower = new Borrower(vault);
        vault.setAsBorrower(address(borrower));

        // Borrow asset
        borrower.borrow(90 * 1e6); // Borrow 90 USDC

        // Change the timestamp to 7 days
        hevm.warp(previousTimestamp + (60 * 60 * 24 * 7));

        // Accrue interest
        vault.accrueInterest();

        // Get the toal pending fees
        uint256 collectedFees = vault.totalPendingFees();

        // Public collect fees
        FeeCollector collector = new FeeCollector(vault);
        collector.collectPendingFees();

        // Make sure totalPendingFees is set to zero
        assertEq(vault.totalPendingFees(), 0);

        // Make sure the fee recipient have collectedFees balance
        assertEq(USDC.balanceOf(feeRecipient), collectedFees);
    }

    /// @notice Test accrue interest as public
    function test_AnyoneCanAccrueInterest() public {
        // Create new vault
        address governor = hevm.addr(2);
        RisedleVault vault = createNewVault();
        vault.transferOwnership(governor);

        // Set the timestamp
        uint256 previousTimestamp = block.timestamp;
        hevm.warp(previousTimestamp);

        // Public accrue interest
        vault.accrueInterest();

        // Make sure is not failed
        assertTrue(true);
    }
}
