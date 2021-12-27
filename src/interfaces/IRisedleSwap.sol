// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity >=0.8.9;
pragma experimental ABIEncoderV2;

interface IRisedleSwap {
    /**
     * @notice Swap tokenIn to tokenOut
     * @param tokenIn The ERC20 address of token that we want to swap
     * @param tokenOut The ERC20 address of token that we want swap to
     * @param maxAmountIn The maximum amount of tokenIn to get the tokenOut with amountOut
     * @param amountOut The amount of tokenOut that we want to get
     * @return amountIn The amount of tokenIn that we spend to get the amountOut of tokenOut
     */
    function swap(
        address tokenIn,
        address tokenOut,
        uint256 maxAmountIn,
        uint256 amountOut
    ) external returns (uint256 amountIn);
}
