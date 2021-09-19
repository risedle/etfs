// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.7;
pragma experimental ABIEncoderV2;

import "lib/ds-test/src/test.sol";

import {HEVM} from "./IHEVM.sol";
import {Token} from "./rToken.sol";

// TODO(bayu):
// - Prove that we can assign new admin role
contract rTokenTest is DSTest {
    HEVM hevm;

    /// @notice Initialize hevm, so we can use the cheat codes
    function setUp() public {
        hevm = HEVM(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    }

    /// @notice Make sure all token properties is setup correctly
    function test_rToken_Properties() public {
        // Set properties
        string memory tokenName = "Risedle ETHRISE Supply";
        string memory tokenSymbol = "rETHRISE";
        uint8 tokenDecimals = 8; // same as cDAI
        address tokenAdminAddress = address(this); // set current contract as admin

        // Initialize new token
        Token token = new Token(
            tokenName,
            tokenSymbol,
            tokenDecimals,
            tokenAdminAddress
        );

        // Make sure all properties are set
        assertEq(token.name(), tokenName);
        assertEq(token.symbol(), tokenSymbol);
        assertEq(token.decimals(), tokenDecimals);
        assertEq(token.admin(), tokenAdminAddress);
    }

    /// @notice Test that admin can mint the token
    function test_rToken_AdminCanMintToken() public {
        // Initialize new token
        address adminAddress = address(this); // Set this contract as admin
        Token token = new Token(
            "Risedle ETHRISE Supply",
            "rETHRISE",
            8,
            adminAddress
        );

        // Setup recipient
        address recipient = hevm.addr(1);
        uint256 mintedAmount = 10000;

        // Mint new token to the recipient
        token.mint(recipient, mintedAmount);

        // recipient balance should be updated
        assertEq(token.balanceOf(recipient), mintedAmount);

        // Token supply should be updated
        assertEq(token.totalSupply(), mintedAmount);
    }

    /// @notice Test that only adminAddress can mint the token
    function testFail_rToken_NonAdminCannotMintToken() public {
        address adminAddress = hevm.addr(1); // Set admin to other user
        Token token = new Token(
            "Risedle ETHRISE Supply",
            "rETHRISE",
            8,
            adminAddress
        );

        address recipient = hevm.addr(1);
        uint256 mintedAmount = 10000;

        // address(this), current contract, trying to mint the token
        // it should be fails
        token.mint(recipient, mintedAmount);
    }

    /// @notice Test that admin can burn the token
    function test_rToken_AdminCanBurnToken() public {
        // Initialize new token
        address adminAddress = address(this); // Set this contract as admin
        Token token = new Token(
            "Risedle ETHRISE Supply",
            "rETHRISE",
            8,
            adminAddress
        );

        // Setup recipient
        address recipient = hevm.addr(1);
        uint256 mintedAmount = 10000;

        // Mint new token to the recipient
        token.mint(recipient, mintedAmount);
        assertEq(token.balanceOf(recipient), mintedAmount);
        assertEq(token.totalSupply(), mintedAmount);

        // Burn the token
        token.burn(recipient, mintedAmount);
        assertEq(token.balanceOf(recipient), 0);
        assertEq(token.totalSupply(), 0);
    }

    /// @notice Test that non admin cannot burn the token
    function testFail_rToken_NonAdminCannotBurnToken() public {
        address adminAddress = hevm.addr(1);
        // Initialize new token
        Token token = new Token(
            "Risedle ETHRISE Supply",
            "rETHRISE",
            8,
            adminAddress
        );

        // Setup from
        address fromAccount = hevm.addr(2);
        uint256 burnedAmount = 1000;

        // The contract trying to burn a token, it should be fails
        token.burn(fromAccount, burnedAmount);
    }
}
