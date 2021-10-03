// SPDX-License-Identifier: GPL-3.0-or-later

// Risedle's ETF Internal Test
// Test & validate all internal functionalities

pragma solidity ^0.7.6;
pragma experimental ABIEncoderV2;

import "lib/ds-test/src/test.sol";
import {IERC20Metadata} from "../IERC20Metadata.sol";

// chain/* is replaced by DAPP_REMAPPINGS at compile time,
// this allow us to use custom address on specific chain
// See .dapprc
import {WETH_ADDRESS, USDC_ADDRESS} from "chain/Constants.sol";

import {Hevm} from "./Hevm.sol";
import {RisedleVault} from "../RisedleVault.sol";
import {RisedleETF} from "../RisedleETF.sol";

// Set Risedle ETF's properties
string constant etfTokenName = "ETH 2x Leverage Risedle";
string constant etfTokenSymbol = "ETHRISE";
address constant wethAddress = WETH_ADDRESS;
uint256 constant etfInitialPrice = 100 * 1e6; // 100 USDC

// Set Risedle's Vault properties
string constant vaultTokenName = "Risedle USDC Vault";
string constant vaultTokenSymbol = "rvUSDC";
address constant vaultUnderlyingAddress = USDC_ADDRESS;

contract RisedleETFInternalTest is
    DSTest,
    RisedleETF(etfTokenName, etfTokenSymbol, wethAddress, etfInitialPrice)
{
    // hevm utils to alter mainnet state
    Hevm hevm;

    RisedleVault etfVault;

    function setUp() public {
        // Initialize HEVM
        hevm = new Hevm();

        // Create new Risedle Vault
        etfVault = new RisedleVault(
            vaultTokenName,
            vaultTokenSymbol,
            vaultUnderlyingAddress
        );

        // Set the vault
        setVault(address(etfVault));
    }

    /// @notice Make sure all important states are correctly set after deployment
    function test_ETFProperties() public {
        // Make sure underlying asset is correct
        assertEq(underlying, wethAddress);

        // Make sure the vault address is correct
        assertEq(vault, address(etfVault));

        // Make sure the vault added variable is set to true
        assertTrue(vaultAdded);

        // Make sure the initial price is correct
        assertEq(INITIAL_ETF_PRICE, etfInitialPrice);

        // Make sure the fee is correct
        assertEq(FEE_IN_ETHER, 0.001 ether); // 0.1%

        // Make sure the total pending fees is zero
        assertEq(totalPendingCreationFees, 0);
        assertEq(totalPendingRedemptionFees, 0);

        // Make sure the ETF's token properties is correct
        IERC20Metadata etfTokenMetadata = IERC20Metadata(address(this));
        assertEq(etfTokenMetadata.name(), etfTokenName);
        assertEq(etfTokenMetadata.symbol(), etfTokenSymbol);
        assertEq(uint256(etfTokenMetadata.decimals()), 18); // Default decimals

        // Make sure the total supply is set to zero
        assertEq(totalSupply(), 0);
    }

    /// @notice Make sure the principal and fee amount is setup correctly
    function test_GetPrincipalAndFeeAmount() public {
        uint256 amount;
        uint256 principalAmount;
        uint256 feeAmount;

        // Test with normal number
        amount = 1 ether;
        (principalAmount, feeAmount) = getPrincipalAndFeeAmount(amount);
        assertEq(principalAmount, 0.999 ether);
        assertEq(feeAmount, 0.001 ether);

        // Test with very large number
        amount = 1000 * 1e12 * 1e18; // 1000 trillion WETH
        (principalAmount, feeAmount) = getPrincipalAndFeeAmount(amount);
        assertEq(principalAmount, 999 * 1e12 * 1e18);
        assertEq(feeAmount, 1 * 1e12 * 1e18);

        // Test with other than ether units, for example 1e6
        amount = 1000 * 1e12 * 1e6; // 1000 trillion WETH
        (principalAmount, feeAmount) = getPrincipalAndFeeAmount(amount);
        assertEq(principalAmount, 999 * 1e12 * 1e6);
        assertEq(feeAmount, 1 * 1e12 * 1e6);
    }
}
