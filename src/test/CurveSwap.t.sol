// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.7;
pragma experimental ABIEncoderV2;

import "lib/ds-test/src/test.sol";

import {CHAINLINK_ETH_USD, CHAINLINK_USDC_USD, USDC_ADDRESS, WETH_ADDRESS, USDT_ADDRESS} from "chain/Constants.sol";
import {IAddressProvider, ISwap, IRegistry} from "../interfaces/Curve.sol";

/// @notice Playground to play around with Uniswap V3 contract
contract CurveSwapTest is DSTest {
    function test_SwapUSDCToWETH() public {
        // Gimana cara swap USDC ke WETH
        address curveProviderAddress = 0x0000000022D53366457F9d5E68Ec105046FC4383;

        IAddressProvider curveProvider = IAddressProvider(curveProviderAddress);
        address curveSwapAddress = curveProvider.get_address(3);
        address curveRegistryAddress = curveProvider.get_registry();
        emit log_named_address("Curve Swap Address", curveSwapAddress);
        emit log_named_address("Curve Registry Address", curveRegistryAddress);

        // ISwap curveSwap = ISwap(curveSwapAddress);
        IRegistry curveRegistry = IRegistry(curveRegistryAddress);

        // Get pool
        // uint256 amount = 1000 * 1e6; // 1000 USDC
        address poolUSDTtoWETH = curveRegistry.find_pool_for_coins(
            USDT_ADDRESS,
            WETH_ADDRESS,
            0
        );
        address poolUSDCtoWETH = curveRegistry.find_pool_for_coins(
            USDC_ADDRESS,
            WETH_ADDRESS,
            0
        );
        emit log_named_address("Curve USDT->WETH Pool", poolUSDTtoWETH);
        emit log_named_address("Curve USDC->WETH Pool", poolUSDCtoWETH);

        // Exchange
        // address receiver = address(this);
        // uint256 expected = 0; // Set this using oracle data
        // uint256 receivedAmount = curveSwap.exchange(
        //     pool,
        //     USDC_ADDRESS,
        //     WETH_ADDRESS,
        //     amount,
        //     expected,
        //     receiver
        // );

        // Uncomment below to see log above
        // assertTrue(false); // Set failed to show the emitted event
    }
}
