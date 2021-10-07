// SPDX-License-Identifier: GPL-3.0-or-later

// Risedle's Vault Internal Test
// Test & validate all internal functionalities

pragma solidity ^0.8.7;
pragma experimental ABIEncoderV2;

import "lib/ds-test/src/test.sol";
import {IERC20Metadata} from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {Hevm} from "./Hevm.sol";
import {Risedle} from "../Risedle.sol";

// chain/* is replaced by DAPP_REMAPPINGS at compile time,
// this allow us to use custom address on specific chain
// See .dapprc
import {USDT_ADDRESS, CHAINLINK_ETH_USD, CHAINLINK_USDC_USD} from "chain/Constants.sol";

// Set Risedle's Vault properties
string constant vaultTokenName = "Risedle USDT Vault";
string constant vaultTokenSymbol = "rvUSDT";
address constant vaultUnderlying = USDT_ADDRESS;
address constant vaultFeed = CHAINLINK_USDC_USD;
uint8 constant vaultUnderlyingDecimals = 6;

contract RisedleInternalTest is
    DSTest,
    Risedle(
        vaultTokenName,
        vaultTokenSymbol,
        vaultUnderlying,
        vaultFeed,
        vaultUnderlyingDecimals
    )
{
    /// @notice hevm utils to alter mainnet state
    Hevm hevm;

    function setUp() public {
        hevm = new Hevm();
    }

    /// @notice Make sure all important variables are correctly set after deployment
    function test_VaultProperties() public {
        // Make sure the vault's underlying asset is correct
        assertEq(supply, vaultUnderlying);

        // Make sure total outstanding debt is zero
        assertEq(totalOutstandingDebt, 0);

        // Make sure total debt proportion is zero
        assertEq(totalDebtProportion, 0);

        // Make sure total collected fees is zero
        assertEq(totalVaultPendingFees, 0);

        // Make sure the last timestamp accrued is initialized
        assertEq(lastTimestampInterestAccrued, block.timestamp);

        // Make sure optimal utilization rate is set to 90%
        assertEq(OPTIMAL_UTILIZATION_RATE_IN_ETHER, 900000000000000000);

        // Make sure the interest rate slop 1 is set to 20%
        assertEq(INTEREST_SLOPE_1_IN_ETHER, 200000000000000000);

        // Make sure the interest rate slop 2 is set to 60%
        assertEq(INTEREST_SLOPE_2_IN_ETHER, 600000000000000000);

        // Make sure the seconds per year is set
        assertEq(TOTAL_SECONDS_IN_A_YEAR, 31536000);

        // Make sure max borrow rate is set
        assertEq(MAX_BORROW_RATE_PER_SECOND_IN_ETHER, 50735667174); // Approx 393% APY

        // Make sure the Vault's token properties is correct
        IERC20Metadata vaultTokenMetadata = IERC20Metadata(address(this));
        assertEq(vaultTokenMetadata.name(), vaultTokenName);
        assertEq(vaultTokenMetadata.symbol(), vaultTokenSymbol);
        assertEq(vaultTokenMetadata.decimals(), 6); // Equal to USDT decimals

        // Make sure the total supply is set to zero
        assertEq(totalSupply(), 0);
    }

    /// @notice Make sure getTotalAvailableCash return correctly
    function test_GetTotalAvailableCash() public {
        uint256 amount;
        uint256 totalAvailable;

        amount = 1000 * 1e6; // 1000 USDT
        hevm.setUSDTBalance(address(this), amount);
        totalAvailable = getTotalAvailableCash();
        assertEq(totalAvailable, amount);

        amount = 200 * 1e6; // 200 USDT
        totalVaultPendingFees = 100 * 1e6; // 100 USDT
        hevm.setUSDTBalance(address(this), amount);
        totalAvailable = getTotalAvailableCash();
        assertEq(totalAvailable, amount - totalVaultPendingFees);

        // This most likely never happen; but we need to make sure to handle it
        // totalVaultPendingFees > Underlying balance
        amount = 100 * 1e6; // 100 USDT
        totalVaultPendingFees = 105 * 1e6; // 105 USDT
        hevm.setUSDTBalance(address(this), amount);
        totalAvailable = getTotalAvailableCash();
        assertEq(totalAvailable, 0);

        // Test with very high number
        amount = 100 * 1e12 * 1e6; // 100 trillion USDT
        totalVaultPendingFees = 90 * 1e12 * 1e6; // 90 trillion USDT
        hevm.setUSDTBalance(address(this), amount);
        totalAvailable = getTotalAvailableCash();
        assertEq(totalAvailable, 10 * 1e12 * 1e6); // 10 trillion USDT
    }

    /// @notice Make sure the Utilization Rate calculation is correct
    function test_CalculateUtilizationRateInEther() public {
        uint256 utilizationRateInEther;

        // Available=0 ; Outstanding debt=0
        utilizationRateInEther = calculateUtilizationRateInEther(0, 0);
        assertEq(utilizationRateInEther, 0);

        // Available=100 USDT; Outstanding debt=0
        utilizationRateInEther = calculateUtilizationRateInEther(100 * 1e6, 0);
        assertEq(utilizationRateInEther, 0);

        // Available=100 USDT; Outstanding debt=50 USDT
        utilizationRateInEther = calculateUtilizationRateInEther(
            100 * 1e6, // 100 USDT
            50 * 1e6 // 50 USDT
        );
        assertEq(utilizationRateInEther, 333333333333333333); // 0.33 Utilization rate

        // Available=50 USDT; Outstanding debt=100 USDT
        utilizationRateInEther = calculateUtilizationRateInEther(
            50 * 1e6, // 50 USDT
            100 * 1e6 // 100 USDT
        );
        assertEq(utilizationRateInEther, 666666666666666666); // 0.66 Utilization rate

        // Available=0; Outstanding debt=100 USDT
        utilizationRateInEther = calculateUtilizationRateInEther(0, 100 * 1e6);
        assertEq(utilizationRateInEther, 1 ether);

        // Test with very large number
        utilizationRateInEther = calculateUtilizationRateInEther(
            100 * 1e12 * 1e6, // 100 trillion USDT
            100 * 1e12 * 1e6 // 100 trillion USDT
        );
        assertEq(utilizationRateInEther, 0.5 ether);
    }

    /// @notice Make sure getUtilizationRateInEther is correct
    function test_GetUtilizationRateInEther() public {
        uint256 utilizationRateInEther;

        // Set all balance to zero
        totalOutstandingDebt = 0;
        totalVaultPendingFees = 0;
        hevm.setUSDTBalance(address(this), 0);
        utilizationRateInEther = getUtilizationRateInEther();
        assertEq(utilizationRateInEther, 0);

        // Available=100 USDT; Outstanding debt=0
        totalOutstandingDebt = 0;
        totalVaultPendingFees = 0;
        hevm.setUSDTBalance(address(this), 100 * 1e6);
        utilizationRateInEther = getUtilizationRateInEther();
        assertEq(utilizationRateInEther, 0);

        // Available=100 USDT; Outstanding debt=50 USDT
        totalOutstandingDebt = 50 * 1e6;
        totalVaultPendingFees = 10 * 1e6;
        hevm.setUSDTBalance(address(this), 110 * 1e6);
        utilizationRateInEther = getUtilizationRateInEther();
        assertEq(utilizationRateInEther, 333333333333333333); // 0.33 Utilization rate

        // Available=50 USDT; Outstanding debt=100 USDT
        totalOutstandingDebt = 100 * 1e6;
        totalVaultPendingFees = 50 * 1e6;
        hevm.setUSDTBalance(address(this), 100 * 1e6);
        utilizationRateInEther = getUtilizationRateInEther();
        assertEq(utilizationRateInEther, 666666666666666666); // 0.66 Utilization rate

        // Available=0; Outstanding debt=100 USDT
        totalOutstandingDebt = 100 * 1e6;
        totalVaultPendingFees = 0;
        hevm.setUSDTBalance(address(this), 0);
        utilizationRateInEther = getUtilizationRateInEther();
        assertEq(utilizationRateInEther, 1 ether); // 1.0 utilization rate

        // Test with very large number
        totalOutstandingDebt = 100 * 1e12 * 1e6; // 100 trillion USDT
        totalVaultPendingFees = 0;
        hevm.setUSDTBalance(address(this), 100 * 1e12 * 1e6); // 100 trillion USDT
        utilizationRateInEther = getUtilizationRateInEther();
        assertEq(utilizationRateInEther, 0.5 ether); // 0.5 utilization rate
    }

    /// @notice Make sure the borrow rate calculation is correct
    function test_CalculateBorrowRatePerSecondInEther() public {
        // Set the model parameters
        OPTIMAL_UTILIZATION_RATE_IN_ETHER = 0.9 ether; // 90% utilization
        INTEREST_SLOPE_1_IN_ETHER = 0.2 ether; // 20% slope 1
        INTEREST_SLOPE_2_IN_ETHER = 0.6 ether; // 60% slope 2
        uint256 borrowRatePerSecondInEther;

        // Initial state: 0 utilization
        borrowRatePerSecondInEther = calculateBorrowRatePerSecondInEther(0);
        assertEq(borrowRatePerSecondInEther, 0);

        // 0.5 utilization rate (50%)
        borrowRatePerSecondInEther = calculateBorrowRatePerSecondInEther(
            0.5 ether
        );
        assertEq(borrowRatePerSecondInEther, 3523310220); // approx 11.75% APY

        // 0.94 utilization rate (94%)
        borrowRatePerSecondInEther = calculateBorrowRatePerSecondInEther(
            0.94 ether
        );
        assertEq(borrowRatePerSecondInEther, 19025875190); // approx 82.122% APY

        // 0.97 utilization rate (97%)
        borrowRatePerSecondInEther = calculateBorrowRatePerSecondInEther(
            0.97 ether
        );
        assertEq(
            borrowRatePerSecondInEther,
            MAX_BORROW_RATE_PER_SECOND_IN_ETHER
        ); // approx 393% APY

        // 0.99 utilization rate (99%)
        borrowRatePerSecondInEther = calculateBorrowRatePerSecondInEther(
            0.99 ether
        );
        assertEq(
            borrowRatePerSecondInEther,
            MAX_BORROW_RATE_PER_SECOND_IN_ETHER
        ); // approx 393% APY

        // 1.0 utilization rate (100%)
        borrowRatePerSecondInEther = calculateBorrowRatePerSecondInEther(
            1 ether
        ); // 100%
        assertEq(
            borrowRatePerSecondInEther,
            MAX_BORROW_RATE_PER_SECOND_IN_ETHER
        ); // approx 393% APY

        // More than 100% utilization rate should be capped to max borrow rate
        borrowRatePerSecondInEther = calculateBorrowRatePerSecondInEther(
            1.5 ether
        ); // 150%
        assertEq(
            borrowRatePerSecondInEther,
            MAX_BORROW_RATE_PER_SECOND_IN_ETHER
        ); // approx 393% APY
    }

    /// @notice Make sure getBorrowRatePerSecondInEther is correct
    function test_GetBorrowRatePerSecondInEther() public {
        // Set the model parameters
        OPTIMAL_UTILIZATION_RATE_IN_ETHER = 0.9 ether; // 90% utilization
        INTEREST_SLOPE_1_IN_ETHER = 0.2 ether; // 20% slope 1
        INTEREST_SLOPE_2_IN_ETHER = 0.6 ether; // 60% slope 2
        uint256 borrowRatePerSecondInEther;

        // Initial state: 0 utilization
        totalOutstandingDebt = 0;
        totalVaultPendingFees = 0;
        hevm.setUSDTBalance(address(this), 0);
        borrowRatePerSecondInEther = getBorrowRatePerSecondInEther();
        assertEq(borrowRatePerSecondInEther, 0);

        // 0.5 utilization rate (50%)
        totalOutstandingDebt = 100 * 1e6;
        totalVaultPendingFees = 0;
        hevm.setUSDTBalance(address(this), 100 * 1e6);
        borrowRatePerSecondInEther = getBorrowRatePerSecondInEther();
        assertEq(borrowRatePerSecondInEther, 3523310220); // approx 11.75% APY

        // 1.0 utilization rate (100%)
        totalOutstandingDebt = 100 * 1e6;
        totalVaultPendingFees = 0;
        hevm.setUSDTBalance(address(this), 0);
        borrowRatePerSecondInEther = getBorrowRatePerSecondInEther();
        assertEq(
            borrowRatePerSecondInEther,
            MAX_BORROW_RATE_PER_SECOND_IN_ETHER
        ); // approx 393% APY
    }

    /// @notice Make sure the getSupplyRatePerSecondInEther is correct
    function test_GetSupplyRatePerSecondInEther() public {
        // Test with 76% utilization rate
        totalOutstandingDebt = 100 * 1e6;
        totalVaultPendingFees = 20 * 1e6;
        hevm.setUSDTBalance(address(this), 50 * 1e6);
        uint256 borrowRatePerSecondInEther = getBorrowRatePerSecondInEther();
        assertEq(borrowRatePerSecondInEther, 5420477262); // approx 18% APY
        uint256 supplyRatePerSecondInEther = getSupplyRatePerSecondInEther();
        assertEq(supplyRatePerSecondInEther, 3752638103); // approx 12% APY
    }

    /// @notice Make sure getInterestAmount is correct
    function test_GetInterestAmount() public {
        uint256 interestAmount;

        // Total Outstanding debt: 0
        // Borrow Rate Per Seconds: 0
        // Elapsed Seconds: 0
        // Expected interest amount: 0
        interestAmount = getInterestAmount(0, 0, 0);
        assertEq(interestAmount, 0);

        // Total Outstanding debt: x
        // Borrow Rate Per Seconds: 0
        // Elapsed Seconds: 0
        // Expected interest amount: 0
        interestAmount = getInterestAmount(
            100 * 1e6, // 100 USDT
            0,
            0
        );
        assertEq(interestAmount, 0);

        // Total Outstanding debt: 0
        // Borrow Rate Per Seconds: 0
        // Elapsed Seconds: y
        // Expected interest amount: 0
        interestAmount = getInterestAmount(0, 0, 20);
        assertEq(interestAmount, 0);

        // Total Outstanding debt: x
        // Borrow Rate Per Seconds: y
        // Elapsed Seconds: z
        // Expected interest amount: 0
        interestAmount = getInterestAmount(
            100 * 1e6, // 100 USDT
            3523310220, // Approx 11.75% APY
            86400 // 86400 seconds ~ 24 hours
        );
        assertEq(interestAmount, 30441); // in 1e6 precision or 0.0304414003 USDT

        // Test with very large numbers
        interestAmount = getInterestAmount(
            100 * 1e12 * 1e6, // 100 trillion USDT
            3523310220, // Approx 11.75% APY
            60 * 60 * 24 * 7 // Approx 7 weeks
        );
        assertEq(interestAmount, 213089802105600000); // in 1e6 precision or 213B USDT
    }

    /// @notice Make sure setVaultStates update the vault states correctly
    function test_setVaultStates() public {
        // interestAmount=0
        totalOutstandingDebt = 100 * 1e6; // 100 USDT
        totalVaultPendingFees = 5 * 1e6; // 5 USDT
        lastTimestampInterestAccrued = 0;
        setVaultStates(0, 0);
        assertEq(totalOutstandingDebt, 100 * 1e6);
        assertEq(totalVaultPendingFees, 5 * 1e6);
        assertEq(lastTimestampInterestAccrued, 0);

        // interestAmount=10 USDT
        totalOutstandingDebt = 100 * 1e6; // 100 USDT
        totalVaultPendingFees = 5 * 1e6; // 5 USDT
        lastTimestampInterestAccrued = 10;
        setVaultStates(10 * 1e6, 12); // 10 USDT
        // The totalOutstandingDebt & totalVaultPendingFees should be updated
        assertEq(totalOutstandingDebt, 110000000); // 110 USDT
        assertEq(totalVaultPendingFees, 6000000); // 6 USDT
        assertEq(lastTimestampInterestAccrued, 12);

        // Test with very large numbers
        totalOutstandingDebt = 100 * 1e12 * 1e6; // 100 trillion USDT
        totalVaultPendingFees = 1 * 1e12 * 1e6; // 1 trillion USDT
        lastTimestampInterestAccrued = 100;
        setVaultStates(10 * 1e12 * 1e6, 200); // 10 trillion USDT
        assertEq(totalOutstandingDebt, 110 * 1e12 * 1e6); // 110 trillion USDT
        assertEq(totalVaultPendingFees, 2 * 1e12 * 1e6); // 2 trillion USDT
        assertEq(lastTimestampInterestAccrued, 200);
    }

    /// @notice Make sure accrue interest is working perfectly
    function test_AccrueInterest() public {
        uint256 nextTimestamp;

        // Scenario 1: 0% utilization
        totalOutstandingDebt = 0;
        totalVaultPendingFees = 0;
        uint256 contractBalance = 1000 * 1e6; // 1000 USDT
        hevm.setUSDTBalance(address(this), contractBalance); // Set the contract balance
        accrueInterest();
        // Make sure it doesn't change the totalOutstandingDebt and totalVaultPendingFees
        assertEq(totalOutstandingDebt, 0);
        assertEq(totalVaultPendingFees, 0);

        // Scenario 2: Below optimal utilization rate
        totalOutstandingDebt = 100 * 1e6; // 100 USDT
        totalVaultPendingFees = 20 * 1e6; // 20 USDT
        hevm.setUSDTBalance(address(this), 50 * 1e6); // Set contract balance
        lastTimestampInterestAccrued = block.timestamp; // Set accured interest to now
        nextTimestamp = lastTimestampInterestAccrued + (60 * 60 * 24);
        // Set block timestamp to 24 hours later
        hevm.warp(nextTimestamp);
        // Perform interest calculation
        accrueInterest();
        // Make sure the totalOutstandingDebt and totalVaultPendingFees are updated
        assertEq(totalOutstandingDebt, 100046832); // 100 + (100% of interest amount)
        assertEq(totalVaultPendingFees, 20004683); // 20 + (10% of interest amount)
        assertEq(lastTimestampInterestAccrued, nextTimestamp); // Make sure the last timestamp is updated

        // Scenario 3: Above optimzal utilization rate
        totalOutstandingDebt = 400 * 1e6; // 400 USDT
        totalVaultPendingFees = 20 * 1e6; // 20 USDT
        hevm.setUSDTBalance(address(this), 50 * 1e6); // Set contract balance
        lastTimestampInterestAccrued = block.timestamp; // Set accured interest to now
        nextTimestamp = lastTimestampInterestAccrued + (60 * 60 * 3);
        // Set block timestamp to 3 hours later
        hevm.warp(nextTimestamp);
        // Perform interest calculation
        accrueInterest();
        // Make sure the totalOutstandingDebt and totalVaultPendingFees are updated
        assertEq(totalOutstandingDebt, 400063013); // 400 + (100% of interest amount)
        assertEq(totalVaultPendingFees, 20006301); // 20 + (10% of interest amount)
        assertEq(lastTimestampInterestAccrued, nextTimestamp); // Make sure the last timestamp is updated

        // Scenario 4: Maximum utilization rate
        totalOutstandingDebt = 15000 * 1e6; // 15000 USDT
        totalVaultPendingFees = 20 * 1e6; // 20 USDT
        hevm.setUSDTBalance(address(this), 50 * 1e6); // Set contract balance
        lastTimestampInterestAccrued = block.timestamp; // Set accured interest to now
        nextTimestamp = lastTimestampInterestAccrued + (60 * 60 * 10);
        // Set block timestamp to 10 hours later
        hevm.warp(nextTimestamp);
        // Perform interest calculation
        accrueInterest();
        // Make sure the totalOutstandingDebt and totalVaultPendingFees are updated
        assertEq(totalOutstandingDebt, 15027397260); // 400 + (100% of interest amount)
        assertEq(totalVaultPendingFees, 22739726); // 20 + (10% of interest amount)
        assertEq(lastTimestampInterestAccrued, nextTimestamp); // Make sure the last timestamp is updated
    }

    /// @notice Make sure the getExchangeRateInEther() working perfectly
    function test_GetExchangeRateInEther() public {
        uint256 exchangeRateInETher;

        // Scenario 1: Initial exchange rate
        // totalSupply = 0
        // exchangeRate should be 1:1
        exchangeRateInETher = getExchangeRateInEther();
        assertEq(exchangeRateInETher, 1 ether);

        // Scenario 2: Simulate lender already supply some asset but the
        // interest is not accrued yet
        uint256 suppliedUSDT = 100 * 1e6; // 100 USDT
        hevm.setUSDTBalance(address(this), suppliedUSDT); // Set contract balance to 100USDT

        totalOutstandingDebt = 0;
        totalVaultPendingFees = 0;

        // Mint to random address with 1:1 exchange rate
        address supplier = hevm.addr(1);
        _mint(supplier, 100 * 1e6);

        // Make sure the exchange rate is correct
        exchangeRateInETher = getExchangeRateInEther();
        assertEq(exchangeRateInETher, 1 ether);

        // Scenario 3: Simulate that the totalOutstandingDebt is 50 USDT and interest
        // already accrued 10 USDT.
        // 1. Someone borrow the asset 50 USDT
        hevm.setUSDTBalance(address(this), suppliedUSDT - (50 * 1e6)); // Set contract balance to 50USDT previously 100USDT
        totalOutstandingDebt = (50 * 1e6);

        // 2. Interest accrued 10 USDT
        totalOutstandingDebt = totalOutstandingDebt + (9 * 1e6); // 9 USDT (90% of interest accrued)
        totalVaultPendingFees = 1 * 1e6; // 1 USDT (10% of interest accrued)

        // 3. Exchange rate should ~1.08
        exchangeRateInETher = getExchangeRateInEther();
        assertEq(exchangeRateInETher, 1.08 ether); // 1.08

        // Test with very large numbers
        // Update the total supply first
        _burn(supplier, (100 * 1e6));
        _mint(supplier, (100 * 1e12 * 1e6));
        hevm.setUSDTBalance(address(this), (50 * 1e12 * 1e6)); // Set contract balance to 50 trillion USDT
        totalOutstandingDebt = (50 * 1e12 * 1e6); // 50 trillion USDT
        totalOutstandingDebt = totalOutstandingDebt + (9 * 1e12 * 1e6); // 9 trillion USDT (90% of interest accrued)
        totalVaultPendingFees = 1 * 1e12 * 1e6; // 1 trillion USDT (10% of interest accrued)
        exchangeRateInETher = getExchangeRateInEther();
        assertEq(exchangeRateInETher, 1.08 ether); // 1.08
    }

    /// @notice Make sure the debt proportion rate is correct
    function test_GetDebtProportionRateInEther() public {
        uint256 debtProportionRateInEther;

        // Initial rate should be 1 ether
        totalOutstandingDebt = 0;
        totalDebtProportion = 0;
        debtProportionRateInEther = getDebtProportionRateInEther();
        assertEq(debtProportionRateInEther, 1 ether);

        // If total outstanding debt is equal to proportion then the rate should be 1
        totalOutstandingDebt = 100 * 1e6; // 100 USDT
        totalDebtProportion = 100 * 1e6; // 100 USDT
        debtProportionRateInEther = getDebtProportionRateInEther();
        assertEq(debtProportionRateInEther, 1 ether);

        // If interest accrued, total outstanding debt is larger than the total debt proportion
        totalOutstandingDebt = 120 * 1e6; // 120 USDT
        totalDebtProportion = 100 * 1e6; // 100 USDT
        debtProportionRateInEther = getDebtProportionRateInEther();
        assertEq(debtProportionRateInEther, 1.2 ether);

        // Test with very large number
        totalOutstandingDebt = 120 * 1e12 * 1e6; // 120 trillion USDT
        totalDebtProportion = 100 * 1e12 * 1e6; // 100 trillion USDT
        debtProportionRateInEther = getDebtProportionRateInEther();
        assertEq(debtProportionRateInEther, 1.2 ether);
    }

    /// @notice Make sure the fee calculation is correct
    function test_GetCollateralAndFeeAmount() public {
        uint256 amount;
        uint256 feeInEther;
        uint256 outputCollateralAmount;
        uint256 outputFeeAmount;
        uint256 expectedCollateralAmount;
        uint256 expectedFeeAmount;

        amount = 50 ether;
        feeInEther = 0.001 ether; // 0.1%
        expectedCollateralAmount = 49.95 ether;
        expectedFeeAmount = 0.05 ether;
        (outputCollateralAmount, outputFeeAmount) = getCollateralAndFeeAmount(
            amount,
            feeInEther
        );
        assertEq(outputCollateralAmount, expectedCollateralAmount);
        assertEq(outputFeeAmount, expectedFeeAmount);

        // Test with very large number
        amount = (120 * 1e12) * 1 ether; // 120 trillion ether
        feeInEther = 0.001 ether; // 0.1%
        expectedCollateralAmount = (11988 * 1e10) * 1 ether;
        expectedFeeAmount = (12 * 1e10) * 1 ether;
        (outputCollateralAmount, outputFeeAmount) = getCollateralAndFeeAmount(
            amount,
            feeInEther
        );
        assertEq(outputCollateralAmount, expectedCollateralAmount);
        assertEq(outputFeeAmount, expectedFeeAmount);
    }

    /// @notice Make sure we can get correct data from chainlink
    function test_GetChainlinkPriceInGwei() public {
        uint256 priceInGwei;

        // Test with ETH/USD feed
        priceInGwei = getChainlinkPriceInGwei(CHAINLINK_ETH_USD);
        assertGt(priceInGwei, 2700 gwei); // 2700 USD ETH UP ONLY

        // Test with USDC/USD feed
        priceInGwei = getChainlinkPriceInGwei(CHAINLINK_USDC_USD);
        assertGt(priceInGwei, 0.9 gwei);
        assertLt(priceInGwei, 1.1 gwei);
    }

    /// @notice Make sure that we can get the collateral price
    function test_GetCollateralPrice() public {
        // Supply is set to USDC, see on the on this contract constructor
        uint256 wethUSDC = getCollateralPrice(CHAINLINK_ETH_USD);

        // Currently ETH is trading on range 2500USDC - 5000USDC
        // (Oct 2021) I Hope this test is failed
        assertGt(wethUSDC, 2500 * 1e6);
        assertLt(wethUSDC, 5000 * 1e6);
    }
}
