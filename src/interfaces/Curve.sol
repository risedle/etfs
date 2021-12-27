// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity >=0.8.9;
pragma experimental ABIEncoderV2;

/// @notice Curve Address Provider interface
/// @dev https://curve.readthedocs.io/registry-address-provider.html
interface IAddressProvider {
    function get_registry() external view returns (address);

    function get_address(uint256 id) external view returns (address);
}

/// @notice Curve Swaps Interface
interface ISwap {
    function exchange(
        address pool,
        address from,
        address to,
        uint256 amount,
        uint256 expected,
        address receiver
    ) external returns (uint256 receivedAmount);

    function get_best_rate(
        address from,
        address to,
        uint256 amount,
        address[8] memory exclude_pools
    ) external view returns (address pool, uint256 expected);
}

/// @notice Curve Registry interface
interface IRegistry {
    function find_pool_for_coins(
        address from,
        address to,
        uint256 i
    ) external view returns (address pool);
}
