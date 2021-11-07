// SPDX-License-Identifier: GPL-3.0-or-later

// Risedle's Vault Access Control Test
// Make sure the ownership is working as expected

pragma solidity 0.8.9;
pragma experimental ABIEncoderV2;

import "lib/ds-test/src/test.sol";

import {RisedleMarket} from "../RisedleMarket.sol";
import {Hevm} from "./Hevm.sol";
import {USDC_ADDRESS, CHAINLINK_USDC_USD} from "chain/Constants.sol";
import {IRisedleERC20} from "../tokens/RisedleERC20.sol";

/// @notice To simulate actions performed by other accounts
contract RisedleNonMarket {
    address private _vaultToken;

    constructor(address vaultToken) {
        _vaultToken = vaultToken;
    }

    function mint(address to, uint256 amount) external {
        IRisedleERC20(_vaultToken).mint(to, amount);
    }
}

contract RisedleMarketAccessControl is DSTest {
    Hevm hevm;

    /// @notice Run the test setup
    function setUp() public {
        hevm = new Hevm();
    }

    /// @notice Make sure the owner is properly set
    function test_OwnerIsProperlySet() public {
        // Create new market
        RisedleMarket market = new RisedleMarket();

        // The governance is the one who create/deploy the vault
        assertEq(market.owner(), address(this));
    }

    /// @notice Make sure non-owner cannot create new vault
    function testFail_NonOwnerCannnotCreateNewVault() public {
        // Create new market; by default the deployer is the owner
        RisedleMarket market = new RisedleMarket();

        // Transfer the ownership to the random owner
        address newOwner = hevm.addr(1);
        market.transferOwnership(newOwner);

        // Try to create new vault as non-owner; this should be failed
        market.createNewVault(
            "Risedle USDC Vault",
            "rvUSDC",
            USDC_ADDRESS,
            CHAINLINK_USDC_USD,
            hevm.addr(2),
            hevm.addr(3)
        );
    }

    /// @notice Make sure owner can create new vault
    function test_OwnerCanCreateNewVault() public {
        // Create new market; by default the deployer is the owner
        RisedleMarket market = new RisedleMarket();

        // Vault's fee recipient
        address feeRecipient = hevm.addr(1);

        // Vault's implementation
        address vaultImplementation = hevm.addr(2);

        // Create new vault
        address vaultTokenAddress = market.createNewVault(
            "Risedle USDC Vault",
            "rvUSDC",
            USDC_ADDRESS,
            CHAINLINK_USDC_USD,
            feeRecipient,
            vaultImplementation
        );

        // Validate the information
        RisedleMarket.VaultMetadata memory vaultMetadata = market.getVault(
            vaultTokenAddress
        );
        assertEq(vaultMetadata.token, vaultTokenAddress);
        assertEq(vaultMetadata.underlying, USDC_ADDRESS);
        assertEq(vaultMetadata.feed, CHAINLINK_USDC_USD);
        assertEq(vaultMetadata.feeRecipient, feeRecipient);
        assertEq(vaultMetadata.implementation, vaultImplementation);
    }

    /// @notice Make sure only the market can mint the vault token
    function testFail_NonMarketCannotMintVaultToken() public {
        // Create new market; by default the deployer is the owner
        RisedleMarket market = new RisedleMarket();

        // Vault's fee recipient
        address feeRecipient = hevm.addr(1);

        // Vault's implementation
        address vaultImplementation = hevm.addr(2);

        // Create new vault
        address vaultTokenAddress = market.createNewVault(
            "Risedle USDC Vault",
            "rvUSDC",
            USDC_ADDRESS,
            CHAINLINK_USDC_USD,
            feeRecipient,
            vaultImplementation
        );

        // Create new non-market actor
        RisedleNonMarket nonMarket = new RisedleNonMarket(vaultTokenAddress);

        // Non market trying to mint the vault token; it should be failed
        address to = hevm.addr(3);
        nonMarket.mint(to, 1 ether);
    }

    /// TODO: implement testFail_NonMarketCannotBurnVaultToken
}
