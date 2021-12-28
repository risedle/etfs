// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.9;
pragma experimental ABIEncoderV2;

import { IERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20Metadata } from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { IRisedleSwap } from "../interfaces/IRisedleSwap.sol";
import { IRisedleOracle } from "../interfaces/IRisedleOracle.sol";

import { USDC_ADDRESS } from "chain/Constants.sol";

/// @title Contract implements IRisesdleSwap
/// @author bayu (github.com/pyk)
/// @dev This contract is used for testing only
contract CustomizableSwap is IRisedleSwap {
    using SafeERC20 for IERC20;

    /// Storages
    address private oracle;
    uint256 private slippageInEther;

    constructor(address oracleContract, uint256 slippage) {
        oracle = oracleContract;
        slippageInEther = slippage;
    }

    function swap(
        address tokenIn,
        address tokenOut,
        uint256 maxAmountIn,
        uint256 amountOut
    ) external returns (uint256 amountIn) {
        // Get the current price
        uint256 currentPrice = IRisedleOracle(oracle).getPrice();

        // Add artificial slippage
        uint256 slippage = (slippageInEther * currentPrice) / 1 ether;
        uint256 finalPrice;

        // Calculate amountIn
        uint8 tokenOutDecimals = IERC20Metadata(tokenOut).decimals();
        uint8 tokenInDecimals = IERC20Metadata(tokenIn).decimals();
        if (tokenIn == USDC_ADDRESS) {
            finalPrice = currentPrice + slippage; // Buy positive slippage
            amountIn = (amountOut * finalPrice) / (10**tokenOutDecimals);
        } else {
            finalPrice = currentPrice - slippage; // Sell negative slippgage
            amountIn = (amountOut * (10**tokenInDecimals)) / finalPrice;
        }

        // Transfer the specified amount of tokenIn to this contract.
        // Should be failed when amountIn > maxAmountIn coz the caller only approve
        // to transfer maxAmountIn
        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);

        // Transfer the specified amount of tokenOut to the caller
        IERC20(tokenOut).safeTransfer(msg.sender, amountOut);
    }
}
