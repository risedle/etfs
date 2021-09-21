// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.7;
pragma experimental ABIEncoderV2;

import "lib/ds-test/src/test.sol";

import "../RisedleSupply.sol";

/// @notice Test for RisedleSupply contract
contract RisedleSupplyTest is DSTest {
    /// @notice Make sure all properties is set correctly
    function test_RisedleSupplyProperties() public {
        // Set the properties
        string memory name = "ETHRISE USDT Supply";
        string memory symbol = "rsETHRISE";
        address usdtAddress = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
        address borrowerAddress = address(this); // Set this contract as borrower

        // Create new Risedle supply
        RisedleSupply rs = new RisedleSupply(
            name,
            symbol,
            usdtAddress,
            borrowerAddress
        );

        // Make sure it's properly set
        assertEq(rs.name(), name);
        assertEq(rs.symbol(), symbol);
        assertEq(rs.decimals(), 8); // similar to cToken
        assertEq(rs.underlying(), usdtAddress);
        assertEq(rs.borrower(), borrowerAddress);
    }

    /// @notice Make sure it fails when the underlying asset is non ERC20
    function testFail_RisedleSupplyUnderlyingNonERC20() public {
        // Set the properties
        string memory name = "ETHRISE USDT Supply";
        string memory symbol = "rsETHRISE";
        address borrowerAddress = address(this); // Set this contract as borrower

        // Make sure it's fail when the underlying is set to non ERC20
        new RisedleSupply(name, symbol, borrowerAddress, borrowerAddress);
    }
}
