// SPDX-License-Identifier: GPL-3.0-or-later

// List of ERC20 addresses in Ethereum Mainnet and their storage slot to modify
// the balance.
//
// This file will automatically replace "chains/Constants.sol" when the test is
// running using:
//
//    CHAIN="ethereum" make test
//
// It's configured by DAPP_REMAPPINGS inside the .dapprc
//
// File to find the slot location:
// https://gist.github.com/pyk/1fdb426e722dc711cc6ee6fc60e0563f

pragma solidity >=0.8.9;
pragma experimental ABIEncoderV2;

address constant USDC_ADDRESS = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
uint256 constant USDC_SLOT = 9;
address constant USDT_ADDRESS = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
uint256 constant USDT_SLOT = 2;
address constant WETH_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
uint256 constant WETH_SLOT = 3;
address constant UNI_ADDRESS = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984;
uint256 constant UNI_SLOT = 4;
address constant GOHM_ADDRESS = 0x0ab87046fBb341D058F17CBC4c1133F25a20a52f;
uint256 constant GOHM_SLOT = 0;

// Chainlink feeds
address constant CHAINLINK_ETH_USD = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
address constant CHAINLINK_BTC_USD = 0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c;
address constant CHAINLINK_USDC_USD = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6;
address constant CHAINLINK_USDT_USD = 0x3E7d1eAB13ad0104d2750B8863b489D65364e32D;

// Uniswap V3
address constant UNISWAPV3_SWAP_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
