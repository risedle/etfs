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
}
