// SPDX-License-Identifier: GPL-3.0-or-later

// Risedle ERC20 Access Control Test
// Make sure the ownership is working as expected

pragma solidity >=0.8.9;
pragma experimental ABIEncoderV2;

import "lib/ds-test/src/test.sol";
import { Hevm } from "../Hevm.sol";
import { RisedleERC20 } from "../../tokens/RisedleERC20.sol";

contract RisedleERC20AccessControl is DSTest {
    Hevm hevm;

    /// @notice Run the test setup
    function setUp() public {
        hevm = new Hevm();
    }

    /// @notice Make sure non-owner cannot mint token
    function testFail_NonOwnerCannotMintToken() public {
        // Set random address as owner
        address owner = hevm.addr(1);
        uint8 decimals = 18; // Similar to WETH

        // Create new ETF token
        RisedleERC20 token = new RisedleERC20("ETH 2x Leverage Risedle", "ETHRISE", owner, decimals);

        // Non owner trying to mint token
        // This should be failed
        token.mint(address(this), 1 ether);
    }

    /// @notice Make sure owner can mint the token
    function test_OwnerCanMintToken() public {
        // Set this contract as the owner
        address owner = address(this);
        uint8 decimals = 18; // Similar to WETH

        // Create new ETF token
        RisedleERC20 token = new RisedleERC20("ETH 2x Leverage Risedle", "ETHRISE", owner, decimals);

        // Mint new token as owner
        address recipient = hevm.addr(1);
        uint256 amount = 1 ether;
        token.mint(recipient, amount);

        // Make sure the recipient receive the token
        assertEq(token.balanceOf(recipient), amount);
    }

    /// @notice Make sure non-owner cannot burn token
    function testFail_NonOwnerCannotBurnToken() public {
        // Set this contract as the owner
        address owner = address(this);
        uint8 decimals = 18; // Similar to WETH

        // Create new ETF token
        RisedleERC20 token = new RisedleERC20("ETH 2x Leverage Risedle", "ETHRISE", owner, decimals);

        // Mint new token as owner
        address recipient = hevm.addr(1);
        uint256 amount = 1 ether;
        token.mint(recipient, amount);

        // Transfer the owner
        address newOwner = hevm.addr(1);
        token.transferOwnership(newOwner);

        // Burn the token as non owner
        // This should be failed
        token.burn(recipient, amount);
    }

    /// @notice Make sure owner can burn token
    function test_OwnerCanBurnToken() public {
        // Set this contract as the owner
        address owner = address(this);
        uint8 decimals = 18; // Similar to WETH

        // Create new ETF token
        RisedleERC20 token = new RisedleERC20("ETH 2x Leverage Risedle", "ETHRISE", owner, decimals);

        // Mint new token as owner
        address recipient = hevm.addr(1);
        uint256 amount = 1 ether;
        token.mint(recipient, amount);

        // Burn the token as owner
        token.burn(recipient, amount);

        // Make sure the token is burned
        assertEq(token.balanceOf(recipient), 0);
    }
}
