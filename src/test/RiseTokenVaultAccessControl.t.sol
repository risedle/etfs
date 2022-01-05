// SPDX-License-Identifier: GPL-3.0-or-later

// Rise Token Vault Access control test
// Make sure the ownership is working as expected
pragma solidity >=0.8.9;
pragma experimental ABIEncoderV2;

import "lib/ds-test/src/test.sol";
import { IERC20Metadata } from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { Hevm } from "./Hevm.sol";
import { RiseTokenVault } from "../RiseTokenVault.sol";
import { RisedleERC20 } from "../tokens/RisedleERC20.sol";
import { IRisedleERC20 } from "../interfaces/IRisedleERC20.sol";

import { USDC_ADDRESS, WETH_ADDRESS, CHAINLINK_USDC_USD, CHAINLINK_ETH_USD, UNI_ADDRESS } from "chain/Constants.sol";

contract RiseTokenVaultAccessControlTest is DSTest {
    Hevm hevm;

    /// @notice Run the test setup
    function setUp() public {
        hevm = new Hevm();
    }

    /// @notice Make sure non-owner cannot create new ETHRISE token
    function testFail_NonOwnerCannotCreateNewETHRISEToken() public {
        // Create new vault; by default the deployer is the owner
        RiseTokenVault vault = new RiseTokenVault("Risedle USDC Vault", "rvUSDC", USDC_ADDRESS, address(this));

        // Transfer the ownership
        address newOwner = hevm.addr(1);
        vault.transferOwnership(newOwner);

        // Create dummy swapper address
        address uniswapV3Swapper = hevm.addr(2);

        // Create new RISE token as non-owner; should be failed
        RisedleERC20 ethrise = new RisedleERC20("ETH 2x Long Risedle", "ETHRISE", address(vault), IERC20Metadata(WETH_ADDRESS).decimals());
        address riseTokenAddress = address(ethrise);
        vault.create(
            true,
            riseTokenAddress,
            WETH_ADDRESS,
            CHAINLINK_ETH_USD,
            uniswapV3Swapper,
            0.05 ether, // Max 5% slippage for mint, redeem and rebalance
            100 * 1e6, // Initial price 100 USDC
            0.001 ether, // creation and redemption fees is 0.1%
            1.7 ether, // Min leverage ratio is 1.7x
            2.3 ether, // Max leverage ratio is 2.3x
            250000 * 1e6, // Max value of sell/buy is 250K USDC
            0.2 ether // Rebalancing step is 0.2x
        );
    }

    /// @notice Make sure non-owner cannot create new ERC20RISE token
    function testFail_NonOwnerCannotCreateNewERC20RISEToken() public {
        // Create new vault; by default the deployer is the owner
        RiseTokenVault vault = new RiseTokenVault("Risedle USDC Vault", "rvUSDC", USDC_ADDRESS, address(this));

        // Transfer the ownership
        address newOwner = hevm.addr(1);
        vault.transferOwnership(newOwner);

        // Create dummy swapper address
        address uniswapV3Swapper = hevm.addr(2);

        // Create new ERC20RISE token as non-owner; should be failed
        RisedleERC20 unirise = new RisedleERC20("UNI Leverage Risedle", "UNIRISE", address(vault), IERC20Metadata(UNI_ADDRESS).decimals());
        vault.create(
            false,
            address(unirise),
            UNI_ADDRESS,
            CHAINLINK_ETH_USD, // For test only
            uniswapV3Swapper,
            0.05 ether, // Max 5% slippage for mint, redeem and rebalance
            100 * 1e6, // Initial price 100 USDC
            0.001 ether, // creation and redemption fees is 0.1%
            1.7 ether, // Min leverage ratio is 1.7x
            2.3 ether, // Max leverage ratio is 2.3x
            250000 * 1e6, // Max value of sell/buy is 250K USDC
            0.2 ether // Rebalancing step is 0.2x
        );
    }

    /// @notice Make sure owner can create new ETHRISE token
    function test_OwnerCanCreateNewETHRISEToken() public {
        // Create new vault; by default the deployer is the owner
        RiseTokenVault vault = new RiseTokenVault("Risedle USDC Vault", "rvUSDC", USDC_ADDRESS, address(this));

        // Create dummy contract
        address dummyOracleContract = hevm.addr(2);
        address dummySwapContract = hevm.addr(3);

        // Create new RISE token as owner
        RisedleERC20 ethrise = new RisedleERC20("ETH 2x Long Risedle", "ETHRISE", address(vault), IERC20Metadata(WETH_ADDRESS).decimals());
        address riseTokenAddress = address(ethrise);
        vault.create(
            true,
            riseTokenAddress,
            WETH_ADDRESS,
            dummyOracleContract,
            dummySwapContract,
            0.05 ether, // Max 5% slippage for mint, redeem and rebalance
            100 * 1e6, // Initial price 100 USDC
            0.001 ether, // creation and redemption fees is 0.1%
            1.7 ether, // Min leverage ratio is 1.7x
            2.3 ether, // Max leverage ratio is 2.3x
            500000 * 1e6, // Max value of sell/buy is 500K USDC
            0.2 ether // Rebalancing step is 0.2x
        );

        // Validate the ERC20 of the RISE token
        assertEq(IERC20Metadata(riseTokenAddress).name(), "ETH 2x Long Risedle");
        assertEq(IERC20Metadata(riseTokenAddress).symbol(), "ETHRISE");
        assertEq(IERC20Metadata(riseTokenAddress).decimals(), IERC20Metadata(WETH_ADDRESS).decimals());

        // Validate the metadata of the RISE token
        RiseTokenVault.RiseTokenMetadata memory riseTokenMetadata = vault.getMetadata(riseTokenAddress);
        assertEq(riseTokenMetadata.isETH, true);
        assertEq(riseTokenMetadata.token, riseTokenAddress);
        assertEq(riseTokenMetadata.collateral, WETH_ADDRESS);
        assertEq(riseTokenMetadata.oracleContract, dummyOracleContract);
        assertEq(riseTokenMetadata.swapContract, dummySwapContract);
        assertEq(riseTokenMetadata.maxSwapSlippageInEther, 0.05 ether); // max slippage is 5%
        assertEq(riseTokenMetadata.initialPrice, 100 * 1e6); // 100 USDC
        assertEq(riseTokenMetadata.feeInEther, 0.001 ether); // 0.1%
        assertEq(riseTokenMetadata.minLeverageRatioInEther, 1.7 ether);
        assertEq(riseTokenMetadata.maxLeverageRatioInEther, 2.3 ether);
        assertEq(riseTokenMetadata.maxRebalancingValue, 500000 * 1e6); // 500K USDC
        assertEq(riseTokenMetadata.rebalancingStepInEther, 0.2 ether); // Rebalancing step
        assertEq(riseTokenMetadata.totalCollateralPlusFee, 0);
        assertEq(riseTokenMetadata.totalPendingFees, 0);
    }

    /// @notice Make sure owner can create new ETHRISE token
    function test_OwnerCanCreateNewERC20RISEToken() public {
        // Create new vault; by default the deployer is the owner
        RiseTokenVault vault = new RiseTokenVault("Risedle USDC Vault", "rvUSDC", USDC_ADDRESS, address(this));

        // Create dummy contract
        address dummyOracleContract = hevm.addr(2);
        address dummySwapContract = hevm.addr(3);

        // Create new RISE token as owner
        RisedleERC20 unirise = new RisedleERC20("UNI 2x Long Risedle", "UNIRISE", address(vault), IERC20Metadata(UNI_ADDRESS).decimals());
        vault.create(
            false,
            address(unirise),
            UNI_ADDRESS,
            dummyOracleContract,
            dummySwapContract,
            0.05 ether, // Max 5% slippage for mint, redeem and rebalance
            100 * 1e6, // Initial price 100 USDC
            0.001 ether, // creation and redemption fees is 0.1%
            1.7 ether, // Min leverage ratio is 1.7x
            2.3 ether, // Max leverage ratio is 2.3x
            500000 * 1e6, // Max value of sell/buy is 500K USDC
            0.2 ether // Rebalancing step is 0.2x
        );

        // Validate the ERC20 of the RISE token
        assertEq(IERC20Metadata(address(unirise)).name(), "UNI 2x Long Risedle");
        assertEq(IERC20Metadata(address(unirise)).symbol(), "UNIRISE");
        assertEq(IERC20Metadata(address(unirise)).decimals(), IERC20Metadata(UNI_ADDRESS).decimals());

        // Validate the metadata of the RISE token
        RiseTokenVault.RiseTokenMetadata memory riseTokenMetadata = vault.getMetadata(address(unirise));
        assertEq(riseTokenMetadata.isETH, false);
        assertEq(riseTokenMetadata.token, address(unirise));
        assertEq(riseTokenMetadata.collateral, UNI_ADDRESS);
        assertEq(riseTokenMetadata.oracleContract, dummyOracleContract);
        assertEq(riseTokenMetadata.swapContract, dummySwapContract);
        assertEq(riseTokenMetadata.maxSwapSlippageInEther, 0.05 ether); // max slippage is 5%
        assertEq(riseTokenMetadata.initialPrice, 100 * 1e6); // 100 USDC
        assertEq(riseTokenMetadata.feeInEther, 0.001 ether); // 0.1%
        assertEq(riseTokenMetadata.minLeverageRatioInEther, 1.7 ether);
        assertEq(riseTokenMetadata.maxLeverageRatioInEther, 2.3 ether);
        assertEq(riseTokenMetadata.maxRebalancingValue, 500000 * 1e6); // 500K USDC
        assertEq(riseTokenMetadata.rebalancingStepInEther, 0.2 ether); // Rebalancing step
        assertEq(riseTokenMetadata.totalCollateralPlusFee, 0);
        assertEq(riseTokenMetadata.totalPendingFees, 0);
    }

    /// @notice Make sure only vault can mint the ETHRISE token
    function testFail_NonRiseTokenVaultCannotMintRISEToken() public {
        // Create new vault; by default the deployer is the owner
        RiseTokenVault vault = new RiseTokenVault("Risedle USDC Vault", "rvUSDC", USDC_ADDRESS, address(this));

        // Create new RISE token as owner
        RisedleERC20 ethrise = new RisedleERC20("ETH 2x Long Risedle", "ETHRISE", address(vault), IERC20Metadata(WETH_ADDRESS).decimals());

        // Event the vault's owner cannot mint the RISE token
        address mintTo = hevm.addr(2);
        IRisedleERC20(address(ethrise)).mint(mintTo, 1 ether); // Should be failed
    }

    /// @notice Make sure only vault can burn the RISE token
    function testFail_NonRiseTokenVaultCannotBurnRiseToken() public {
        // Create new vault; by default the deployer is the owner
        RiseTokenVault vault = new RiseTokenVault("Risedle USDC Vault", "rvUSDC", USDC_ADDRESS, address(this));

        // Create new ETHRISE token
        RisedleERC20 ethrise = new RisedleERC20("ETH 2x Long Risedle", "ETHRISE", address(vault), IERC20Metadata(WETH_ADDRESS).decimals());

        // Event the vault's owner cannot burn the RISE token
        address burnFrom = hevm.addr(2);
        IRisedleERC20(address(ethrise)).burn(burnFrom, 1 ether); // Should be failed
    }

    /// @notice Make sure non-owner cannot set max total collateral
    function testFail_NonOwnerCannotSetMaxTotalCollateral() public {
        // Create new vault; by default the deployer is the owner
        RiseTokenVault vault = new RiseTokenVault("Risedle USDC Vault", "rvUSDC", USDC_ADDRESS, address(this));

        // Create dummy contract
        address dummyOracleContract = hevm.addr(2);
        address dummySwapContract = hevm.addr(3);

        // Create new RISE token as owner
        RisedleERC20 unirise = new RisedleERC20("UNI 2x Long Risedle", "UNIRISE", address(vault), IERC20Metadata(UNI_ADDRESS).decimals());
        vault.create(
            false,
            address(unirise),
            UNI_ADDRESS,
            dummyOracleContract,
            dummySwapContract,
            0.05 ether, // Max 5% slippage for mint, redeem and rebalance
            100 * 1e6, // Initial price 100 USDC
            0.001 ether, // creation and redemption fees is 0.1%
            1.7 ether, // Min leverage ratio is 1.7x
            2.3 ether, // Max leverage ratio is 2.3x
            500000 * 1e6, // Max value of sell/buy is 500K USDC
            0.2 ether // Rebalancing step is 0.2x
        );

        // Transfer ownership
        address newOwner = hevm.addr(4);
        vault.transferOwnership(newOwner);

        // Try to set max collateral; this should be failed
        vault.setMaxTotalCollateral(address(unirise), 1_000_000 ether);
    }

    /// @notice Make sure owner can set max total Collateral
    function test_OwnerCanSetMaxTotalCollateral() public {
        // Create new vault; by default the deployer is the owner
        RiseTokenVault vault = new RiseTokenVault("Risedle USDC Vault", "rvUSDC", USDC_ADDRESS, address(this));

        // Create dummy contract
        address dummyOracleContract = hevm.addr(2);
        address dummySwapContract = hevm.addr(3);

        // Create new RISE token as owner
        RisedleERC20 unirise = new RisedleERC20("UNI 2x Long Risedle", "UNIRISE", address(vault), IERC20Metadata(UNI_ADDRESS).decimals());
        vault.create(
            false,
            address(unirise),
            UNI_ADDRESS,
            dummyOracleContract,
            dummySwapContract,
            0.05 ether, // Max 5% slippage for mint, redeem and rebalance
            100 * 1e6, // Initial price 100 USDC
            0.001 ether, // creation and redemption fees is 0.1%
            1.7 ether, // Min leverage ratio is 1.7x
            2.3 ether, // Max leverage ratio is 2.3x
            500000 * 1e6, // Max value of sell/buy is 500K USDC
            0.2 ether // Rebalancing step is 0.2x
        );

        // Set max collateral as owner
        vault.setMaxTotalCollateral(address(unirise), 1_000_000 ether);
        RiseTokenVault.RiseTokenMetadata memory riseTokenMetadata = vault.getMetadata(address(unirise));
        assertEq(riseTokenMetadata.maxTotalCollateral, 1_000_000 ether);
    }

    /// @notice Make sure non-owner cannot set the oracle contract
    function testFail_NonOwnerCannotSetOracleContract() public {
        // Create new vault; by default the deployer is the owner
        RiseTokenVault vault = new RiseTokenVault("Risedle USDC Vault", "rvUSDC", USDC_ADDRESS, address(this));

        // Create dummy contract
        address dummyOracleContract = hevm.addr(2);
        address dummySwapContract = hevm.addr(3);

        // Create new RISE token as owner
        RisedleERC20 unirise = new RisedleERC20("UNI 2x Long Risedle", "UNIRISE", address(vault), IERC20Metadata(UNI_ADDRESS).decimals());
        vault.create(
            false,
            address(unirise),
            UNI_ADDRESS,
            dummyOracleContract,
            dummySwapContract,
            0.05 ether, // Max 5% slippage for mint, redeem and rebalance
            100 * 1e6, // Initial price 100 USDC
            0.001 ether, // creation and redemption fees is 0.1%
            1.7 ether, // Min leverage ratio is 1.7x
            2.3 ether, // Max leverage ratio is 2.3x
            500000 * 1e6, // Max value of sell/buy is 500K USDC
            0.2 ether // Rebalancing step is 0.2x
        );

        // Transfer ownership
        address newOwner = hevm.addr(4);
        vault.transferOwnership(newOwner);

        // Try to set oracle contract; this should be failed
        address newOracleContract = hevm.addr(4);
        vault.setOracleContract(address(unirise), newOracleContract);
    }

    /// @notice Make sure owner can set the oracle contract
    function test_OwnerCanSetOracleContract() public {
        // Create new vault; by default the deployer is the owner
        RiseTokenVault vault = new RiseTokenVault("Risedle USDC Vault", "rvUSDC", USDC_ADDRESS, address(this));

        // Create dummy contract
        address dummyOracleContract = hevm.addr(2);
        address dummySwapContract = hevm.addr(3);

        // Create new RISE token as owner
        RisedleERC20 unirise = new RisedleERC20("UNI 2x Long Risedle", "UNIRISE", address(vault), IERC20Metadata(UNI_ADDRESS).decimals());
        vault.create(
            false,
            address(unirise),
            UNI_ADDRESS,
            dummyOracleContract,
            dummySwapContract,
            0.05 ether, // Max 5% slippage for mint, redeem and rebalance
            100 * 1e6, // Initial price 100 USDC
            0.001 ether, // creation and redemption fees is 0.1%
            1.7 ether, // Min leverage ratio is 1.7x
            2.3 ether, // Max leverage ratio is 2.3x
            500000 * 1e6, // Max value of sell/buy is 500K USDC
            0.2 ether // Rebalancing step is 0.2x
        );

        // Try to set oracle contract; this should be failed
        address newOracleContract = hevm.addr(4);
        vault.setOracleContract(address(unirise), newOracleContract);

        // Make sure the new oracle contract is set
        RiseTokenVault.RiseTokenMetadata memory riseTokenMetadata = vault.getMetadata(address(unirise));
        assertEq(riseTokenMetadata.oracleContract, newOracleContract);
    }

    /// @notice Make sure non-owner cannot set the swap contract
    function testFail_NonOwnerCannotSetSwapContract() public {
        // Create new vault; by default the deployer is the owner
        RiseTokenVault vault = new RiseTokenVault("Risedle USDC Vault", "rvUSDC", USDC_ADDRESS, address(this));

        // Create dummy contract
        address dummyOracleContract = hevm.addr(2);
        address dummySwapContract = hevm.addr(3);

        // Create new RISE token as owner
        RisedleERC20 unirise = new RisedleERC20("UNI 2x Long Risedle", "UNIRISE", address(vault), IERC20Metadata(UNI_ADDRESS).decimals());
        vault.create(
            false,
            address(unirise),
            UNI_ADDRESS,
            dummyOracleContract,
            dummySwapContract,
            0.05 ether, // Max 5% slippage for mint, redeem and rebalance
            100 * 1e6, // Initial price 100 USDC
            0.001 ether, // creation and redemption fees is 0.1%
            1.7 ether, // Min leverage ratio is 1.7x
            2.3 ether, // Max leverage ratio is 2.3x
            500000 * 1e6, // Max value of sell/buy is 500K USDC
            0.2 ether // Rebalancing step is 0.2x
        );

        // Transfer ownership
        address newOwner = hevm.addr(4);
        vault.transferOwnership(newOwner);

        // Try to set oracle contract; this should be failed
        address newSwapContract = hevm.addr(4);
        vault.setSwapContract(address(unirise), newSwapContract);
    }

    /// @notice Make sure owner can set the swap contract
    function test_OwnerCanSetSwapContract() public {
        // Create new vault; by default the deployer is the owner
        RiseTokenVault vault = new RiseTokenVault("Risedle USDC Vault", "rvUSDC", USDC_ADDRESS, address(this));

        // Create dummy contract
        address dummyOracleContract = hevm.addr(2);
        address dummySwapContract = hevm.addr(3);

        // Create new RISE token as owner
        RisedleERC20 unirise = new RisedleERC20("UNI 2x Long Risedle", "UNIRISE", address(vault), IERC20Metadata(UNI_ADDRESS).decimals());
        vault.create(
            false,
            address(unirise),
            UNI_ADDRESS,
            dummyOracleContract,
            dummySwapContract,
            0.05 ether, // Max 5% slippage for mint, redeem and rebalance
            100 * 1e6, // Initial price 100 USDC
            0.001 ether, // creation and redemption fees is 0.1%
            1.7 ether, // Min leverage ratio is 1.7x
            2.3 ether, // Max leverage ratio is 2.3x
            500000 * 1e6, // Max value of sell/buy is 500K USDC
            0.2 ether // Rebalancing step is 0.2x
        );

        // Try to set swap contract; this should be failed
        address newSwapContract = hevm.addr(4);
        vault.setSwapContract(address(unirise), newSwapContract);

        // Make sure the new swap contract is set
        RiseTokenVault.RiseTokenMetadata memory riseTokenMetadata = vault.getMetadata(address(unirise));
        assertEq(riseTokenMetadata.swapContract, newSwapContract);
    }
}
