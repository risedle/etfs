// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.9;
pragma experimental ABIEncoderV2;

interface IRisedleOracle {
    // Get price of the collateral based on the vault's underlying asset
    function getPrice() external view returns (uint256 price);
}
