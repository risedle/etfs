// SPDX-License-Identifier: GPL-3.0-or-later

// Rise Token Vault Internal Test
// Test & validate all Rise Token Vault internal functionalities

pragma solidity >=0.8.9;
pragma experimental ABIEncoderV2;

import "lib/ds-test/src/test.sol";

import { IERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { Hevm } from "./Hevm.sol";
import { RiseTokenVault } from "../RiseTokenVault.sol";
import { UniswapV3Swap } from "../swaps/UniswapV3Swap.sol";
import { ChainlinkOracle } from "../oracles/ChainlinkOracle.sol";
import { IRisedleOracle } from "../interfaces/IRisedleOracle.sol";

// chain/* is replaced by DAPP_REMAPPINGS at compile time, this allow us to use custom address on specific chain
// See .dapprc
import { USDC_ADDRESS, WETH_ADDRESS, UNISWAPV3_SWAP_ROUTER, CHAINLINK_USDC_USD, CHAINLINK_ETH_USD } from "chain/Constants.sol";

// Set Risedle's Vault properties
string constant tokenName = "Risedle USDC Vault";
string constant tokenSymbol = "rvUSDC";
address constant underlying = USDC_ADDRESS;
address constant feeRecipient = USDC_ADDRESS; // random address

contract RiseTokenVaultInternalTest is DSTest, RiseTokenVault(tokenName, tokenSymbol, underlying, feeRecipient) {
    /// @notice hevm utils to alter mainnet state
    Hevm hevm;

    function setUp() public {
        hevm = new Hevm();
    }

    /// @notice Make sure the collateral per RISE token is working as expected
    function test_CalculateCollateralPerRiseToken() public {
        uint256 collateralPerRiseToken;
        uint256 riseTokenTotalSupply;
        uint256 riseTokenTotalCollateral;
        uint256 riseTokenTotalPendingFees;
        uint8 riseTokenCollateralDecimals;

        // Initial state, collateral per RiseToken should be zero
        riseTokenTotalSupply = 0;
        riseTokenTotalCollateral = 0;
        riseTokenTotalPendingFees = 0;
        riseTokenCollateralDecimals = 18;
        collateralPerRiseToken = calculateCollateralPerRiseToken(riseTokenTotalSupply, riseTokenTotalCollateral, riseTokenTotalPendingFees, riseTokenCollateralDecimals);
        assertEq(collateralPerRiseToken, 0);

        // Set RiseToken states
        riseTokenTotalSupply = 10 ether;
        riseTokenTotalCollateral = 9 ether;
        riseTokenTotalPendingFees = 1 ether;
        riseTokenCollateralDecimals = 18;
        collateralPerRiseToken = calculateCollateralPerRiseToken(riseTokenTotalSupply, riseTokenTotalCollateral, riseTokenTotalPendingFees, riseTokenCollateralDecimals);
        assertEq(collateralPerRiseToken, 0.8 ether);

        // User very large number
        riseTokenTotalSupply = (10 * 1e12) * 1 ether;
        riseTokenTotalCollateral = (9 * 1e12) * 1 ether;
        riseTokenTotalPendingFees = (1 * 1e12) * 1 ether;
        riseTokenCollateralDecimals = 18;
        collateralPerRiseToken = calculateCollateralPerRiseToken(riseTokenTotalSupply, riseTokenTotalCollateral, riseTokenTotalPendingFees, riseTokenCollateralDecimals);
        assertEq(collateralPerRiseToken, 0.8 ether);
    }

    /// @notice Make sure it fails when totalPendingFees > totalCollateral
    function testFail_CalculateCollateralPerRiseTokenFeeTooLarge() public pure {
        // Test too large fees
        uint256 riseTokenTotalSupply = 10 ether;
        uint256 riseTokenTotalCollateral = 12 ether;
        uint256 riseTokenTotalPendingFees = 15 ether;
        uint8 riseTokenCollateralDecimals = 18;
        // This should be failed
        calculateCollateralPerRiseToken(riseTokenTotalSupply, riseTokenTotalCollateral, riseTokenTotalPendingFees, riseTokenCollateralDecimals);
    }

    // Utils to set the total debt of given RiseToken
    function setRiseTokenDebt(address riseToken, uint256 borrowAmount) internal {
        uint256 debtProportionRateInEther = getDebtProportionRateInEther();
        totalOutstandingDebt += borrowAmount;
        uint256 borrowProportion = (borrowAmount * 1 ether) / debtProportionRateInEther;
        totalDebtProportion += borrowProportion;
        debtProportion[riseToken] = debtProportion[riseToken] + borrowProportion;
    }

    /// @notice Make sure getDebtPerRiseToken is correct
    function test_CalculateDebtPerRiseToken() public {
        address riseToken;
        uint256 borrowAmount;
        uint256 riseTokenTotalSupply;
        uint256 debtPerRiseToken;
        uint8 riseTokenCollateralDecimals = 18;

        // Initial state it should be zero
        riseToken = hevm.addr(1);
        borrowAmount = 0;
        setRiseTokenDebt(riseToken, borrowAmount);
        riseTokenTotalSupply = 0;
        debtPerRiseToken = calculateDebtPerRiseToken(riseToken, riseTokenTotalSupply, riseTokenCollateralDecimals);
        assertEq(debtPerRiseToken, 0);

        // Create new Risedle RiseToken token
        riseToken = hevm.addr(2);
        borrowAmount = 1000 * 1e6; // 1K USDC
        setRiseTokenDebt(riseToken, borrowAmount);
        riseTokenTotalSupply = 10 ether;
        debtPerRiseToken = calculateDebtPerRiseToken(riseToken, riseTokenTotalSupply, riseTokenCollateralDecimals);
        assertEq(debtPerRiseToken, 100 * 1e6); // 100 USDC per RiseToken

        // Let's simulate other RiseToken borrow once again
        riseToken = hevm.addr(3);
        borrowAmount = 2000 * 1e6; // 2K USDC
        setRiseTokenDebt(riseToken, borrowAmount);
        riseTokenTotalSupply = 10 ether;
        debtPerRiseToken = calculateDebtPerRiseToken(riseToken, riseTokenTotalSupply, riseTokenCollateralDecimals);
        assertEq(debtPerRiseToken, 200 * 1e6); // 200 USDC per RiseToken
    }

    /// @notice Make sure the NAV calculation is correct
    function test_CalculateNAV() public {
        uint256 riseTokenNAV;
        uint256 collateralPerRiseToken;
        uint256 debtPerRiseToken;
        uint256 collateralPrice;
        uint256 riseTokenInitialPrice = 100 * 1e6; // 100 USDC
        uint8 riseTokenCollateralDecimals = 18;

        // Initial state should be the initial price
        collateralPerRiseToken = 0;
        debtPerRiseToken = 0; // 1.2K USDC
        collateralPrice = 0; // 3.2K USDC
        riseTokenNAV = calculateNAV(collateralPerRiseToken, debtPerRiseToken, collateralPrice, riseTokenInitialPrice, riseTokenCollateralDecimals);
        assertEq(riseTokenNAV, riseTokenInitialPrice);

        // Set the collateralPerRiseToken and debtPerRiseToken
        collateralPerRiseToken = 0.9 ether;
        debtPerRiseToken = 1200 * 1e6; // 1.2K USDC
        collateralPrice = 3200 * 1e6; // 3.2K USDC
        riseTokenNAV = calculateNAV(collateralPerRiseToken, debtPerRiseToken, collateralPrice, riseTokenInitialPrice, riseTokenCollateralDecimals);
        assertEq(riseTokenNAV, 1680 * 1e6);
    }

    /// @notice Make sure the fee calculation is correct
    function test_GetCollateralAndFeeAmount() public {
        uint256 amount;
        uint256 feeInEther;
        uint256 outputCollateralAmount;
        uint256 outputFeeAmount;
        uint256 expectedCollateralAmount;
        uint256 expectedFeeAmount;

        amount = 50 ether;
        feeInEther = 0.001 ether; // 0.1%
        expectedCollateralAmount = 49.95 ether;
        expectedFeeAmount = 0.05 ether;
        (outputCollateralAmount, outputFeeAmount) = getCollateralAndFeeAmount(amount, feeInEther);
        assertEq(outputCollateralAmount, expectedCollateralAmount);
        assertEq(outputFeeAmount, expectedFeeAmount);

        // Test with very large number
        amount = (120 * 1e12) * 1 ether; // 120 trillion ether
        feeInEther = 0.001 ether; // 0.1%
        expectedCollateralAmount = (11988 * 1e10) * 1 ether;
        expectedFeeAmount = (12 * 1e10) * 1 ether;
        (outputCollateralAmount, outputFeeAmount) = getCollateralAndFeeAmount(amount, feeInEther);
        assertEq(outputCollateralAmount, expectedCollateralAmount);
        assertEq(outputFeeAmount, expectedFeeAmount);
    }

    /// @notice Make sure the getMintAmount is correct
    function test_GetMintAmount() public {
        uint256 nav;
        uint256 collateralAmount;
        uint256 collateralPrice;
        uint256 borrowAmount;
        uint256 mintedAmount;
        uint8 collateralDecimals = 18;

        // First scenario
        nav = 200 * 1e6; // 200 USDC
        collateralAmount = 1 ether; // 2 ether
        collateralPrice = 4000 * 1e6; // 4K USDC
        borrowAmount = collateralPrice;
        mintedAmount = getMintAmount(nav, collateralAmount, collateralPrice, borrowAmount, collateralDecimals);
        assertEq(mintedAmount, 20 ether);

        // Second scenario
        nav = 145 * 1e6; // 145 USDC
        collateralAmount = 1 ether; // 2 ether
        collateralPrice = 4000 * 1e6; // 4K USDC
        borrowAmount = collateralPrice;
        mintedAmount = getMintAmount(nav, collateralAmount, collateralPrice, borrowAmount, collateralDecimals);
        assertEq(mintedAmount, 27586206896551724137);
    }
}
