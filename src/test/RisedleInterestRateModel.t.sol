// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.7;
pragma experimental ABIEncoderV2;

import "lib/ds-test/src/test.sol";

import "../RisedleInterestRateModel.sol";

contract RisedleInterestRateModelTest is DSTest, RisedleInterestRateModel {
    /// @notice Make sure the Utilization Rate calculation is correct
    function test_UtilizationRateCalculation() public {
        // Test zero utilization rate, with reserved = 0
        uint256 availableCashUSDT1 = 100 * 1e6; // 100 USDT, USDT is 6 decimals
        uint256 borrowedUSDT1 = 0 * 1e6; // 0 USDT
        uint256 reservedUSDT1 = 0 * 1e6; // 0 USDT
        uint256 expectedUtilizationRateAsWad1 = 0; // 0%
        uint256 utilizationRateAsWad1 = calculateUtilizationRateWad(
            availableCashUSDT1,
            borrowedUSDT1,
            reservedUSDT1
        );
        assertEq(utilizationRateAsWad1, expectedUtilizationRateAsWad1);

        // Test ~33% utilization rate
        uint256 availableCashUSDT2 = 100 * 1e6; // 100 USDT, USDT is 6 decimals
        uint256 borrowedUSDT2 = 50 * 1e6; // 50 USDT
        uint256 reservedUSDT2 = 1 * 1e6; // 1 USDT
        uint256 expectedUtilizationRateAsWad2 = 335570469798657718; // 33.55%
        uint256 utilizationRateAsWad2 = calculateUtilizationRateWad(
            availableCashUSDT2,
            borrowedUSDT2,
            reservedUSDT2
        );
        assertEq(utilizationRateAsWad2, expectedUtilizationRateAsWad2);

        // Test 100% utilization rate
        uint256 availableCashUSDT3 = 0 * 1e6; // 0 USDT, USDT is 6 decimals
        uint256 borrowedUSDT3 = 50 * 1e6; // 50 USDT
        uint256 reservedUSDT3 = 1 * 1e6; // 1 USDT
        uint256 expectedUtilizationRateAsWad3 = 1 * 1e18; // 100%
        uint256 utilizationRateAsWad3 = calculateUtilizationRateWad(
            availableCashUSDT3,
            borrowedUSDT3,
            reservedUSDT3
        );
        assertEq(utilizationRateAsWad3, expectedUtilizationRateAsWad3);
    }

    /// @notice Make sure the borrow rate calculation is correct
    function test_BorrowRateCalculation() public {
        // Set the model parameters
        OPTIMAL_UTILIZATION_RATE_WAD = 900000000000000000; // 90% utilization
        INTEREST_SLOPE_1_WAD = 200000000000000000; // 20% slope 1
        INTEREST_SLOPE_2_WAD = 600000000000000000; // 60% slope 2

        // Set utilization rate
        uint256 utilizationRateWad1 = 500000000000000000; // 0.5 or 50%
        uint256 expectedBorrowRatePerSecondWad1 = 3523310220; // approx 11.75% APY

        // Calculate borrow rate per second
        uint256 borrowRatePerSecondWad1 = calculateBorrowRatePerSecondWad(
            utilizationRateWad1
        );

        // Make sure the calculation is correct
        assertEq(borrowRatePerSecondWad1, expectedBorrowRatePerSecondWad1);

        // Set utilization rate
        uint256 utilizationRateWad2 = 940000000000000000; // 0.94 or 94%
        uint256 expectedBorrowRatePerSecondWad2 = 19025875190; // approx 82.122% APY

        // Calculate borrow rate per second
        uint256 borrowRatePerSecondWad2 = calculateBorrowRatePerSecondWad(
            utilizationRateWad2
        );

        // Make sure the calculation is correct
        assertEq(borrowRatePerSecondWad2, expectedBorrowRatePerSecondWad2);
    }
}
