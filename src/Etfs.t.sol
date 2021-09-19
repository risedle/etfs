// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "ds-test/test.sol";

import "./Etfs.sol";

contract EtfsTest is DSTest {
    Etfs etfs;

    function setUp() public {
        etfs = new Etfs();
    }

    function testFail_basic_sanity() public {
        assertTrue(false);
    }

    function test_basic_sanity() public {
        assertTrue(true);
    }
}
