// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.7;
pragma experimental ABIEncoderV2;

import "lib/ds-test/src/test.sol";

import "../RisedleUSD.sol";

/// @notice Dummy contract to simulate the borrower
contract Borrower {

}

contract RisedleUSDTest is DSTest {
    /// @notice Make sure the admin is properly set
    function test_AdminIsProperlySet() public {
        // Set this contract as admin
        address admin = address(this);
        address usdtAddress = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
        RisedleUSD rusd = new RisedleUSD(
            "Risedle USDT",
            "rUSDT",
            usdtAddress,
            admin
        );

        // Make sure the admin is set
        assertTrue(rusd.hasRole(rusd.DEFAULT_ADMIN_ROLE(), admin));

        // Check with non-admin address
        address nonAdmin = address(rusd);
        assertFalse(rusd.hasRole(rusd.DEFAULT_ADMIN_ROLE(), nonAdmin));
    }

    /// @notice Make sure admin can grant borrower role
    function test_AdminCanGrantBorrower() public {
        // Set this contract as admin; so we can call admin only function
        address admin = address(this);
        address usdtAddress = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
        RisedleUSD rusd = new RisedleUSD(
            "Risedle USDT",
            "rUSDT",
            usdtAddress,
            admin
        );

        // Create new borrower actor
        Borrower borrower = new Borrower();

        // Grant borrower
        rusd.grantAsBorrower(address(borrower));

        // Make sure the role has been set
        assertTrue(rusd.isBorrower(address(borrower)));

        // Even the admin itself is not borrower
        assertFalse(rusd.isBorrower(admin));
    }
}
