// SPDX-License-Identifier: GPL-3.0-or-later

// Risedle's Vault External Test
// Test & validate user/contract interaction with Risedle's Vault

pragma solidity 0.8.9;
pragma experimental ABIEncoderV2;

import "lib/ds-test/src/test.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

// chain/* is replaced by DAPP_REMAPPINGS at compile time,
// this allow us to use custom address on specific chain
// See .dapprc
import {USDC_ADDRESS, CHAINLINK_USDC_USD, UNISWAPV3_SWAP_ROUTER, WETH_ADDRESS, CHAINLINK_ETH_USD} from "chain/Constants.sol";

import {Hevm} from "./Hevm.sol";
import {RisedleMarket} from "../RisedleMarket.sol";
import {RisedleETFToken} from "../RisedleETFToken.sol";

/// @notice Dummy contract to simulate the lender
contract Lender {
    using SafeERC20 for IERC20;

    // Vault
    RisedleMarket private _market;
    IERC20 underlying;

    constructor(RisedleMarket market) {
        _market = market;
        underlying = IERC20(market.vaultUnderlyingTokenAddress());
    }

    /// @notice lender supply asset
    function lend(uint256 amount) public {
        // approve market to spend the underlying asset
        underlying.safeApprove(address(_market), type(uint256).max);

        // Supply asset
        _market.addSupply(amount);
    }

    /// @notice lender remove asset
    function withdraw(uint256 amount) public {
        // approve market to spend the vault token
        _market.approve(address(_market), type(uint256).max);

        // Withdraw asset
        _market.removeSupply(amount);
    }
}

/// @notice Dummy contract to simulate investor
contract Investor {
    RisedleMarket private _market;

    constructor(RisedleMarket market) {
        _market = market;
    }

    function invest(
        address etf,
        address collateral,
        uint256 amount
    ) public {
        // approve market to spend the collateral token
        IERC20(collateral).approve(address(_market), type(uint256).max);

        // Mint new ETF token
        _market.invest(etf, amount);
    }

    function redeem(address etf, uint256 amount) public {
        // approve market to spend the etf token
        IERC20(etf).approve(address(_market), type(uint256).max);

        // Mint new ETF token
        _market.redeem(etf, amount);
    }
}

