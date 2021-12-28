// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.9;
pragma experimental ABIEncoderV2;

import "lib/ds-test/src/test.sol";

import { WETH9 } from "../tokens/WETH9.sol";

contract WETH9User {
    WETH9 weth9;

    constructor(WETH9 _weth9) {
        weth9 = _weth9;
    }

    function deposit() public {
        weth9.deposit{ value: 1 ether }();
    }

    function withdraw() public {
        weth9.withdraw(1 ether);
    }

    receive() external payable {}
}

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

    /// @notice Make sure deposit and withdraw is working
    function test_DepositAndWithdraw() public {
        WETH9 weth = new WETH9();
        WETH9User user = new WETH9User(weth);
        (bool success, ) = address(user).call{ value: 1 ether }("");
        require(success, "!TEF");

        // Wrap 1 ETH to WETH
        user.deposit();
        assertEq(address(user).balance, 0);
        assertEq(weth.balanceOf(address(user)), 1 ether);

        // Unwrap 1 WETH to ETH
        user.withdraw();
        assertEq(weth.balanceOf(address(user)), 0);
        assertEq(address(user).balance, 1 ether);
    }
}
