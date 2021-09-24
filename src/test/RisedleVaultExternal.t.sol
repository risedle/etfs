// SPDX-License-Identifier: GPL-3.0-or-later

// Risedle's Vault External Test
// Test & validate user/contract interaction with Risedle's Vault

pragma solidity ^0.8.7;
pragma experimental ABIEncoderV2;

import "lib/ds-test/src/test.sol";

import {HEVM} from "./utils/HEVM.sol";
import {RisedleVault} from "../RisedleVault.sol";

/// @notice Dummy contract to simulate the borrower
contract Borrower {

}

contract RisedleVaultExternalTest is DSTest {
    RisedleVault rvUSDT;
    address rvUSDTAdmin;
    HEVM hevm;

    function setUp() public {
        // Set this contract as admin
        rvUSDTAdmin = address(this);
        address usdtAddress = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
        rvUSDT = new RisedleVault(
            "Risedle USDT Vault",
            "rvUSDT",
            usdtAddress,
            rvUSDTAdmin
        );

        // Initialize new hevm
        hevm = new HEVM();
    }

    /// @notice Make sure the admin is properly set
    function test_AdminIsProperlySet() public {
        // Make sure the admin is set
        assertTrue(rvUSDT.hasRole(rvUSDT.DEFAULT_ADMIN_ROLE(), rvUSDTAdmin));

        // Check with non-admin address
        address nonAdmin = address(rvUSDT);
        assertFalse(rvUSDT.hasRole(rvUSDT.DEFAULT_ADMIN_ROLE(), nonAdmin));
    }

    /// @notice Make sure admin can grant borrower role
    function test_AdminCanGrantBorrower() public {
        // Create new borrower actor
        Borrower borrower = new Borrower();

        // Grant borrower
        rvUSDT.grantAsBorrower(address(borrower));

        // Make sure the role has been set
        assertTrue(rvUSDT.isBorrower(address(borrower)));

        // Even the admin itself is not borrower
        assertFalse(rvUSDT.isBorrower(rvUSDTAdmin));
    }
}
