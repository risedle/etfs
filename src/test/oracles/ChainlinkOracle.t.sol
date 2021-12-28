// SPDX-License-Identifier: GPL-3.0-or-later

// Risedle Chainlink Oracle test
// Make sure the price oracle is working as expected

pragma solidity >=0.8.9;
pragma experimental ABIEncoderV2;

import "lib/ds-test/src/test.sol";
import { IRisedleOracle } from "../../interfaces/IRisedleOracle.sol";
import { ChainlinkOracle } from "../../oracles/ChainlinkOracle.sol";
import { CHAINLINK_ETH_USD, CHAINLINK_USDC_USD, CHAINLINK_BTC_USD, CHAINLINK_USDT_USD } from "chain/Constants.sol";

contract ChainlinkOracleTest is DSTest {
    /// @notice Make sure ETH/USDC is working as expected
    function test_ChainlinkETHUSDC() public {
        // Create new chainlink oracle
        ChainlinkOracle oracle = new ChainlinkOracle(CHAINLINK_ETH_USD, CHAINLINK_USDC_USD, 6);

        // Get price
        uint256 price = IRisedleOracle(address(oracle)).getPrice();

        // The price should > 3000 USDC (3000 * 1e6)
        assertGt(price, 3000 * 1e6);

        // The price should < 10000 USDC (10000 * 1e6)
        assertLt(price, 10000 * 1e6);
    }

    /// @notice Make sure BTC/USDT is working as expected
    function test_ChainlinkBTCUSDT() public {
        // Create new chainlink oracle
        ChainlinkOracle oracle = new ChainlinkOracle(CHAINLINK_BTC_USD, CHAINLINK_USDT_USD, 6);

        // Get price
        uint256 price = IRisedleOracle(address(oracle)).getPrice();

        // The price should > 4000 USDC (4000 * 1e6)
        assertGt(price, 40000 * 1e6);

        // The price should < 80000 USDC (80000 * 1e6)
        assertLt(price, 80000 * 1e6);
    }
}
