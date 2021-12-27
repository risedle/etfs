// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.9;
pragma experimental ABIEncoderV2;

import { IRisedleOracle } from "../interfaces/IRisedleOracle.sol";

/// @title CustomizableOracle
/// @author bayu (github.com/pyk)
/// @dev Contract to simulate oracle contract on production
contract CustomizableOracle is IRisedleOracle {
    uint256 private currentPrice;

    constructor() {
        currentPrice = 0;
    }

    function setPrice(uint256 price) public {
        currentPrice = price;
    }

    function getPrice() external view returns (uint256 price) {
        return currentPrice;
    }
}
