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

/// @notice Dummy contract to simulate random account to execute collect fee
contract FeeCollector {
    RisedleVault _vault;

    constructor(RisedleVault vault) {
        _vault = vault;
    }

    function collectFees() public {
        _vault.collectFees();
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
    function createNewVault(address governor, address feeReceiver)
        internal
        returns (RisedleVault)
    {
        // Create new vault
        RisedleVault vault = new RisedleVault(
            "Risedle USDT Vault",
            "rvUSDT",
            USDT_ADDRESS,
            governor,
            feeReceiver
        );
        return vault;
    }

    /// @notice Make sure the governor is properly set
    function test_GovernorIsProperlySet() public {
        // Create new vault
        RisedleVault vault = createNewVault(address(this), address(this));

        // Make sure the governor is set
        assertTrue(vault.hasRole(vault.DEFAULT_ADMIN_ROLE(), vault.governor()));

        // Check with non-governor address
        address nonGovernor = hevm.addr(2); // random address
        assertFalse(vault.hasRole(vault.DEFAULT_ADMIN_ROLE(), nonGovernor));
    }

    /// @notice Make sure governor can grant borrower role
    function test_GovernorCanGrantBorrower() public {
        // Create new vault
        RisedleVault vault = createNewVault(address(this), address(this));

        // Create new borrower actor
        Borrower borrower = new Borrower(vault);

        // Grant borrower
        vault.grantAsBorrower(address(borrower));

        // Make sure the role has been set
        assertTrue(vault.isBorrower(address(borrower)));

        // Even the governor itself is not borrower
        assertFalse(vault.isBorrower(vault.governor()));
    }

    /// @notice Make sure the lender can supply asset to the vault
    function test_LenderCanAddSupplytToTheVault() public {
        // Create new vault
        RisedleVault vault = createNewVault(address(this), address(this));

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
        RisedleVault vault = createNewVault(address(this), address(this));

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
        RisedleVault vault = createNewVault(address(this), address(this));

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
        RisedleVault vault = createNewVault(address(this), address(this));

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
        RisedleVault vault = createNewVault(address(this), address(this));

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
        RisedleVault vault = createNewVault(address(this), address(this));

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
        assertEq(vault.totalDebtProportion(), borrowAmount); // coz the debt proportion rate is set to 1:1 or 1 ether
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
        RisedleVault vault = createNewVault(address(this), address(this));

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
        RisedleVault vault = createNewVault(address(this), address(this));

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

        // Repay underlying asset
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

    /// @notice Borrower debt should increased when the interest is accrued
    function test_BorrowersDebtShouldIncreasedProportionally() public {
        // Create new vault
        RisedleVault vault = createNewVault(address(this), address(this));

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
        vault.grantAsBorrower(address(borrowerA));
        vault.grantAsBorrower(address(borrowerB));

        // Borrower A borrow 40 USDT
        borrowerA.borrow(40 * 1e6);
        assertEq(vault.getOutstandingDebt(address(borrowerA)), 40 * 1e6);
        assertEq(vault.getDebtProportion(address(borrowerA)), 40 * 1e6); // debt roportion rate is 1:1

        // Total debt should be correct
        assertEq(vault.totalOutstandingDebt(), 40 * 1e6); // 40 USDT so far

        // Total collected fees should be correct
        assertEq(vault.totalCollectedFees(), 0); // 0 USDT so far

        // After 5 days, then accrue interest
        hevm.warp(previousTimestamp + (60 * 60 * 24 * 5));
        previousTimestamp = previousTimestamp + (60 * 60 * 24 * 5);

        // Accrue interest
        vault.accrueInterest();

        // The debt of borrower A should be increased
        assertEq(vault.getOutstandingDebt(address(borrowerA)), 40048706);
        // Debt proportion should not change
        assertEq(vault.getDebtProportion(address(borrowerA)), 40 * 1e6);
        // Total debt should be correct
        assertEq(vault.totalOutstandingDebt(), 40048706); // 40.04870624 USDT so far

        // Borrower B borrow 50 USDT
        borrowerB.borrow(50 * 1e6);

        // The debt should correct
        assertEq(vault.getOutstandingDebt(address(borrowerB)), 50 * 1e6);
        assertEq(vault.getDebtProportion(address(borrowerB)), 49939191); // debt roportion rate is 1:1.001217656

        // Total debt should be correct
        assertEq(vault.totalOutstandingDebt(), 40048706 + (50 * 1e6)); // 90.04870624 USDT so far

        // Total collected fees should be correct
        assertEq(vault.totalCollectedFees(), 4870); // 0.004870624049 USDT so far

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

    /// @notice Make sure non-governor account cannot update vault parameters
    function testFail_NonGovernorCannotUpdateVaultParameters() public {
        address governor = hevm.addr(2); // Use random address as governor
        RisedleVault vault = createNewVault(governor, governor);

        // Make sure this is fail
        vault.updateVaultParameters(
            0.1 ether,
            0.2 ether,
            0.3 ether,
            0.4 ether,
            0.1 ether
        );
    }

    /// @notice Make sure governor can update the vault parameters
    function test_GovernorCanUpdateVaultParameters() public {
        address governor = address(this); // Set this contract as vault governor
        RisedleVault vault = createNewVault(governor, governor);

        // Update vault's parameters
        uint256 optimalUtilizationRate = 0.8 ether;
        uint256 slope1 = 0.4 ether;
        uint256 slope2 = 0.9 ether;
        uint256 maxBorrowRatePerSeconds = 0.7 ether;
        uint256 fee = 0.9 ether;
        vault.updateVaultParameters(
            optimalUtilizationRate,
            slope1,
            slope2,
            maxBorrowRatePerSeconds,
            fee
        );

        // Make sure the parameters is updated
        assertEq(
            vault.OPTIMAL_UTILIZATION_RATE_IN_ETHER(),
            optimalUtilizationRate
        );
        assertEq(vault.INTEREST_SLOPE_1_IN_ETHER(), slope1);
        assertEq(vault.INTEREST_SLOPE_2_IN_ETHER(), slope2);
        assertEq(
            vault.MAX_BORROW_RATE_PER_SECOND_IN_ETHER(),
            maxBorrowRatePerSeconds
        );
        assertEq(vault.PERFORMANCE_FEE_IN_ETHER(), fee);
    }

    /// @notice Make sure non-governor account cannot change the fee receiver
    function testFail_NonGovernorCannotUpdateFeeReceiverAddress() public {
        // Set governor
        address governor = hevm.addr(2);

        RisedleVault vault = createNewVault(governor, governor);

        // Make sure it fails
        vault.updateFeeReceiver(hevm.addr(3));
    }

    /// @notice Make sure governor can update the fee receiver
    function test_GovernorCanUpdateFeeReceiverAddress() public {
        // Set this contract as governor
        address governor = address(this);
        address feeReceiver = governor;
        address newReceiver = hevm.addr(2);

        // Create new vault
        RisedleVault vault = createNewVault(governor, feeReceiver);

        // Update the fee receiver
        vault.updateFeeReceiver(newReceiver);

        // Make sure the fee receiver is updated
        assertEq(vault.feeReceiver(), newReceiver);
    }

    /// @notice Make sure anyone can send collected fees to fee receiver
    function test_AnyoneCanSendCollectedFeesToFeeReceiver() public {
        // Set governor and fee receiver
        address governor = address(this);
        address feeReceiver = hevm.addr(3);

        // Create new vault
        RisedleVault vault = createNewVault(governor, feeReceiver);

        // Simulate the borrowing activities

        // Set the timestamp
        uint256 previousTimestamp = block.timestamp;
        hevm.warp(previousTimestamp);

        // Add supply to the vault
        Lender lender = new Lender(vault);
        hevm.setUSDTBalance(address(lender), 100 * 1e6); // 100 USDT
        lender.lend(100 * 1e6); // 100 USDT

        // Create new authorized borrowers
        Borrower borrower = new Borrower(vault);
        vault.grantAsBorrower(address(borrower));

        // Borrow asset
        borrower.borrow(90 * 1e6); // Borrow 90 USDT

        // Change the timestamp to 7 days
        hevm.warp(previousTimestamp + (60 * 60 * 24 * 7));

        // Accrue interest
        vault.accrueInterest();

        // Get the toal collected fees
        uint256 totalCollectedFees = vault.totalCollectedFees();

        // Public collect fees
        FeeCollector collector = new FeeCollector(vault);
        collector.collectFees();

        // Make sure totalCollectedFees is set to zero
        assertEq(vault.totalCollectedFees(), 0);

        // Make sure the fee receiver have totalCollectedFees balance
        assertEq(USDT.balanceOf(feeReceiver), totalCollectedFees);
    }

    /// @notice Test accrue interest as public
    function test_AnyoneCanAccrueInterest() public {
        // Set governor and fee receiver
        address governor = hevm.addr(1);
        address feeReceiver = hevm.addr(2);

        // Create new vault
        RisedleVault vault = createNewVault(governor, feeReceiver);

        // Set the timestamp
        uint256 previousTimestamp = block.timestamp;
        hevm.warp(previousTimestamp);

        // Public accrue interest
        vault.accrueInterest();

        // Make sure the lastAccruedInterest is updated
        assertEq(vault.lastTimestampInterestAccrued(), previousTimestamp);

        // Set the timestamp again
        uint256 nextTimestamp = previousTimestamp + (60 * 60 * 24 * 7); // +7 days
        hevm.warp(nextTimestamp);

        // Public accrue interest
        vault.accrueInterest();

        // Make sure the lastAccruedInterest is updated
        assertEq(vault.lastTimestampInterestAccrued(), nextTimestamp);
    }
}
