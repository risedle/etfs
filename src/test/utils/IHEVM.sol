// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.7;
pragma experimental ABIEncoderV2;

/// @notice Set Hevm interface, so we can use the cheat codes it in the test
/// @dev https://github.com/dapphub/dapptools/tree/master/src/hevm#cheat-codes
interface HEVM {
    function addr(uint256 sk) external returns (address addr);

    function store(
        address c,
        bytes32 loc,
        bytes32 val
    ) external;
}
