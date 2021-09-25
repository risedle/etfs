// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.7;
pragma experimental ABIEncoderV2;

import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

/// @notice Set Hevm interface, so we can use the cheat codes it in the test
/// @dev https://github.com/dapphub/dapptools/tree/master/src/hevm#cheat-codes
interface IHEVM {
    function addr(uint256 sk) external returns (address addr);

    function store(
        address c,
        bytes32 loc,
        bytes32 val
    ) external;

    function warp(uint256 x) external;
}

/// @notice We use this contract to interact with HEVM
contract HEVM {
    /// @notice Store the HEVM contract here
    IHEVM private immutable _hevm;
    IERC20 USDC;
    IERC20 USDT;

    constructor() {
        // Assign hevm contract
        // HEVM address https://github.com/dapphub/dapptools/tree/master/src/hevm#cheat-codes
        _hevm = IHEVM(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

        // Assign USDC contract in mainnet
        USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        USDT = IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    }

    /// @notice Returns dummy address given secret key
    function addr(uint256 sk) external returns (address) {
        return _hevm.addr(sk);
    }

    /// @notice Send USDC to specified address
    function sendUSDC(address recipientAddress, uint256 amount) external {
        // Get existing balance
        uint256 recipientBalance = USDC.balanceOf(recipientAddress);

        // Top up amount
        // We get the 9 number using slot20 npm package
        _hevm.store(
            address(USDC),
            keccak256(abi.encode(recipientAddress, uint256(9))),
            bytes32(amount + recipientBalance)
        );
    }

    /// @notice Send USDT to specified address
    function sendUSDT(address recipientAddress, uint256 amount) external {
        // Get existing balance
        uint256 recipientBalance = USDT.balanceOf(recipientAddress);

        // Top up amount
        // We get the 2 number using slot20 npm package
        _hevm.store(
            address(USDT),
            keccak256(abi.encode(recipientAddress, uint256(2))),
            bytes32(amount + recipientBalance)
        );
    }

    /// @notice Set USDT balance of specified address
    function setUSDTBalance(address account, uint256 amount) external {
        // We get the 2 number using slot20 npm package
        _hevm.store(
            address(USDT),
            keccak256(abi.encode(account, uint256(2))),
            bytes32(amount)
        );
    }

    /// @notice Set block.timestamp to x
    function warp(uint256 x) public {
        _hevm.warp(x);
    }
}
