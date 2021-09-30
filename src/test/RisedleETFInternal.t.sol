// SPDX-License-Identifier: GPL-3.0-or-later

// Risedle's ETF Internal Test
// Test & validate all internal functionalities

pragma solidity ^0.8.7;
pragma experimental ABIEncoderV2;

import "lib/ds-test/src/test.sol";
import {IERC20Metadata} from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

// chain/* is replaced by DAPP_REMAPPINGS at compile time,
// this allow us to use custom address on specific chain
// See .dapprc
import {WETH_ADDRESS, USDT_ADDRESS} from "chain/Constants.sol";

import {Hevm} from "./Hevm.sol";
import {RisedleVault} from "../RisedleVault.sol";
import {RisedleETF} from "../RisedleETF.sol";

// Set Risedle ETF's properties
string constant etfTokenName = "ETH 2x Leverage Risedle";
string constant etfTokenSymbol = "ETHRISE";
address constant wethAddress = WETH_ADDRESS;
address constant etfGovernor = 0xdAC17F958D2ee523a2206206994597C13D831ec7; // set random governor
address constant etfFeeReceiver = 0xdAC17F958D2ee523a2206206994597C13D831ec7; // random fee receiver
uint256 constant etfInitialPrice = 100 * 1e6; // 100 USDT

// Set Risedle's Vault properties
string constant vaultTokenName = "Risedle USDT Vault";
string constant vaultTokenSymbol = "rvUSDT";
address constant usdtAddress = USDT_ADDRESS;
address constant vaultGovernor = 0xdAC17F958D2ee523a2206206994597C13D831ec7; // set random governor
address constant vaultFeeReceiver = 0xdAC17F958D2ee523a2206206994597C13D831ec7; // random fee receiver

contract RisedleETFInternalTest is
    DSTest,
    RisedleETF(
        etfTokenName,
        etfTokenSymbol,
        wethAddress,
        etfGovernor,
        etfFeeReceiver,
        etfInitialPrice
    )
{
    /// @notice hevm utils to alter mainnet state
    Hevm hevm;

    RisedleVault etfVault;

    function setUp() public {
        // Initialize HEVM
        hevm = new Hevm();

        // Create new Risedle Vault
        etfVault = new RisedleVault(
            vaultTokenName,
            vaultTokenSymbol,
            usdtAddress,
            6,
            vaultGovernor,
            vaultFeeReceiver
        );

        // Set the vault
        setVault(address(etfVault));
    }

    /// @notice Make sure all important variables are correctly set after deployment
    function test_ETFProperties() public {
        // Make sure underlying asset is correct
        assertEq(underlying, wethAddress);

        // Make sure the governor address is correct
        assertEq(governor, etfGovernor);

        // Make sure the fee receiver is correct
        assertEq(feeReceiver, etfFeeReceiver);

        // Make sure the vault address is correct
        assertEq(vault, address(etfVault));

        // Make sure the initial price is correct
        assertEq(INITIAL_ETF_PRICE, etfInitialPrice);

        // Make sure the ETF's token properties is correct
        IERC20Metadata etfTokenMetadata = IERC20Metadata(address(this));
        assertEq(etfTokenMetadata.name(), etfTokenName);
        assertEq(etfTokenMetadata.symbol(), etfTokenSymbol);
        assertEq(etfTokenMetadata.decimals(), 18); // Default decimals

        // Make sure the total supply is set to zero
        assertEq(getTotalSupply(), 0);
    }
}
