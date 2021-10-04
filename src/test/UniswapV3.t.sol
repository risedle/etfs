// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.7;
pragma experimental ABIEncoderV2;

import "lib/ds-test/src/test.sol";

import {USDC_ADDRESS, WETH_ADDRESS, UNISWAPV3_SWAP_ROUTER, CHAINLINK_ETH_USD, CHAINLINK_USDC_USD} from "chain/Constants.sol";
import {ISwapRouter} from "../interfaces/UniswapV3.sol";
import {Hevm} from "./Hevm.sol";
import {TransferHelper} from "lib/v3-periphery/contracts/libraries/TransferHelper.sol";
import {IChainlinkAggregatorV3} from "../interfaces/Chainlink.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

/// @notice Playground to play around with Uniswap V3 contract
contract UniswapV3Test is DSTest {
    Hevm hevm;

    function setUp() public {
        hevm = new Hevm();
    }

    function test_SwapUSDCToWETH() public {
        // First thing first, send USDC to this contract
        uint256 balance = 10000 * 1e6; // 10K USDC
        hevm.setUSDCBalance(address(this), balance);

        // Create the swap router
        ISwapRouter swapRouter = ISwapRouter(UNISWAPV3_SWAP_ROUTER);

        // Approve uniswap router to spend the balance
        TransferHelper.safeApprove(USDC_ADDRESS, address(swapRouter), balance);

        // Gimana cara swap USDC ke WETH
        uint24 poolFee = 500;
        uint256 amountInMaximum = 10000 * 1e6; // We use oracle to determine the amountInMaximum
        address recipient = hevm.addr(1);
        ISwapRouter.ExactOutputSingleParams memory params = ISwapRouter
            .ExactOutputSingleParams({
                tokenIn: USDC_ADDRESS,
                tokenOut: WETH_ADDRESS,
                fee: poolFee,
                recipient: msg.sender,
                deadline: block.timestamp,
                amountOut: 1 ether,
                amountInMaximum: amountInMaximum,
                sqrtPriceLimitX96: 0
            });

        // The call to `exactInputSingle` executes the swap.
        uint256 amountIn = swapRouter.exactOutputSingle(params);

        emit log_named_uint("After swap amountIn", amountIn);
        // Uncomment below to see log above
        // assertTrue(false); // Set failed to show the emitted event
    }

    function test_BorrowAndSwap() public {
        // uint256 gas = gasleft();

        // Collaterals
        address collateralAddress = WETH_ADDRESS;
        uint8 collateralDecimals = 18;
        address collateralFeed = CHAINLINK_ETH_USD;

        // Supplies
        address supplyAddress = USDC_ADDRESS;
        uint8 supplyDecimals = 6;
        address supplyFeed = CHAINLINK_USDC_USD;

        // Input collateral amount
        uint256 collateralAmount = 10 ether;
        emit log_named_uint("collateralAmount", collateralAmount);

        // Get the price of collateral and supply from Chainlink
        uint256 collateralPriceInGwei = getChainlinkPriceInGwei(collateralFeed);
        emit log_named_uint("collateralPriceInGwei", collateralPriceInGwei);
        uint256 supplyPriceInGwei = getChainlinkPriceInGwei(supplyFeed);
        emit log_named_uint("supplyPriceInGwei", supplyPriceInGwei);

        // Convert Collateral/USD and Supply/USD to Collateral/Supply
        uint256 priceInGwei = (collateralPriceInGwei * 1 gwei) /
            supplyPriceInGwei;
        emit log_named_uint("priceInGwei", priceInGwei);

        // Convert gwei to quote (supply) decimals
        uint256 price = (priceInGwei * (10**supplyDecimals)) / 1 gwei;
        emit log_named_uint("price", price);

        // Calculate the borrow amount, the amount of supply token that we need to borrow
        uint256 borrowAmount = (collateralAmount * price) /
            (10**collateralDecimals);
        emit log_named_uint("borrowAmount", borrowAmount);
        uint256 priceBump = getPriceBump(borrowAmount);
        emit log_named_uint("priceBump", priceBump);

        // Perform swap
        // First let's assume the supply is 10K USDC
        uint256 balance = 1e5 * 1e6; // 100K USDC
        hevm.setUSDCBalance(address(this), balance);

        // Create the swap router
        ISwapRouter swapRouter = ISwapRouter(UNISWAPV3_SWAP_ROUTER);

        // Approve uniswap router to spend the balance
        // TODO: change the balance based on the borrowAmount
        TransferHelper.safeApprove(
            USDC_ADDRESS,
            address(swapRouter),
            borrowAmount + priceBump
        );

        // TODO: check if borrowAmount + priceBump < totalUnderlyingAsset
        // otherwise cancel di transaction with !SupplyNotEnough

        uint24 poolFee = 500;
        // TODO: change amountInMaximum based on borrowAmount
        // uint256 amountInMaximum = balance;
        uint256 amountInMaximum = borrowAmount + priceBump;
        address recipient = hevm.addr(1);
        ISwapRouter.ExactOutputSingleParams memory params = ISwapRouter
            .ExactOutputSingleParams({
                tokenIn: USDC_ADDRESS,
                tokenOut: WETH_ADDRESS,
                fee: poolFee,
                recipient: recipient,
                deadline: block.timestamp,
                amountOut: collateralAmount,
                amountInMaximum: amountInMaximum,
                sqrtPriceLimitX96: 0
            });

        // The call to `exactInputSingle` executes the swap.
        uint256 amountIn = swapRouter.exactOutputSingle(params);
        emit log_named_uint("amountIn", amountIn);

        // Check the recipient balance
        IERC20 weth = IERC20(WETH_ADDRESS);
        uint256 recipientBalance = weth.balanceOf(recipient);
        emit log_named_uint("recipientBalance", recipientBalance);

        // uint256 gasUsage = gas - gasleft();
        // emit log_named_uint("gasUsage", gasUsage);

        // Uncomment below to see log above
        // assertTrue(false); // Set failed to show the emitted event
    }

    // getPriceBump returns 0.9% of amount, we use the price bump to prevent
    // swap transaction failed when there is slight price movement
    function getPriceBump(uint256 amount) internal pure returns (uint256 bump) {
        return (0.009 ether * amount) / 1 ether;
    }

    function getChainlinkPriceInGwei(address feed)
        internal
        view
        returns (uint256 feedPriceInGwei)
    {
        // Get latest price
        (, int256 price, , , ) = IChainlinkAggregatorV3(feed).latestRoundData();

        // Get decimals representation
        uint8 decimals = IChainlinkAggregatorV3(feed).decimals();

        // Scaleup or scaledown the decimals
        if (decimals != 9) {
            feedPriceInGwei = (uint256(price) * 1 gwei) / 10**decimals;
        } else {
            feedPriceInGwei = uint256(price);
        }
    }
}
