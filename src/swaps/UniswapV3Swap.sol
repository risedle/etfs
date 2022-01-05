// SPDX-License-Identifier: GPL-3.0-or-later

// Risedle Uniswap V3 Swap contract
// It implements IRisedleSwap interface.
//
// Copyright (c) 2021 Bayu - All rights reserved
// github: pyk
// email: bayu@risedle.com
pragma solidity >=0.8.9;
pragma experimental ABIEncoderV2;

import { IERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

import { ISwapRouter } from "../interfaces/UniswapV3.sol";

contract UniswapV3Swap {
    using SafeERC20 for IERC20;

    address public router; // The Uniswap V3 router address
    uint24 public poolFee; // The Uniswap V3 pool's fee (500, 3000, 10000)

    constructor(address uniswapRouter, uint24 fee) {
        router = uniswapRouter;
        poolFee = fee;
    }

    /// @notice Swap tokenIn to tokenOut; It returns the amount of tokenIn that we spend to get the amountOut of tokenOut
    function swap(
        address tokenIn, // The ERC20 address of token that we want to swap
        address tokenOut, // The ERC20 address of token that we want swap to
        uint256 maxAmountIn, // The maximum amount of tokenIn to get the tokenOut with amountOut
        uint256 amountOut // The amount of tokenOut that we want to get
    ) external returns (uint256 amountIn) {
        // Transfer the specified amount of tokenIn to this contract.
        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), maxAmountIn);

        // Approve Uniswap V3 router to spend maximum amount in
        IERC20(tokenIn).safeApprove(router, maxAmountIn);

        // Set the params, we want to get exact amount of collateral with minimal supply out as possible
        ISwapRouter.ExactOutputSingleParams memory params = ISwapRouter.ExactOutputSingleParams({ tokenIn: tokenIn, tokenOut: tokenOut, fee: poolFee, recipient: msg.sender, deadline: block.timestamp, amountOut: amountOut, amountInMaximum: maxAmountIn, sqrtPriceLimitX96: 0 });

        // Execute the swap
        amountIn = ISwapRouter(router).exactOutputSingle(params);

        // For exact output swaps, the maxAmountIn may not have all been spent
        // If the actual amount spent (amountIn) is less than the specified maximum amount, we must refund the msg.sender and approve the swapRouter to spend 0.
        if (amountIn < maxAmountIn) {
            IERC20(tokenIn).safeApprove(router, 0);
            IERC20(tokenIn).safeTransfer(msg.sender, maxAmountIn - amountIn);
        }
    }
}
