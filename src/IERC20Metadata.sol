// SPDX-License-Identifier: GPL-3.0-or-later

// Extends the IERC20 from OpenZeppelin
// This not available on v3.x

pragma solidity ^0.7.6;
pragma experimental ABIEncoderV2;

import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

/// @notice Extends OpenZeppelin interface
interface IERC20Metadata is IERC20 {
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);
}
