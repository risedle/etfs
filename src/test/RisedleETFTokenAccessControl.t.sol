// SPDX-License-Identifier: GPL-3.0-or-later

// Risedle ETF Token Access Control Test
// Make sure the Governance ownership is working as expected

pragma solidity 0.8.9;
pragma experimental ABIEncoderV2;

import "lib/ds-test/src/test.sol";
import {Hevm} from "./Hevm.sol";
import {RisedleETFToken} from "../RisedleETFToken.sol";

contract RisedleETFTokenAccessControl is DSTest {
    Hevm hevm;

    /// @notice Run the test setup
    function setUp() public {
        hevm = new Hevm();
    }

    /// @notice Make sure non-governance cannot mint token
    function testFail_NonGovernanceCannotMintToken() public {
        // Set random address as governance
        address governance = hevm.addr(1);
        uint8 decimals = 18; // Similar to WETH

        // Create new ETF token
        RisedleETFToken token = new RisedleETFToken(
            "ETH 2x Leverage Risedle",
            "ETHRISE",
            governance,
            decimals
        );

        // Non governance trying to mint token
        // This should be failed
        token.mint(address(this), 1 ether);
    }

    /// @notice Make sure governance can mint the token
    function test_GovernanceCanMintToken() public {
        // Set this contract as the governance
        address governance = address(this);
        uint8 decimals = 18; // Similar to WETH

        // Create new ETF token
        RisedleETFToken token = new RisedleETFToken(
            "ETH 2x Leverage Risedle",
            "ETHRISE",
            governance,
            decimals
        );

        // Mint new token as governance
        address recipient = hevm.addr(1);
        uint256 amount = 1 ether;
        token.mint(recipient, amount);

        // Make sure the recipient receive the token
        assertEq(token.balanceOf(recipient), amount);
    }

    /// @notice Make sure non-governance cannot burn token
    function testFail_NonGovernanceCannotBurnToken() public {
        // Set this contract as the governance
        address governance = address(this);
        uint8 decimals = 18; // Similar to WETH

        // Create new ETF token
        RisedleETFToken token = new RisedleETFToken(
            "ETH 2x Leverage Risedle",
            "ETHRISE",
            governance,
            decimals
        );

        // Mint new token as governance
        address recipient = hevm.addr(1);
        uint256 amount = 1 ether;
        token.mint(recipient, amount);

        // Transfer the governance
        address newGovernance = hevm.addr(1);
        token.transferOwnership(newGovernance);

        // Burn the token as non governance
        // This should be failed
        token.burn(recipient, amount);
    }

    /// @notice Make sure governance can burn token
    function test_GovernanceCanBurnToken() public {
        // Set this contract as the governance
        address governance = address(this);
        uint8 decimals = 18; // Similar to WETH

        // Create new ETF token
        RisedleETFToken token = new RisedleETFToken(
            "ETH 2x Leverage Risedle",
            "ETHRISE",
            governance,
            decimals
        );

        // Mint new token as governance
        address recipient = hevm.addr(1);
        uint256 amount = 1 ether;
        token.mint(recipient, amount);

        // Burn the token as governance
        token.burn(recipient, amount);

        // Make sure the token is burned
        assertEq(token.balanceOf(recipient), 0);
    }
}
