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

pragma solidity ^0.7.6;
pragma experimental ABIEncoderV2;

address constant USDC_ADDRESS = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
uint256 constant USDC_SLOT = 9;
address constant USDT_ADDRESS = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
uint256 constant USDT_SLOT = 2;
address constant WETH_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
uint256 constant WETH_SLOT = 3;
