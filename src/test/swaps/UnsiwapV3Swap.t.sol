// SPDX-License-Identifier: GPL-3.0-or-later

// Risedle Uniswap V3 Swap test
// Make sure the swap is working as expected

pragma solidity >=0.8.9;
pragma experimental ABIEncoderV2;

import "lib/ds-test/src/test.sol";

import { IERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

import { Hevm } from "../Hevm.sol";
import { IRisedleOracle } from "../../interfaces/IRisedleOracle.sol";
import { IRisedleSwap } from "../../interfaces/IRisedleSwap.sol";
import { ChainlinkOracle } from "../../oracles/ChainlinkOracle.sol";
import { UniswapV3Swap } from "../../swaps/UniswapV3Swap.sol";
import { CHAINLINK_ETH_USD, CHAINLINK_USDC_USD, UNISWAPV3_SWAP_ROUTER, USDC_ADDRESS, WETH_ADDRESS } from "chain/Constants.sol";

contract UniswapV3SwapTest is DSTest {
    using SafeERC20 for IERC20;

    /// @notice hevm utils to alter mainnet state
    Hevm hevm;

    function setUp() public {
        hevm = new Hevm();
    }

    /// @notice Make sure the contract is working as expected
    function test_SwapUSDCToWETH() public {
        // Set the contract balance to 20K USDC
        hevm.setUSDCBalance(address(this), 20000 * 1e6); // 20K USDC

        // Use Uniswap V3 WETH/USDC 0.05% fee liquidity
        UniswapV3Swap uniswap = new UniswapV3Swap(UNISWAPV3_SWAP_ROUTER, 500);

        // Make sure the public variable is correct
        assertEq(uniswap.router(), UNISWAPV3_SWAP_ROUTER);
        assertEq(uniswap.poolFee(), 500);

        // Use Chainlink oracle
        ChainlinkOracle oracle = new ChainlinkOracle("Chainlink ETH/USDC", CHAINLINK_ETH_USD, CHAINLINK_USDC_USD, 6);

        // Execute the borrow and swap
        uint256 collateralAmount = 1 ether;
        uint256 collateralPrice = IRisedleOracle(address(oracle)).getPrice();
        // Maximum plus +1% from the oracle price
        uint256 maximumCollateralPrice = collateralPrice + ((0.01 ether * collateralPrice) / 1 ether);
        uint256 maxAmountIn = (collateralAmount * maximumCollateralPrice) / (1 ether);

        // Allow swap contract to spend the the USDC
        IERC20(USDC_ADDRESS).safeApprove(address(uniswap), maxAmountIn);

        // Swap USDC to WETH
        uint256 amountIn = IRisedleSwap(address(uniswap)).swap(USDC_ADDRESS, WETH_ADDRESS, maxAmountIn, collateralAmount);

        // Make sure the amountIn is less than the maxAmountIn
        assertLt(amountIn, maxAmountIn);

        // Make sure this contract get the WETH
        assertEq(IERC20(WETH_ADDRESS).balanceOf(address(this)), collateralAmount);

        // Make sure the balance is updated
        assertEq(IERC20(USDC_ADDRESS).balanceOf(address(this)), (20000 * 1e6) - amountIn);
    }
}
