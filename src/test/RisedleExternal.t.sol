// SPDX-License-Identifier: GPL-3.0-or-later

// Risedle's Vault External Test
// Test & validate user/contract interaction with Risedle's Vault

pragma solidity ^0.8.7;
pragma experimental ABIEncoderV2;

import "lib/ds-test/src/test.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

// chain/* is replaced by DAPP_REMAPPINGS at compile time,
// this allow us to use custom address on specific chain
// See .dapprc
import {USDC_ADDRESS, CHAINLINK_USDC_USD, UNISWAPV3_SWAP_ROUTER, WETH_ADDRESS, CHAINLINK_ETH_USD} from "chain/Constants.sol";

import {Hevm} from "./Hevm.sol";
import {Risedle} from "../Risedle.sol";
import {RisedleETFToken} from "../RisedleETFToken.sol";

/// @notice Dummy contract to simulate the lender
contract Lender {
    using SafeERC20 for IERC20;

    // Vault
    Risedle private _vault;
    IERC20 underlying;

    constructor(Risedle vault) {
        _vault = vault;
        underlying = IERC20(vault.supply());
    }

    /// @notice lender supply asset
    function lend(uint256 amount) public {
        // approve vault to spend the underlying asset
        underlying.safeApprove(address(_vault), type(uint256).max);

        // Supply asset
        _vault.mint(amount);
    }

    /// @notice lender remove asset
    function withdraw(uint256 amount) public {
        // approve vault to spend the vault token
        _vault.approve(address(_vault), type(uint256).max);

        // Withdraw asset
        _vault.burn(amount);
    }
}

/// @notice Dummy contract to simulate investor
contract Investor {
    Risedle private _vault;

    constructor(Risedle vault) {
        _vault = vault;
    }

    function invest(
        address etf,
        address collateral,
        uint256 amount
    ) public {
        // approve vault to spend the collateral token
        IERC20(WETH_ADDRESS).approve(address(_vault), type(uint256).max);

        // Mint new ETF token
        _vault.mint(etf, amount);
    }
}

