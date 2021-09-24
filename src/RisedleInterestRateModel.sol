// SPDX-License-Identifier: GPL-3.0-or-later

// RisedleInterestRateModel is base contract to handle interest calculation
// The interest rate model is available here: https://observablehq.com/@pyk/ethrise
// It uses wad, a decimal number with 18 digits of precision, to represent the
// borrow rate.
//
// I wrote this for ETHOnline Hackathon 2021. Enjoy.

// Copyright (c) 2021 Bayu - All rights reserved
// github: pyk

pragma solidity ^0.8.7;
pragma experimental ABIEncoderV2;

import {DSMath} from "lib/ds-math/src/math.sol";

/// @title Risedle's Lending Pool Contract
contract RisedleInterestRateModel is DSMath {
    /// @notice Optimal utilization rate stored in wad
    ///         For example, 90% or 0.9 is equal to 900000000000000000
    uint256 public OPTIMAL_UTILIZATION_RATE_WAD;

    /// @notice Interest slope 1, stored in wad
    uint256 public INTEREST_SLOPE_1_WAD;

    /// @notice Interest slop 2, stored in wad
    uint256 public INTEREST_SLOPE_2_WAD;

    /// @notice Number of seconds in a year, stored in wad
    uint256 public immutable SECONDS_PER_YEAR_WAD = 31536000000000000000000000;

    /// @notice 1 stored as wad
    uint256 public immutable ONE_WAD = 1000000000000000000;

    /**
     * @notice calculateUtilizationRateWad calculates the utilization rate of
     *         the lending pool.
     * @param cash The amount of cash available to borrow in the lending pool
     * @param borrowed The amount of borrowed asset in the lending pool
     * @param reserved The amount of reserved asset in the lending pool
     * @return The utilization rate as a Wad,
     */
    function calculateUtilizationRateWad(
        uint256 cash,
        uint256 borrowed,
        uint256 reserved
    ) public pure returns (uint256) {
        // Utilization rate is 0% when there is no borrowed asset
        if (borrowed == 0) {
            return 0;
        }
        // Utilization rate is 100% when there is no cash available
        if (cash == 0) {
            return 1 * 1e18;
        }

        // Ut = Bt/(Ct + Bt - Rt)
        return wdiv(borrowed, sub(add(cash, borrowed), reserved));
    }

    /**
     * @notice calculateBorrowRatePerSecondWad calculates the borrow rate per second.
     * @param utilizationRateWad The current utilization rate, stored as wad
     * @return The borrow rate as a wad
     */
    function calculateBorrowRatePerSecondWad(uint256 utilizationRateWad)
        internal
        view
        returns (uint256)
    {
        // Calculate the borrow rate
        if (utilizationRateWad <= OPTIMAL_UTILIZATION_RATE_WAD) {
            uint256 borrowRatePerYearWad = wmul(
                wdiv(utilizationRateWad, OPTIMAL_UTILIZATION_RATE_WAD),
                INTEREST_SLOPE_1_WAD
            );
            return wdiv(borrowRatePerYearWad, SECONDS_PER_YEAR_WAD);
        } else {
            uint256 borrowRatePerYearWad = add(
                INTEREST_SLOPE_1_WAD,
                wmul(
                    wdiv(
                        sub(utilizationRateWad, OPTIMAL_UTILIZATION_RATE_WAD),
                        sub(ONE_WAD, utilizationRateWad)
                    ),
                    INTEREST_SLOPE_2_WAD
                )
            );
            return wdiv(borrowRatePerYearWad, SECONDS_PER_YEAR_WAD);
        }
    }
}
