// SPDX-License-Identifier: GPL-3.0-or-later

// Rise Token Vault Access control test
// Make sure the ownership is working as expected
pragma solidity 0.8.9;
pragma experimental ABIEncoderV2;

import "lib/ds-test/src/test.sol";
import { IERC20Metadata } from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { Hevm } from "./Hevm.sol";
import { RiseTokenVault } from "../RiseTokenVault.sol";
import { RisedleERC20 } from "../tokens/RisedleERC20.sol";
import { IRisedleERC20 } from "../interfaces/IRisedleERC20.sol";

import { USDC_ADDRESS, WETH_ADDRESS, CHAINLINK_USDC_USD, CHAINLINK_ETH_USD } from "chain/Constants.sol";

contract RiseTokenVaultAccessControlTest is DSTest {
    Hevm hevm;

    /// @notice Run the test setup
    function setUp() public {
        hevm = new Hevm();
    }

    /// @notice Make sure non-owner cannot create new RISE token
    function testFail_NonOwnerCannotCreateNewRiseToken() public {
        // Create new vault; by default the deployer is the owner
        RiseTokenVault vault = new RiseTokenVault("Risedle USDC Vault", "rvUSDC", USDC_ADDRESS);

        // Transfer the ownership
        address newOwner = hevm.addr(1);
        vault.transferOwnership(newOwner);

        // Create dummy swapper address
        address uniswapV3Swapper = hevm.addr(2);

        // Create new RISE token as non-owner; should be failed
        RisedleERC20 ethrise = new RisedleERC20("ETH 2x Long Risedle", "ETHRISE", address(vault), IERC20Metadata(WETH_ADDRESS).decimals());
        address riseTokenAddress = address(ethrise);
        vault.create(
            riseTokenAddress,
            WETH_ADDRESS,
            CHAINLINK_ETH_USD,
            uniswapV3Swapper,
            100 * 1e6, // 100 USDC
            0.001 ether, // creation and redemption fees is 0.1%
            2 ether, // Target leverage is 2x
            0.1 ether, // Daily rebalancing step is 0.1x
            250000 * 1e6 // Max value of sell/buy is 250K USDC
        );
    }

    /// @notice Make sure owner can create new RISE token
    function test_OwnerCanCreateNewRiseToken() public {
        // Create new vault; by default the deployer is the owner
        RiseTokenVault vault = new RiseTokenVault("Risedle USDC Vault", "rvUSDC", USDC_ADDRESS);

        // Create dummy swapper address
        address uniswapV3Swapper = hevm.addr(2);

        // Create new RISE token as owner
        RisedleERC20 ethrise = new RisedleERC20("ETH 2x Long Risedle", "ETHRISE", address(vault), IERC20Metadata(WETH_ADDRESS).decimals());
        address riseTokenAddress = address(ethrise);
        vault.create(
            riseTokenAddress,
            WETH_ADDRESS,
            CHAINLINK_ETH_USD,
            uniswapV3Swapper,
            100 * 1e6, // 100 USDC
            0.001 ether, // creation and redemption fees is 0.1%
            2 ether, // Target leverage is 2x
            0.1 ether, // Daily rebalancing step is 0.1x
            250000 * 1e6 // Max value of sell/buy is 250K USDC
        );

        // Validate the ERC20 of the RISE token
        assertEq(IERC20Metadata(riseTokenAddress).name(), "ETH 2x Leverage Risedle");
        assertEq(IERC20Metadata(riseTokenAddress).symbol(), "ETHRISE");
        assertEq(IERC20Metadata(riseTokenAddress).decimals(), IERC20Metadata(WETH_ADDRESS).decimals());

        // Validate the metadata of the RISE token
        RiseTokenVault.RiseTokenMetadata memory riseTokenMetadata = vault.getMetadata(riseTokenAddress);
        assertEq(riseTokenMetadata.token, riseTokenAddress);
        assertEq(riseTokenMetadata.collateral, WETH_ADDRESS);
        assertEq(riseTokenMetadata.oracle, CHAINLINK_ETH_USD);
        assertEq(riseTokenMetadata.swap, uniswapV3Swapper);
        assertEq(riseTokenMetadata.initialPrice, 100 * 1e6); // 100 USDC
        assertEq(riseTokenMetadata.feeInEther, 0.001 ether); // 0.1%
        assertEq(riseTokenMetadata.totalCollateral, 0);
        assertEq(riseTokenMetadata.totalPendingFees, 0);
    }

    /// @notice Make sure only vault can mint the RISE token
    function testFail_NonRiseTokenVaultCannotMintRiseToken() public {
        // Create new vault; by default the deployer is the owner
        RiseTokenVault vault = new RiseTokenVault("Risedle USDC Vault", "rvUSDC", USDC_ADDRESS);

        // Create dummy swapper address
        address uniswapV3Swapper = hevm.addr(1);

        // Create new RISE token as owner
        RisedleERC20 ethrise = new RisedleERC20("ETH 2x Long Risedle", "ETHRISE", address(vault), IERC20Metadata(WETH_ADDRESS).decimals());
        address riseTokenAddress = address(ethrise);
        vault.create(
            riseTokenAddress,
            WETH_ADDRESS,
            CHAINLINK_ETH_USD,
            uniswapV3Swapper,
            100 * 1e6, // 100 USDC
            0.001 ether, // creation and redemption fees is 0.1%
            2 ether, // Target leverage is 2x
            0.1 ether, // Daily rebalancing step is 0.1x
            250000 * 1e6 // Max value of sell/buy is 250K USDC
        );

        // Event the vault's owner cannot mint the RISE token
        address mintTo = hevm.addr(2);
        IRisedleERC20(riseTokenAddress).mint(mintTo, 1 ether); // Should be failed
    }

    /// @notice Make sure only vault can burn the RISE token
    function testFail_NonRiseTokenVaultCannotBurnRiseToken() public {
        // Create new vault; by default the deployer is the owner
        RiseTokenVault vault = new RiseTokenVault("Risedle USDC Vault", "rvUSDC", USDC_ADDRESS);

        // Create dummy swapper address
        address uniswapV3Swapper = hevm.addr(1);

        // Create new RISE token as owner

        // Create new ETHRISE token
        RisedleERC20 ethrise = new RisedleERC20("ETH 2x Long Risedle", "ETHRISE", address(vault), IERC20Metadata(WETH_ADDRESS).decimals());
        address riseTokenAddress = address(ethrise);
        vault.create(
            riseTokenAddress,
            WETH_ADDRESS,
            CHAINLINK_ETH_USD,
            uniswapV3Swapper,
            100 * 1e6, // 100 USDC
            0.001 ether, // creation and redemption fees is 0.1%
            2 ether, // Target leverage is 2x
            0.1 ether, // Daily rebalancing step is 0.1x
            250000 * 1e6 // Max value of sell/buy is 250K USDC
        );
        // Event the vault's owner cannot burn the RISE token
        address burnFrom = hevm.addr(2);
        IRisedleERC20(riseTokenAddress).burn(burnFrom, 1 ether); // Should be failed
    }
}
