// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity >=0.8.9;
pragma experimental ABIEncoderV2;

interface IRisedleOracle {
    // Get price of the collateral based on the vault's underlying asset
    // For example ETH that trade 4000 USDC is returned as 4000 * 1e6 because USDC have 6 decimals
    function getPrice() external view returns (uint256 price);
}
