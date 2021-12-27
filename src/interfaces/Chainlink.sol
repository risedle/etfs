// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity >=0.8.9;
pragma experimental ABIEncoderV2;

/// @notice Chainlink Aggregator V3 Interface
/// @dev https://docs.chain.link/docs/price-feeds-api-reference/
interface IChainlinkAggregatorV3 {
    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );

    function decimals() external view returns (uint8);
}
