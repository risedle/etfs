// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.7;
pragma experimental ABIEncoderV2;

import "lib/ds-test/src/test.sol";

import {CHAINLINK_ETH_USD, CHAINLINK_USDC_USD} from "chain/Constants.sol";
import {IChainlinkAggregatorV3} from "../interfaces/Chainlink.sol";

/// @notice Playground to play around with Chainlink contract
contract ChainlinkTest is DSTest {
    function test_getETHUSDCPrice() public {
        uint256 ethUSDPriceInGwei = _getChainlinkPriceInGwei(CHAINLINK_ETH_USD);
        uint256 usdcUSDPriceInGwei = _getChainlinkPriceInGwei(
            CHAINLINK_USDC_USD
        );

        emit log_named_uint("ETH/USD in Gwei Units", ethUSDPriceInGwei);
        emit log_named_uint("USDC/USD in Gewi Units", usdcUSDPriceInGwei);

        uint256 ethUSDCPriceInGwei = (ethUSDPriceInGwei * 1 gwei) /
            usdcUSDPriceInGwei;

        emit log_named_uint("ETH/USDC in Gwei Units", ethUSDCPriceInGwei);

        // Given x amount of eth how many usdc
        uint8 baseDecimals = 18;
        uint8 quoteDecimals = 6;
        uint256 ETHinUSDC = (ethUSDCPriceInGwei * 10**quoteDecimals) / 1 gwei;
        uint256 value = (0.5 ether * ETHinUSDC) / 10**baseDecimals;
        emit log_named_uint("ETH/USDC in 1e6", ETHinUSDC);
        emit log_named_uint("Value 0.5 ETH in 1e6 USDC", value);

        assertTrue(false); // Set failed to show the emitted event
    }

    function _getChainlinkPriceInGwei(address feed)
        internal
        view
        returns (uint256 feedPriceInGwei)
    {
        // Get latest price
        (, int256 price, , , ) = IChainlinkAggregatorV3(feed).latestRoundData();

        // Get decimals representation
        uint8 decimals = IChainlinkAggregatorV3(feed).decimals();

        // Scaleup or scaledown the decimals
        if (decimals != 9) {
            feedPriceInGwei = (uint256(price) * 1 gwei) / 10**decimals;
        } else {
            feedPriceInGwei = uint256(price);
        }
    }
}
