// SPDX-License-Identifier: GPL-3.0-or-later

// Rise Token Vault Access control test
// Make sure the ownership is working as expected
pragma solidity 0.8.9;
pragma experimental ABIEncoderV2;

import "lib/ds-test/src/test.sol";

import {Hevm} from "./Hevm.sol";
import {RiseTokenVault} from "../RiseTokenVault.sol";

import {USDC_ADDRESS, WETH_ADDRESS, CHAINLINK_USDC_USD, CHAINLINK_ETH_USD} from "chain/Constants.sol";

contract RiseTokenVaultAccessControlTest is DSTest {
    Hevm hevm;

    /// @notice Run the test setup
    function setUp() public {
        hevm = new Hevm();
    }

    /// @notice Make sure non-owner cannot create new RISE token
    function testFail_NonOwnerCannotCreateNewRiseToken() public {
        // Create new vault; by default the deployer is the admin
        RiseTokenVault vault = new RiseTokenVault(
            "Risedle USDC Vault",
            "rvUSDC",
            USDC_ADDRESS
        );

        // Transfer the ownership
        address newOwner = hevm.addr(1);
        vault.transferOwnership(newOwner);

        // Create dummy swapper address
        address uniswapV3Swapper = hevm.addr(2);

        // Create new RISE token as non-owner; should be failed
        vault.create(
            "ETH 2x Leverage Risedle",
            "ETHRISE",
            WETH_ADDRESS,
            CHAINLINK_ETH_USD,
            uniswapV3Swapper,
            100 * 1e6,
            0.001 ether
        );
    }
}