contract RisedleMarketExternalTest is DSTest {
    // Test utils
    IERC20 constant USDC = IERC20(USDC_ADDRESS);
    Hevm hevm;

    /// @notice Run the test setup
    function setUp() public {
        hevm = new Hevm();
    }

    /// @notice Utility function to create new market
    function createNewMarket() internal returns (RisedleMarket) {
        // Create new market
        RisedleMarket market = new RisedleMarket(
            "Risedle USDC Vault",
            "rvUSDC",
            USDC_ADDRESS,
            CHAINLINK_USDC_USD,
            6,
            UNISWAPV3_SWAP_ROUTER
        );
        return market;
    }

    /// @notice Make sure the lender can supply asset to the market
    function test_LenderCanAddSupplytToTheVault() public {
        // Create new market
        RisedleMarket market = createNewMarket();

        // Create new lender
        Lender lender = new Lender(market);

        // Set the lender USDC balance
        uint256 amount = 1000 * 1e6; // 1000 USDC
        hevm.setUSDCBalance(address(lender), amount);

        // Lender add supply to the market
        lender.lend(amount);

        // Lender should receive the same amount of market token
        uint256 lenderVaultTokenBalance = market.balanceOf(address(lender));
        assertEq(lenderVaultTokenBalance, amount);

        // The market should receive the USDC
        assertEq(USDC.balanceOf(address(market)), amount);
    }

    /// @notice Make sure the lender can remove asset from the market
    function test_LenderCanRemoveSupplyFromTheVault() public {
        // Create new market
        RisedleMarket market = createNewMarket();

        // Create new lender
        Lender lender = new Lender(market);

        // Set the lender USDC balance
        uint256 amount = 1000 * 1e6; // 1000 USDC
        hevm.setUSDCBalance(address(lender), amount);

        // Lender add supply to the market
        lender.lend(amount);

        // Make sure the market receive the asset
        assertEq(USDC.balanceOf(address(market)), amount);

        // Lender remove supply from the market
        lender.withdraw(amount);

        // Lender market token should be burned
        uint256 lenderVaultTokenBalance = market.balanceOf(address(lender));
        assertEq(lenderVaultTokenBalance, 0);

        // The lender should receive the USDC back
        assertEq(USDC.balanceOf(address(lender)), amount);

        // Not the market should have zero USDC
        assertEq(USDC.balanceOf(address(market)), 0);
    }

    /// @notice Make sure the investor can invest
    function test_InvestorCanMintETFToken() public {
        // Create new market
        RisedleMarket market = createNewMarket();

        // Create new lender
        Lender lender = new Lender(market);

        // Set the lender USDC balance
        uint256 amount = 10000 * 1e6; // 1000 USDC
        hevm.setUSDCBalance(address(lender), amount);

        // Lender add supply to the market
        lender.lend(amount);

        // Create new ETF token
        RisedleETFToken token = new RisedleETFToken(
            "ETH 2x Leverage Risedle",
            "ETHRISE",
            address(market), // set the market as the owner
            18
        );

        // Create new ETF
        market.createNewETF(
            address(token),
            WETH_ADDRESS,
            CHAINLINK_ETH_USD,
            100 * 1e6, // ETF initial price
            0.001 ether, // ETF creation and redemption fee 0.1%
            500 // Uniswap V3 Pool fee
        );

        // Create new investor
        Investor investor = new Investor(market);

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
        RisedleMarket.ETFInfo memory etfInfo = market.getETFInfo(
            address(token)
        );

        // Validate the ETF states
        assertEq(etfInfo.totalCollateral, expectedTotalCollateral);
        assertEq(etfInfo.totalPendingFees, expectedFeeAmount);

        // Make sure the debt is updated
        assertGt(market.getOutstandingDebt(address(token)), 1500 * 1e6); // Should more than 1500 USDC

        // Make sure the market receive the WETH
        uint256 marketWETHBalance = IERC20(WETH_ADDRESS).balanceOf(
            address(market)
        );
        assertEq(marketWETHBalance, expectedTotalCollateral);
    }

    /// @notice Make sure it fails when there is no supply
    function testFail_InvestorCannotMintETFTokenIfNoSupplyAvailable() public {
        // Create new market
        RisedleMarket market = createNewMarket();

        // Create new lender
        Lender lender = new Lender(market);

        // Set the lender USDC balance
        uint256 amount = 10 * 1e6; // 10 USDC
        hevm.setUSDCBalance(address(lender), amount);

        // Lender add supply to the market
        lender.lend(amount);

        // Create new ETF token
        RisedleETFToken token = new RisedleETFToken(
            "ETH 2x Leverage Risedle",
            "ETHRISE",
            address(market), // set the market as the owner
            18
        );

        // Create new ETF
        market.createNewETF(
            address(token),
            WETH_ADDRESS,
            CHAINLINK_ETH_USD,
            100 * 1e6, // ETF initial price
            0.001 ether, // ETF creation and redemption fee 0.1%
            500 // Uniswap V3 Pool fee
        );

        // Create new investor
        Investor investor = new Investor(market);

        // Set the investor WETH balance
        uint256 investAmount = 1.5 ether;
        hevm.setWETHBalance(address(investor), investAmount);

        // Invest to te ETF
        investor.invest(address(token), WETH_ADDRESS, investAmount); // This should be failed
    }

    /// @notice Make sure the investor can redeem the ETF token
    function test_InvestorCanRedeemETFToken() public {
        // Create new market
        RisedleMarket market = createNewMarket();

        // Create new lender
        Lender lender = new Lender(market);

        // Set the lender USDC balance
        uint256 amount = 10000 * 1e6; // 1000 USDC
        hevm.setUSDCBalance(address(lender), amount);

        // Lender add supply to the market
        lender.lend(amount);

        // Create new ETF token
        RisedleETFToken token = new RisedleETFToken(
            "ETH 2x Leverage Risedle",
            "ETHRISE",
            address(market), // set the market as the owner
            18
        );

        // Create new ETF
        market.createNewETF(
            address(token),
            WETH_ADDRESS,
            CHAINLINK_ETH_USD,
            100 * 1e6, // ETF initial price
            0.001 ether, // ETF creation and redemption fee 0.1%
            500 // Uniswap V3 Pool fee
        );

        // Create new investor
        Investor investor = new Investor(market);

        // Set the investor WETH balance and invest it to the protocol
        uint256 investAmount = 1.5 ether;
        hevm.setWETHBalance(address(investor), investAmount);
        investor.invest(address(token), WETH_ADDRESS, investAmount);

        // Get the etf token balance of the investor
        uint256 etfTokenBalance = token.balanceOf(address(investor));

        // Redeem the etf token
        investor.redeem(address(token), etfTokenBalance);

        // Make sure the investor receive the collateral back
        uint256 investorWETHBalance = IERC20(WETH_ADDRESS).balanceOf(
            address(investor)
        );
        assertGt(investorWETHBalance, 1.4 ether); // Should greater than 1.4 WETH

        // Make sure there is fee left to the market
        uint256 marketWETHBalance = IERC20(WETH_ADDRESS).balanceOf(
            address(market)
        );
        assertGt(marketWETHBalance, 0.0015 ether); // Greater than creation fee

        // Validate the ETF states
        RisedleMarket.ETFInfo memory etfInfo = market.getETFInfo(
            address(token)
        );
        assertGt(etfInfo.totalCollateral, 0.0015 ether); // Greater than creation fee
        assertGt(etfInfo.totalPendingFees, 0.0015 ether); // Greater than creation fee

        // Validate the borrow state
        assertGt(market.getOutstandingDebt(address(token)), 0); // It should be all repaid
    }

    /// @notice Make sure the investor can invest
    function test_InvestorMintTwice() public {
        // Create new market
        RisedleMarket market = createNewMarket();

        // Create new lender
        Lender lender = new Lender(market);

        // Set the lender USDC balance
        uint256 amount = 1 * 1e30;
        hevm.setUSDCBalance(address(lender), amount);

        // Lender add supply to the market
        lender.lend(amount);

        // Create new ETF token
        RisedleETFToken token = new RisedleETFToken(
            "ETH 2x Leverage Risedle",
            "ETHRISE",
            address(market), // set the market as the owner
            18
        );

        // Create new ETF
        market.createNewETF(
            address(token),
            WETH_ADDRESS,
            CHAINLINK_ETH_USD,
            100 * 1e6, // ETF initial price
            0.001 ether, // ETF creation and redemption fee 0.1%
            500 // Uniswap V3 Pool fee
        );

        // Create new investor
        Investor investor = new Investor(market);

        // Set the investor WETH balance
        uint256 investAmount = 1.5 ether;
        hevm.setWETHBalance(address(investor), investAmount);

        // Invest to te ETF
        investor.invest(address(token), WETH_ADDRESS, investAmount);

        hevm.setWETHBalance(address(investor), investAmount);
        investor.invest(address(token), WETH_ADDRESS, investAmount);
    }
}
