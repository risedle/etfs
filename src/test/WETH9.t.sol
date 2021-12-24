// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;
pragma experimental ABIEncoderV2;

import "lib/ds-test/src/test.sol";

import { WETH9 } from "../tokens/WETH9.sol";

/// @title WETH9 Test
/// @author bayu (github.com/pyk)
contract WETH9Test is DSTest {
    /// @notice Make sure it transfer 1M WETH to the deployer
    function test_MintAddDeploy() public {
        WETH9 weth = new WETH9();

        // Make sure the total supply is correct
        assertEq(weth.totalSupply(), 1_000_000 ether);

        // Make sure the balance is correct
        assertEq(weth.balanceOf(address(this)), 1_000_000 ether);
    }
}
