// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.7;
pragma experimental ABIEncoderV2;

import "lib/ds-test/src/test.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {ETHRISE} from "../ETHRISE.sol";
import {rToken} from "../rToken.sol";
import {HEVM} from "./utils/HEVM.sol";

/// @notice We use this contract to interact with ETHRISE market as a lender
contract Lender {
    /// @notice ETHRISE market that the lender interact with
    ETHRISE private immutable _ethrise;

    /// @notice USDC contract in mainnet
    IERC20 private immutable USDC;

    constructor(ETHRISE ethrise) {
        // Assign ETHRISE market contract
        _ethrise = ethrise;

        // Assign USDC contract in mainnet
        USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    }

    function depositUSDC(uint256 usdcAmount) external {
        // Allow ETHRISE market to spend the USDC
        USDC.approve(address(_ethrise), uint256((2**256) - 1));
        _ethrise.depositUSDC(usdcAmount);
    }
}

contract ETHRISELenderTest is DSTest {
    HEVM hevm;
    IERC20 USDC;

    function setUp() public {
        hevm = new HEVM();
        // Assign USDC contract in mainnet
        USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    }

    /// @notice Make sure depositUSDC working properly
    /// TODO(bayu):
    /// - Add test where there is borrowed USDC
    /// - Test rETHRISE USDC value function
    function test_ETHRISE_Lender_DepositUSDC() public {
        // Create new ETHRISE market
        ETHRISE ethrise = new ETHRISE();

        // Create new lender actor
        Lender lenderA = new Lender(ethrise);

        // Top up the USDC balance of the lender
        uint256 lenderAUSDCBalance = 100 *
            (10**IERC20Metadata(address(USDC)).decimals()); // 100 USDC
        hevm.sendUSDC(address(lenderA), lenderAUSDCBalance);
        assertEq(USDC.balanceOf(address(lenderA)), lenderAUSDCBalance); // Doublecheck

        // Lender A deposit
        lenderA.depositUSDC(lenderAUSDCBalance);

        // Lender A should receive 1:1 rETHRISE
        assertEq(
            ethrise.rETHRISE().balanceOf(address(lenderA)),
            lenderAUSDCBalance
        );

        // ethrise market should receive the USDC
        assertEq(USDC.balanceOf(address(ethrise)), lenderAUSDCBalance);

        // Suppose the interest is accrued
        uint256 interestPaidAmount = 50 *
            (10**IERC20Metadata(address(USDC)).decimals()); // 50 USDC
        // We simulate the paid interest by sending USDC token to the ETHRISE
        // market contract to increase the total available USDC
        hevm.sendUSDC(address(ethrise), interestPaidAmount);

        // Make sure the interest is received by ETHRISE market
        assertEq(
            USDC.balanceOf(address(ethrise)),
            lenderAUSDCBalance + interestPaidAmount
        );

        // Then lender B should receive less rETHRISE token with the same amount USDC
        Lender lenderB = new Lender(ethrise);

        // Top up the USDC balance of the lender B, with the same amount of lender A
        hevm.sendUSDC(address(lenderB), lenderAUSDCBalance);
        assertEq(USDC.balanceOf(address(lenderB)), lenderAUSDCBalance); // Doublecheck

        // Lender B deposit
        lenderB.depositUSDC(lenderAUSDCBalance);

        // Lender B should receive less amount of rETHRISE than the lender A
        assertLt(
            ethrise.rETHRISE().balanceOf(address(lenderB)),
            ethrise.rETHRISE().balanceOf(address(lenderA))
        );
    }
}
