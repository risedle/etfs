// SPDX-License-Identifier: GPL-3.0-or-later

// Risedle's Vault Internal Test
// Test & validate all internal functionalities

pragma solidity ^0.8.7;
pragma experimental ABIEncoderV2;

import "lib/ds-test/src/test.sol";
import {IERC20Metadata} from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {HEVM} from "./utils/HEVM.sol";
import {RisedleVault} from "../RisedleVault.sol";

// Set Risedle's Vault properties
string constant vaultTokenName = "Risedle USDT Vault";
string constant vaultTokenSymbol = "rvUSDT";
address constant usdtAddress = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
address constant rvUSDTAdmin = 0xdAC17F958D2ee523a2206206994597C13D831ec7; // set random admin

contract RisedleVaultInternalTest is
    DSTest,
    RisedleVault(vaultTokenName, vaultTokenSymbol, usdtAddress, rvUSDTAdmin)
{
    /// @notice Make sure all important variables are correctly set after deployment
    function test_VaultProperties() public {
        // Make sure underlying asset is correct
        assertEq(underlying, usdtAddress);

        // Make sure admin address is correct
        assertEq(admin, rvUSDTAdmin);

        // Make sure total borrowed is zero
        assertEq(totalBorrowed, 0);

        // Make sure total reserved is zero
        assertEq(totalReserved, 0);

        // Make sure optimal utilization rate is set to 90%
        assertEq(OPTIMAL_UTILIZATION_RATE_WAD, 900000000000000000);

        // Make sure the interest rate slop 1 is set to 20%
        assertEq(INTEREST_SLOPE_1_WAD, 200000000000000000);

        // Make sure the interest rate slop 2 is set to 60%
        assertEq(INTEREST_SLOPE_2_WAD, 600000000000000000);

        // Make sure the seconds per year is set
        assertEq(SECONDS_PER_YEAR_WAD, 31536000000000000000000000);

        // Make sure one wad correctly set
        assertEq(ONE_WAD, 1e18);

        // Make sure the Vault's token properties is correct
        IERC20Metadata vaultTokenMetadata = IERC20Metadata(address(this));
        assertEq(vaultTokenMetadata.name(), vaultTokenName);
        assertEq(vaultTokenMetadata.symbol(), vaultTokenSymbol);
        assertEq(vaultTokenMetadata.decimals(), 8);
    }

    /// @notice Make sure the Utilization Rate calculation is correct
    function test_GetUtilizationRate() public {
        // Test zero utilization rate, with reserved = 0
        uint256 availableCashUSDT1 = 100 * 1e6; // 100 USDT, USDT is 6 decimals
        uint256 borrowedUSDT1 = 0 * 1e6; // 0 USDT
        uint256 reservedUSDT1 = 0 * 1e6; // 0 USDT
        uint256 expectedUtilizationRateAsWad1 = 0; // 0%
        uint256 utilizationRateAsWad1 = getUtilizationRateWad(
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
        uint256 utilizationRateAsWad2 = getUtilizationRateWad(
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
        uint256 utilizationRateAsWad3 = getUtilizationRateWad(
            availableCashUSDT3,
            borrowedUSDT3,
            reservedUSDT3
        );
        assertEq(utilizationRateAsWad3, expectedUtilizationRateAsWad3);
    }

    /// @notice Make sure the borrow rate calculation is correct
    function test_GetBorrowRate() public {
        // Set the model parameters
        OPTIMAL_UTILIZATION_RATE_WAD = 900000000000000000; // 90% utilization
        INTEREST_SLOPE_1_WAD = 200000000000000000; // 20% slope 1
        INTEREST_SLOPE_2_WAD = 600000000000000000; // 60% slope 2

        // Set utilization rate
        uint256 utilizationRateWad1 = 500000000000000000; // 0.5 or 50%
        uint256 expectedBorrowRatePerSecondWad1 = 3523310220; // approx 11.75% APY

        // Calculate borrow rate per second
        uint256 borrowRatePerSecondWad1 = getBorrowRatePerSecondWad(
            utilizationRateWad1
        );

        // Make sure the calculation is correct
        assertEq(borrowRatePerSecondWad1, expectedBorrowRatePerSecondWad1);

        // Set utilization rate
        uint256 utilizationRateWad2 = 940000000000000000; // 0.94 or 94%
        uint256 expectedBorrowRatePerSecondWad2 = 19025875190; // approx 82.122% APY

        // Calculate borrow rate per second
        uint256 borrowRatePerSecondWad2 = getBorrowRatePerSecondWad(
            utilizationRateWad2
        );

        // Make sure the calculation is correct
        assertEq(borrowRatePerSecondWad2, expectedBorrowRatePerSecondWad2);
    }
}
