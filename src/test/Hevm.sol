// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.9;
pragma experimental ABIEncoderV2;

import "lib/ds-test/src/test.sol";

import { USDC_ADDRESS, USDC_SLOT, USDT_ADDRESS, USDT_SLOT, WETH_ADDRESS, WETH_SLOT, UNI_ADDRESS, UNI_SLOT, GOHM_ADDRESS, GOHM_SLOT } from "chain/Constants.sol";

/// @notice Set Hevm interface, so we can use the cheat codes it in the test
/// @dev https://github.com/dapphub/dapptools/tree/master/src/hevm#cheat-codes
interface IHevm {
    function addr(uint256 sk) external returns (address addr);

    function store(
        address c,
        bytes32 loc,
        bytes32 val
    ) external;

    function warp(uint256 x) external;
}

contract Hevm {
    IHevm hevm;

    constructor() {
        hevm = IHevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    }

    function addr(uint256 sk) external returns (address) {
        return hevm.addr(sk);
    }

    // Set the block.timestamp to x
    function warp(uint256 x) external {
        hevm.warp(x);
    }

    function setUSDCBalance(address account, uint256 amount) public {
        hevm.store(USDC_ADDRESS, keccak256(abi.encode(account, USDC_SLOT)), bytes32(amount));
    }

    function setUSDTBalance(address account, uint256 amount) public {
        hevm.store(USDT_ADDRESS, keccak256(abi.encode(account, USDT_SLOT)), bytes32(amount));
    }

    function setWETHBalance(address account, uint256 amount) public {
        hevm.store(WETH_ADDRESS, keccak256(abi.encode(account, WETH_SLOT)), bytes32(amount));
    }

    function setUNIBalance(address account, uint256 amount) public {
        hevm.store(UNI_ADDRESS, keccak256(abi.encode(account, UNI_SLOT)), bytes32(amount));
    }

    function setGOHMBalance(address account, uint256 amount) public {
        hevm.store(GOHM_ADDRESS, keccak256(abi.encode(account, GOHM_SLOT)), bytes32(amount));
    }
}
