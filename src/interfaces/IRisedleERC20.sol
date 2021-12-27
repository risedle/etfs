// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity >=0.8.9;
pragma experimental ABIEncoderV2;

interface IRisedleERC20 {
    function mint(address to, uint256 amount) external;

    function burn(address from, uint256 amount) external;
}