contract RisedleExternalTest is DSTest {
    // Test utils
    IERC20 constant USDC = IERC20(USDC_ADDRESS);
    Hevm hevm;

    /// @notice Run the test setup
    function setUp() public {
        hevm = new Hevm();
    }

    /// @notice Utility function to create new vault
    function createNewVault() internal returns (Risedle) {
        // Create new vault
        Risedle vault = new Risedle(
            "Risedle USDC Vault",
            "rvUSDC",
            USDC_ADDRESS,
            CHAINLINK_USDC_USD,
            6,
            UNISWAPV3_SWAP_ROUTER
        );
        return vault;
    }

    /// @notice Make sure the lender can supply asset to the vault
    function test_LenderCanAddSupplytToTheVault() public {
        // Create new vault
        Risedle vault = createNewVault();

        // Create new lender
        Lender lender = new Lender(vault);

        // Set the lender USDC balance
        uint256 amount = 1000 * 1e6; // 1000 USDC
        hevm.setUSDCBalance(address(lender), amount);

        // Lender add supply to the vault
        lender.lend(amount);

        // Lender should receive the same amount of vault token
        uint256 lenderVaultTokenBalance = vault.balanceOf(address(lender));
        assertEq(lenderVaultTokenBalance, amount);

        // The vault should receive the USDC
        assertEq(USDC.balanceOf(address(vault)), amount);
    }

    /// @notice Make sure the lender can remove asset from the vault
    function test_LenderCanRemoveSupplyFromTheVault() public {
        // Create new vault
        Risedle vault = createNewVault();

        // Create new lender
        Lender lender = new Lender(vault);

        // Set the lender USDC balance
        uint256 amount = 1000 * 1e6; // 1000 USDC
        hevm.setUSDCBalance(address(lender), amount);

        // Lender add supply to the vault
        lender.lend(amount);

        // Make sure the vault receive the asset
        assertEq(USDC.balanceOf(address(vault)), amount);

        // Lender remove supply from the vault
        lender.withdraw(amount);

        // Lender vault token should be burned
        uint256 lenderVaultTokenBalance = vault.balanceOf(address(lender));
        assertEq(lenderVaultTokenBalance, 0);

        // The lender should receive the USDC back
        assertEq(USDC.balanceOf(address(lender)), amount);

        // Not the vault should have zero USDC
        assertEq(USDC.balanceOf(address(vault)), 0);
    }

    /// @notice Make sure the investor can invest
    function test_InvestorCanMintETFToken() public {
        // Create new vault
        Risedle vault = createNewVault();

        // Create new lender
        Lender lender = new Lender(vault);

        // Set the lender USDC balance
        uint256 amount = 10000 * 1e6; // 1000 USDC
        hevm.setUSDCBalance(address(lender), amount);

        // Lender add supply to the vault
        lender.lend(amount);

        // Create new ETF token
        RisedleETFToken token = new RisedleETFToken(
            "ETH 2x Leverage Risedle",
            "ETHRISE",
            address(vault), // set the vault as the owner
            18
        );

        // Create new ETF
        vault.createNewETF(
            address(token),
            WETH_ADDRESS,
            CHAINLINK_ETH_USD,
            100 * 1e6, // ETF initial price
            0.001 ether, // ETF creation and redemption fee 0.1%
            500 // Uniswap V3 Pool fee
        );

        // Create new investor
        Investor investor = new Investor(vault);

        // Set the investor WETH balance
        uint256 investAmount = 1.5 ether;
        hevm.setWETHBalance(address(investor), investAmount);

        // Invest to te ETF
        uint256 expectedCollateralAmount = 1.4985 ether;
        uint256 expectedFeeAmount = 0.0015 ether;
        uint256 expectedTotalCollateral = ((2 * expectedCollateralAmount) +
            expectedFeeAmount);
        investor.invest(address(token), WETH_ADDRESS, investAmount);

        // Make sure the investor get the etf token
        assertGt(token.balanceOf(address(investor)), 20 ether); // At least it should receive 20 ETHRISE @ $2000/ETH

        // Get the ETF info
        Risedle.ETFInfo memory etfInfo = vault.getETFInfo(address(token));

        // Validate the ETF states
        assertEq(etfInfo.totalCollateral, expectedTotalCollateral);
        assertEq(etfInfo.totalPendingFees, expectedFeeAmount);

        // Make sure the debt is updated
        assertGt(vault.getOutstandingDebt(address(token)), 1500 * 1e6); // Should more than 1500 USDC

        // Make sure the vault receive the WETH
        uint256 vaultWETHBalance = IERC20(WETH_ADDRESS).balanceOf(
            address(vault)
        );
        assertEq(vaultWETHBalance, expectedTotalCollateral);
    }

    /// @notice Make sure it fails when there is no supply
    function testFail_InvestorCannotMintETFTokenIfNoSupplyAvailable() public {
        // Create new vault
        Risedle vault = createNewVault();

        // Create new lender
        Lender lender = new Lender(vault);

        // Set the lender USDC balance
        uint256 amount = 10 * 1e6; // 10 USDC
        hevm.setUSDCBalance(address(lender), amount);

        // Lender add supply to the vault
        lender.lend(amount);

        // Create new ETF token
        RisedleETFToken token = new RisedleETFToken(
            "ETH 2x Leverage Risedle",
            "ETHRISE",
            address(vault), // set the vault as the owner
            18
        );

        // Create new ETF
        vault.createNewETF(
            address(token),
            WETH_ADDRESS,
            CHAINLINK_ETH_USD,
            100 * 1e6, // ETF initial price
            0.001 ether, // ETF creation and redemption fee 0.1%
            500 // Uniswap V3 Pool fee
        );

        // Create new investor
        Investor investor = new Investor(vault);

        // Set the investor WETH balance
        uint256 investAmount = 1.5 ether;
        hevm.setWETHBalance(address(investor), investAmount);

        // Invest to te ETF
        investor.invest(address(token), WETH_ADDRESS, investAmount); // This should be failed
    }
}
