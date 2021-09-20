// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.7;
pragma experimental ABIEncoderV2;

import "lib/ds-test/src/test.sol";

import {ETHRISE} from "../ETHRISE.sol";
import {rToken} from "../rToken.sol";

contract ETHRISE_Properties is DSTest {
    /// @notice Make sure all token properties is setup correctly
    function test_ETHRISE_Properties() public {
        // Initialize new market
        ETHRISE ethrise = new ETHRISE();

        // Make sure all properties are set
        assertEq(ethrise.name(), "ETH 2x Leverage Risedle");
        assertEq(ethrise.symbol(), "ETHRISE");
        assertEq(ethrise.decimals(), 18); // It should set to default value

        // Makure sure rETHRISE properties are set
        rToken rETHRISE = rToken(address(ethrise.rETHRISE()));
        assertEq(rETHRISE.name(), "Risedle ETHRISE Supply Shares");
        assertEq(rETHRISE.symbol(), "rETHRISE");
        assertEq(rETHRISE.decimals(), 6); // Should be similar to the USDC
        assertEq(rETHRISE.totalSupply(), 0); // Should be set to zero
        assertEq(rETHRISE.admin(), address(ethrise)); // Only the market can mint & burn the rToken
    }
}
