// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.9;
pragma experimental ABIEncoderV2;

import "lib/ds-test/src/test.sol";
import { IERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import "./Hevm.sol";
import { USDC_ADDRESS, USDT_ADDRESS, WETH_ADDRESS } from "chain/Constants.sol";

contract HevmTest is DSTest {
    Hevm hevm;

    function setUp() public {
        hevm = new Hevm();
    }

    function test_setUSDCBalance() public {
        IERC20 token = IERC20(USDC_ADDRESS);
        address account = hevm.addr(1);
        uint256 amount = 100 * 1e6; // 100 USDC

        // Set the balance
        hevm.setUSDCBalance(account, amount);

        // Check the balance
        uint256 balance = token.balanceOf(account);

        // Make sure it's updated
        assertEq(amount, balance);
    }

    function test_setUSDTBalance() public {
        IERC20 token = IERC20(USDT_ADDRESS);
        address account = hevm.addr(1);
        uint256 amount = 100 * 1e6; // 100 USDT

        // Set the balance
        hevm.setUSDTBalance(account, amount);

        // Check the balance
        uint256 balance = token.balanceOf(account);

        // Make sure it's updated
        assertEq(amount, balance);
    }

    function test_setWETHBalance() public {
        IERC20 token = IERC20(WETH_ADDRESS);
        address account = hevm.addr(1);
        uint256 amount = 100 * 1e6; // 100 WETH

        // Set the balance
        hevm.setWETHBalance(account, amount);

        // Check the balance
        uint256 balance = token.balanceOf(account);

        // Make sure it's updated
        assertEq(amount, balance);
    }

    function test_setUNIBalance() public {
        IERC20 token = IERC20(UNI_ADDRESS);
        address account = hevm.addr(1);
        uint256 amount = 100 ether; // 100 UNI

        // Set the balance
        hevm.setUNIBalance(account, amount);

        // Check the balance
        uint256 balance = token.balanceOf(account);

        // Make sure it's updated
        assertEq(amount, balance);
    }

    function test_setGOHMBalance() public {
        IERC20 token = IERC20(GOHM_ADDRESS);
        address account = hevm.addr(1);
        uint256 amount = 100 ether; // 100 gOHM

        // Set the balance
        hevm.setGOHMBalance(account, amount);

        // Check the balance
        uint256 balance = token.balanceOf(account);

        // Make sure it's updated
        assertEq(balance, amount);
    }
}
