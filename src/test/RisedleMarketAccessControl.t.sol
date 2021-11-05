// SPDX-License-Identifier: GPL-3.0-or-later

// Risedle's Vault Access Control Test
// Make sure the Governance ownership is working as expected

pragma solidity 0.8.9;
pragma experimental ABIEncoderV2;

import "lib/ds-test/src/test.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

// chain/* is replaced by DAPP_REMAPPINGS at compile time,
// this allow us to use custom address on specific chain
// See .dapprc
import {USDC_ADDRESS, WETH_ADDRESS, CHAINLINK_ETH_USD, CHAINLINK_USDC_USD, UNISWAPV3_SWAP_ROUTER} from "chain/Constants.sol";

import {Hevm} from "./Hevm.sol";
import {RisedleMarket} from "../RisedleMarket.sol";

/// @notice Dummy contract to simulate random account to execute collect fee
contract FeeCollector {
    RisedleMarket market;

    constructor(RisedleMarket market_) {
        market = market_;
    }

    function collectPendingFees() public {
        market.collectPendingFees();
    }
}

contract RisedleMarketAccessControlTest is DSTest {
    // Test utils
    IERC20 constant USDC = IERC20(USDC_ADDRESS);
    Hevm hevm;

    /// @notice Run the test setup
    function setUp() public {
        hevm = new Hevm();
    }

    /// @notice Utility function to create new Risedle Market
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

    /// @notice Make sure the governance is properly set
    function test_GovernanceIsProperlySet() public {
        // Create new market
        RisedleMarket market = createNewMarket();

        // The governance is the one who create/deploy the vault
        assertEq(market.owner(), address(this));
    }

    /// @notice Make sure non-governance account cannot set vault parameters
    function testFail_NonGovernanceCannotSetVaultParameters() public {
        address governance = hevm.addr(2); // Use random address as governance
        RisedleMarket market = createNewMarket();
        market.transferOwnership(governance);

        // Make sure this is fail
        market.setVaultParameters(
            0.1 ether,
            0.2 ether,
            0.3 ether,
            0.4 ether,
            0.1 ether
        );
    }

    /// @notice Make sure governance can update the vault parameters
    function test_GovernanceCanSetVaultParameters() public {
        // This contract is the governance by default
        RisedleMarket market = createNewMarket();

        // Update vault's parameters
        uint256 optimalUtilizationRate = 0.8 ether;
        uint256 slope1 = 0.4 ether;
        uint256 slope2 = 0.9 ether;
        uint256 maxBorrowRatePerSeconds = 0.7 ether;
        uint256 fee = 0.9 ether;
        market.setVaultParameters(
            optimalUtilizationRate,
            slope1,
            slope2,
            maxBorrowRatePerSeconds,
            fee
        );

        // Make sure the parameters is updated
        (uint256 u, uint256 s1, uint256 s2, uint256 mr, uint256 f) = market
            .getVaultParameters();

        assertEq(u, optimalUtilizationRate);
        assertEq(s1, slope1);
        assertEq(s2, slope2);
        assertEq(mr, maxBorrowRatePerSeconds);
        assertEq(f, fee);
    }

    /// @notice Make sure non-governance account cannot change the fee recipient
    function testFail_NonGovernanceCannotSetFeeRecipientAddress() public {
        // Set governance
        address governance = hevm.addr(2);
        RisedleMarket market = createNewMarket();
        market.transferOwnership(governance);

        // Make sure it fails
        market.setFeeRecipient(hevm.addr(3));
    }

    /// @notice Make sure governance can update the fee recipient
    function test_GovernanceCanSetFeeRecipientAddress() public {
        // Set the new fee recipient
        address newFeeRecipient = hevm.addr(2);

        // Create new market
        RisedleMarket market = createNewMarket();

        // Update the fee recipient
        market.setFeeRecipient(newFeeRecipient);

        // Make sure the fee recipient is updated
        assertEq(market.getFeeRecipient(), newFeeRecipient);
    }

    /// @notice Test accrue interest as public
    function test_AnyoneCanAccrueInterest() public {
        // Create new market
        address governance = hevm.addr(2);
        RisedleMarket market = createNewMarket();
        market.transferOwnership(governance);

        // Set the timestamp
        uint256 previousTimestamp = block.timestamp;
        hevm.warp(previousTimestamp);

        // Public accrue interest
        market.accrueInterest();

        // Make sure is not failed
        assertTrue(true);
    }

    /// @notice Only governance can create new ETF
    function testFail_NonGovernanceCannotCreateNewETF() public {
        // Create new market
        address governance = hevm.addr(2);
        RisedleMarket market = createNewMarket();
        market.transferOwnership(governance);

        // Make sure this action is failed
        market.createNewETF(
            hevm.addr(2),
            WETH_ADDRESS,
            CHAINLINK_ETH_USD,
            100 * 1e6,
            0.001 ether, // 0.1% creation and redemption fee,
            500 // Uniswap V3 pool fee
        );
    }

    /// @notice Governance can create new ETF
    function test_GovernanceCanCreateNewETF() public {
        // Create new market as governance
        RisedleMarket market = createNewMarket();

        // Create new ETF as governance
        uint256 initialPrice = 100 * 1e6; // 100 USDC
        address etfToken = hevm.addr(1); // Set random address
        uint256 feeInEther = 0.001 ether; // 0.1% creation and redemption fee
        market.createNewETF(
            etfToken,
            WETH_ADDRESS,
            CHAINLINK_ETH_USD,
            initialPrice,
            feeInEther,
            500 // Uniswap V3 pool fee
        );

        // Get the ETF info
        RisedleMarket.ETFInfo memory etfInfo = market.getETFInfo(etfToken);

        // Make sure the etfInfo is correct
        assertEq(etfInfo.token, etfToken);
        assertEq(etfInfo.collateral, WETH_ADDRESS);
        assertEq(etfInfo.collateralDecimals, 18);
        assertEq(etfInfo.feed, CHAINLINK_ETH_USD);
        assertEq(etfInfo.initialPrice, initialPrice);
        assertEq(etfInfo.feeInEther, feeInEther);
        assertEq(etfInfo.totalCollateral, 0);
        assertEq(etfInfo.totalPendingFees, 0);
        assertEq(etfInfo.uniswapV3PoolFee, 500);
    }
}
