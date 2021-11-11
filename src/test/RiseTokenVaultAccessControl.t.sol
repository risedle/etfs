// SPDX-License-Identifier: GPL-3.0-or-later

// Rise Token Vault Access control test
// Make sure the ownership is working as expected
pragma solidity 0.8.9;
pragma experimental ABIEncoderV2;

import "lib/ds-test/src/test.sol";
import { IERC20Metadata } from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { Hevm } from "./Hevm.sol";
import { RiseTokenVault } from "../RiseTokenVault.sol";
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
        vault.create("ETH 2x Leverage Risedle", "ETHRISE", WETH_ADDRESS, CHAINLINK_ETH_USD, uniswapV3Swapper, 100 * 1e6, 0.001 ether);
    }

    /// @notice Make sure owner can create new RISE token
    function test_OwnerCanCreateNewRiseToken() public {
        // Create new vault; by default the deployer is the owner
        RiseTokenVault vault = new RiseTokenVault("Risedle USDC Vault", "rvUSDC", USDC_ADDRESS);

        // Create dummy swapper address
        address uniswapV3Swapper = hevm.addr(2);

        // Create new RISE token as owner
        address riseToken = vault.create(
            "ETH 2x Leverage Risedle",
            "ETHRISE",
            WETH_ADDRESS,
            CHAINLINK_ETH_USD,
            uniswapV3Swapper,
            100 * 1e6, // 100 USDC
            0.001 ether // 0.1%
        );

        // Validate the ERC20 of the RISE token
        assertEq(IERC20Metadata(riseToken).name(), "ETH 2x Leverage Risedle");
        assertEq(IERC20Metadata(riseToken).symbol(), "ETHRISE");
        assertEq(IERC20Metadata(riseToken).decimals(), IERC20Metadata(WETH_ADDRESS).decimals());

        // Validate the metadata of the RISE token
        RiseTokenVault.RiseTokenMetadata memory riseTokenMetadata = vault.getMetadata(riseToken);
        assertEq(riseTokenMetadata.token, riseToken);
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
        address riseToken = vault.create(
            "ETH 2x Leverage Risedle",
            "ETHRISE",
            WETH_ADDRESS,
            CHAINLINK_ETH_USD,
            uniswapV3Swapper,
            100 * 1e6, // 100 USDC
            0.001 ether // 0.1%
        );

        // Event the vault's owner cannot mint the RISE token
        address mintTo = hevm.addr(2);
        IRisedleERC20(riseToken).mint(mintTo, 1 ether); // Should be failed
    }

    /// @notice Make sure only vault can burn the RISE token
    function testFail_NonRiseTokenVaultCannotBurnRiseToken() public {
        // Create new vault; by default the deployer is the owner
        RiseTokenVault vault = new RiseTokenVault("Risedle USDC Vault", "rvUSDC", USDC_ADDRESS);

        // Create dummy swapper address
        address uniswapV3Swapper = hevm.addr(1);

        // Create new RISE token as owner
        address riseToken = vault.create(
            "ETH 2x Leverage Risedle",
            "ETHRISE",
            WETH_ADDRESS,
            CHAINLINK_ETH_USD,
            uniswapV3Swapper,
            100 * 1e6, // 100 USDC
            0.001 ether // 0.1%
        );

        // Event the vault's owner cannot burn the RISE token
        address burnFrom = hevm.addr(2);
        IRisedleERC20(riseToken).burn(burnFrom, 1 ether); // Should be failed
    }
}
