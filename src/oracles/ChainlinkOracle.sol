// SPDX-License-Identifier: GPL-3.0-or-later

// Risedle Chainlink Price Oracle
// It implements IRisedleOracle interface.
//
// Copyright (c) 2021 Bayu - All rights reserved
// github: pyk
// email: bayu@risedle.com
pragma solidity >=0.8.9;
pragma experimental ABIEncoderV2;

import { IChainlinkAggregatorV3 } from "../interfaces/Chainlink.sol";

contract ChainlinkOracle {
    // Chainlink feed contract addresses
    // See here: https://docs.chain.link/docs/reference-contracts/
    string public name;
    address public baseFeed;
    address public quoteFeed;
    uint8 public quoteDecimals;

    /**
     * @notice Contruct new Chainlink oracle
     */
    constructor(
        string memory _name, // The oracle identifier (e.g. ETH/USDC)
        address _baseFeed, // The contract address of base asset price feed in term of USD (e.g ETH/USD)
        address _quoteFeed, // The contract address of quote asset price feed in term of USD (e.g. USDC/USD)
        uint8 _quoteDecimals // The decimals number of quote asset (e.g. USDC is 6 decimals token)
    ) {
        name = _name;
        baseFeed = _baseFeed;
        quoteFeed = _quoteFeed;
        quoteDecimals = _quoteDecimals;
    }

    /**
     * @notice getUSDPriceInGwei returns the latest price from chainlink in term of USD
     * @param feed The contract address of the chainlink feed (e.g. ETH/USD or USDC/USD)
     * @return priceInGwei The USD price in Gwei units
     */
    function getUSDPriceInGwei(address feed) internal view returns (uint256 priceInGwei) {
        // Get latest price
        (, int256 price, , , ) = IChainlinkAggregatorV3(feed).latestRoundData();

        // Get feed decimals representation
        uint8 feedDecimals = IChainlinkAggregatorV3(feed).decimals();

        // Scaleup or scaledown the decimals
        if (feedDecimals != 9) {
            priceInGwei = (uint256(price) * 1 gwei) / 10**feedDecimals;
        } else {
            priceInGwei = uint256(price);
        }
    }

    /**
     * @notice getPrice returns the base token price in term of quote token.
     * @return price The price of the base token. For example ETH/USDC would trade around 4000 * 1e6 USDC
     */
    function getPrice() external view returns (uint256 price) {
        uint256 baseUSDPriceInGwei = getUSDPriceInGwei(baseFeed);
        uint256 quoteUSDPriceInGwei = getUSDPriceInGwei(quoteFeed);
        uint256 priceInGwei = (baseUSDPriceInGwei * 1 gwei) / quoteUSDPriceInGwei;

        // Convert gwei to quote decimals token
        // For example USDC will have 6 decimals. So we convert gwei (9 decimals) to 6 decimals
        price = (priceInGwei * (10**quoteDecimals)) / 1 gwei;
    }
}
