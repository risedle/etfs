// SPDX-License-Identifier: GPL-3.0-or-later

// Risedle RISE Token Vault Contract
// TOKENRISE is 2x leverage long token.
//
// Copyright (c) 2021 Bayu - All rights reserved
// github: pyk
// email: bayu@risedle.com
pragma solidity 0.8.9;
pragma experimental ABIEncoderV2;

import { IERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20Metadata } from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { RisedleVault } from "./RisedleVault.sol";
import { RisedleERC20 } from "./tokens/RisedleERC20.sol";

import { IRisedleOracle } from "./interfaces/IRisedleOracle.sol";
import { IRisedleSwap } from "./interfaces/IRisedleSwap.sol";
import { IRisedleERC20 } from "./interfaces/IRisedleERC20.sol";

contract RiseTokenVault is RisedleVault {
    using SafeERC20 for IERC20;

    /// @notice RiseTokenMetadata contains the metadata of TOKENRISE
    struct RiseTokenMetadata {
        bool isETH; // True if the collateral is eth
        address token; // Address of ETF token ERC20, make sure this vault can mint & burn this token
        address collateral; // ETF underlying asset (e.g. WETH address)
        address oracleContract; // Contract address that implement IRisedleOracle interface
        address swapContract; // Contract address that implment IRisedleSwap interface
        uint256 maxSwapSlippageInEther; // Maximum swap slippage for mint, redeem and rebalancing (e.g. 1% is 0.01 ether or 0.01 * 1e18)
        uint256 initialPrice; // In term of vault's underlying asset (e.g. 100 USDC -> 100 * 1e6, coz is 6 decimals for USDC)
        uint256 feeInEther; // Creation and redemption fee in ether units (e.g. 0.1% is 0.001 ether)
        uint256 totalCollateral; // Total amount of underlying managed by this ETF
        uint256 totalPendingFees; // Total amount of creation and redemption pending fees in ETF underlying
        uint256 minLeverageRatioInEther; // Minimum leverage ratio in ether units (e.g. 2x is 2 ether = 2*1e18)
        uint256 maxLeverageRatioInEther; // Maximum leverage ratio  in ether units (e.g. 3x is 3 ether = 3*1e18)
        uint256 maxRebalancingValue; // The maximum value of buy/sell when rebalancing (e.g. 500K USDC is 500000 * 1e6)
        uint256 rebalancingStepInEther; // The rebalancing step in ether units (e.g. 0.2 is 0.2 ether or 0.2 * 1e18)
    }

    /// @notice Mapping TOKENRISE to their metadata
    mapping(address => RiseTokenMetadata) riseTokens;

    /// @notice Event emitted when new TOKENRISE is created
    event RiseTokenCreated(address indexed creator, address token);

    /// @notice Event emitted when TOKENRISE is minted
    event RiseTokenMinted(address indexed user, address indexed riseToken, uint256 mintedAmount);

    /// @notice Event emitted when TOKENRISE is successfully rebalanced
    event RiseTokenRebalanced(address indexed executor, uint256 previousLeverageRatioInEther);

    /**
     * @notice Construct new RiseTokenVault
     */
    constructor(
        string memory name, // The name of the vault's token (e.g. Risedle USDC Vault)
        string memory symbol, // The symbol of the vault's token (e.g rvUSDC)
        address underlying // The ERC20 address of the vault's underlying token (e.g. address of USDC token)
    ) RisedleVault(name, symbol, underlying) {}

    /**
     * @notice create creates new TOKENRISE
     * @dev Only admin can call this function
     */
    function create(
        bool isETH, // True if the collateral is ETH
        address tokenRiseAddress, // ERC20 token address that only RiseTokenVault can mint and burn
        address collateral, // The underlying token of TOKENRISE (e.g. WBTC), it's WETH if the isETH is true
        address oracleContract, // Contract address that implement IRisedleOracle interface
        address swapContract, // Uniswap V3 like token swapper
        uint256 maxSwapSlippageInEther, // Maximum slippage when mint, redeem and rebalancing (1% is 0.01 ether or 0.01*1e18)
        uint256 initialPrice, // Initial price of the TOKENRISE based on the Vault's underlying asset (e.g. 100 USDC => 100 * 1e6)
        uint256 feeInEther, // Creation and redemption fee in ether units (e.g. 0.001 ether = 0.1%)
        uint256 minLeverageRatioInEther, // Minimum leverage ratio in ether units (e.g. 2x is 2 ether = 2*1e18)
        uint256 maxLeverageRatioInEther, // Maximum leverage ratio  in ether units (e.g. 3x is 3 ether = 3*1e18)
        uint256 maxRebalancingValue, // The maximum value of buy/sell when rebalancing (e.g. 500K USDC is 500000 * 1e6)
        uint256 rebalancingStepInEther // The rebalancing step in ether units (e.g. 0.2 is 0.2 ether or 0.2 * 1e18)
    ) external onlyOwner {
        // Create new Rise metadata
        RiseTokenMetadata memory riseTokenMetadata = RiseTokenMetadata({
            isETH: isETH,
            token: tokenRiseAddress,
            collateral: collateral,
            oracleContract: oracleContract,
            swapContract: swapContract,
            maxSwapSlippageInEther: maxSwapSlippageInEther,
            initialPrice: initialPrice,
            feeInEther: feeInEther,
            minLeverageRatioInEther: minLeverageRatioInEther,
            maxLeverageRatioInEther: maxLeverageRatioInEther,
            maxRebalancingValue: maxRebalancingValue,
            rebalancingStepInEther: rebalancingStepInEther,
            totalCollateral: 0,
            totalPendingFees: 0
        });

        // Map new info to their token
        riseTokens[tokenRiseAddress] = riseTokenMetadata;

        // Emit event
        emit RiseTokenCreated(msg.sender, tokenRiseAddress);
    }

    /**
     * @notice getMetadata returns the metadata of the TOKENRISE
     * @param token The address of the TOKENRISE
     * @return The metadata of the TOKENRISE
     */
    function getMetadata(address token) external view returns (RiseTokenMetadata memory) {
        return riseTokens[token];
    }

    /**
     * @notice getCollateralPerRiseToken returns the collateral shares per TOKENRISE
     * @return collateralPerRiseToken The amount of collateral per TOKENRISE (e.g. 0.5 ETH is 0.5*1e18)
     */
    function getCollateralPerRiseToken(
        uint256 riseTokenSupply, // The total supply of the TOKENRISE
        uint256 totalCollateral, // The total collateral managed by the TOKENRISE
        uint256 totalPendingFees, // The total pending fees in the TOKENRISE
        uint8 collateralDecimals // The collateral decimals (e.g. ETH is 18 decimals)
    ) internal pure returns (uint256 collateralPerRiseToken) {
        if (riseTokenSupply == 0) return 0;

        // Get collateral per TOKENRISE
        collateralPerRiseToken = ((totalCollateral - totalPendingFees) * (10**collateralDecimals)) / riseTokenSupply;
    }

    /**
     * @notice getCollateralPerRiseToken returns the collateral shares per TOKENRISE
     * @return collateralPerRiseToken The amount of collateral per TOKENRISE (e.g. 0.5 ETH is 0.5*1e18)
     */
    function getCollateralPerRiseToken(address token) external view returns (uint256 collateralPerRiseToken) {
        // Make sure the TOKENRISE is exists
        RiseTokenMetadata memory riseTokenMetadata = riseTokens[token];
        if (riseTokenMetadata.feeInEther == 0) return 0;

        // Get collateral per TOKENRISE and debt per TOKENRISE
        uint256 riseTokenSupply = IERC20(riseTokenMetadata.token).totalSupply();
        uint8 collateralDecimals = IERC20Metadata(riseTokenMetadata.token).decimals();

        collateralPerRiseToken = getCollateralPerRiseToken(riseTokenSupply, riseTokenMetadata.totalCollateral, riseTokenMetadata.totalPendingFees, collateralDecimals);
    }

    /**
     * @notice getDebtPerRiseToken returns the debt shares per TOKENRISE
     * @return debtPerRiseToken The amount of debt per TOKENRISE (e.g. 80 USDC is 80*1e6)
     */
    function getDebtPerRiseToken(
        address token, // The address of TOKENRISE (ERC20)
        uint256 totalSupply, // The current total supply of the TOKENRISE
        uint8 collateralDecimals // The decimals of the collateral token (e.g. ETH have 18 decimals)
    ) internal view returns (uint256 debtPerRiseToken) {
        if (totalSupply == 0) return 0;

        // Get total TOKENRISE debt
        uint256 totalDebt = getOutstandingDebt(token);
        if (totalDebt == 0) return 0;

        // Get debt per TOKENRISE
        debtPerRiseToken = (totalDebt * (10**collateralDecimals)) / totalSupply;
    }

    /**
     * @notice getDebtPerRiseToken returns the debt shares per TOKENRISE
     * @return debtPerRiseToken The amount of debt per TOKENRISE (e.g. 80 USDC is 80*1e6)
     */
    function getDebtPerRiseToken(address token) external view returns (uint256 debtPerRiseToken) {
        // Make sure the TOKENRISE is exists
        RiseTokenMetadata memory riseTokenMetadata = riseTokens[token];
        if (riseTokenMetadata.feeInEther == 0) return 0;

        uint256 totalSupply = IERC20(riseTokenMetadata.token).totalSupply();
        uint8 collateralDecimals = IERC20Metadata(riseTokenMetadata.token).decimals();
        debtPerRiseToken = getDebtPerRiseToken(riseTokenMetadata.token, totalSupply, collateralDecimals);
    }

    /**
     * @notice calculateNAV calculates the net-asset value of the ETF
     * @return nav The NAV price of the TOKENRISE in term of vault underlying asset (e.g. 50 USDC is 50*1e6)
     */
    function calculateNAV(
        uint256 collateralPerRiseToken, // The amount of collateral per TOKENRISE (e.g 0.5 ETH is 0.5*1e18)
        uint256 debtPerRiseToken, // The amount of debt per TOKENRISE (e.g. 50 USDC is 50*1e6)
        uint256 collateralPrice, // The collateral price in term of supply asset (e.g 100 USDC is 100*1e6)
        uint256 etfInitialPrice, // The initial price of the ETF in terms od supply asset (e.g. 100 USDC is 100*1e6)
        uint8 collateralDecimals // The decimals of the collateral token
    ) internal pure returns (uint256 nav) {
        if (collateralPerRiseToken == 0 || debtPerRiseToken == 0) return etfInitialPrice;

        // Get the collateral value in term of the supply
        uint256 collateralValuePerRiseToken = (collateralPerRiseToken * collateralPrice) / (10**collateralDecimals);

        // Calculate the NAV
        nav = collateralValuePerRiseToken - debtPerRiseToken;
    }

    /**
     * @notice Get the net-asset value of the TOKENRISE
     * @param token The address of TOKENRISE
     * @return nav The NAV value of TOKENRISE in term of vault's underlying asset.
     * For example ETHRISE in USDC vault would be 200 * 1e6
     */
    function getNAV(address token) public view returns (uint256 nav) {
        // Make sure the TOKENRISE is exists
        RiseTokenMetadata memory riseTokenMetadata = riseTokens[token];
        if (riseTokenMetadata.feeInEther == 0) return 0;

        // Get the current price of the TOKENRISE collateral in term of vault's underlying token
        // For example WETH/USDC would trading around 4000 USDC (4000 * 1e6)
        uint256 collateralPrice = IRisedleOracle(riseTokenMetadata.oracleContract).getPrice();

        // Get collateral per TOKENRISE and debt per TOKENRISE
        uint256 totalSupply = IERC20(riseTokenMetadata.token).totalSupply();
        uint8 collateralDecimals = IERC20Metadata(riseTokenMetadata.token).decimals();
        uint256 collateralPerRiseToken = getCollateralPerRiseToken(totalSupply, riseTokenMetadata.totalCollateral, riseTokenMetadata.totalPendingFees, collateralDecimals);
        uint256 debtPerRiseToken = getDebtPerRiseToken(riseTokenMetadata.token, totalSupply, collateralDecimals);

        nav = calculateNAV(collateralPerRiseToken, debtPerRiseToken, collateralPrice, riseTokenMetadata.initialPrice, collateralDecimals);
    }

    /**
     * @notice getCollateralAndFeeAmount splits collateral and fee amount
     * @param amount The amount of TOKENRISE collateral deposited by the user
     * @param feeInEther The TOKENRISE creation and redemption fee in ether units (e.g. 0.001 ether = 0.1%)
     * @return collateralAmount The collateral amount
     * @return feeAmount The fee amount collected by the protocol
     */
    function getCollateralAndFeeAmount(uint256 amount, uint256 feeInEther) internal pure returns (uint256 collateralAmount, uint256 feeAmount) {
        feeAmount = (amount * feeInEther) / 1 ether;
        collateralAmount = amount - feeAmount;
    }

    /**
     * @notice borrowAndSwap borrow supply asset from the vault and buy more collateral
     * @return borrowAmount The amount of supply borrowed to 2x leverage the collateralAmount
     */
    function borrowAndSwap(
        address swapContract, // The address of swap contract
        address collateralToken, // The address of the collateral token
        uint256 collateralAmount, // The collateral amount
        uint256 collateralPrice, // The collateral price
        uint8 collateralDecimals // The collateral decimals
    ) internal returns (uint256 borrowAmount) {
        // Maximum plus +1% from the oracle price
        uint256 maximumCollateralPrice = collateralPrice + ((0.01 ether * collateralPrice) / 1 ether);

        // Get the collateral value
        uint256 maxSupplyOut = (collateralAmount * maximumCollateralPrice) / (10**collateralDecimals);

        // Make sure we do have enough vault's underlying available
        require(getTotalAvailableCash() > maxSupplyOut, "!NES");

        // Allow swap contract to spend the vault's underlying token
        IERC20(underlyingToken).safeApprove(swapContract, maxSupplyOut);

        // Buy more collateral using the Risedle Swap contract
        // We want to get exact amount of collateral with minimal vault's underlying as possible
        borrowAmount = IRisedleSwap(swapContract).swap(underlyingToken, collateralToken, maxSupplyOut, collateralAmount);

        // Reset the approval
        IERC20(underlyingToken).safeApprove(swapContract, 0);
    }

    /**
     * @notice getMintAmount returns the amount of TOKENRISE need to be minted
     * @return mintedAmount The amount of ETF token need to be minted
     */
    function getMintAmount(
        uint256 nav, // The net asset value of TOKENRISE (e.g. 200 USDC is 200 * 1e6)
        uint256 collateralAmount, // The amount of the collateral (e.g. 1 ETH is 1e18)
        uint256 collateralPrice, // The price of the collateral (e.g. 4000 USDC is 4000 * 1e6)
        uint256 borrowAmount, // The amount of borrow (e.g 200 USDC is 200 * 1e6)
        uint8 collateralDecimals // The decimals of the collateral token (e.g. ETH have 18 decimals)
    ) internal pure returns (uint256 mintedAmount) {
        // Calculate the total investment
        // totalInvestment = (2 x collateralValue) - borrowAmount
        uint256 totalInvestment = ((2 * collateralAmount * collateralPrice) / (10**collateralDecimals)) - borrowAmount;

        // Get minted amount
        mintedAmount = (totalInvestment * (10**collateralDecimals)) / nav;
    }

    /**
     * @notice Mint new TOKENRISE
     * @param token The address of TOKENRISE
     * @param amount The collateral amount
     */
    function mint(address token, uint256 amount) external payable nonReentrant {
        // Accrue interest
        accrueInterest();

        // Make sure the TOKENRISE is exists
        RiseTokenMetadata memory riseTokenMetadata = riseTokens[token];
        require(riseTokenMetadata.feeInEther > 0, "!RTNE");

        // Get the current net-asset value of the TOKENRISE in term of underlying
        // For example, If ETHRISE nav is 200 USDC, it will returns 200 * 1e6
        uint256 nav = getNAV(token);

        // Transfer the collateral to the vault
        if (riseTokenMetadata.isETH) {
            // Transfer eth from address to the contract
            require(msg.value == amount, "!ENE"); // Send it eth not equal to input amount

            // Wrapped it to the ETH using WETH contract
        } else {
            IERC20(riseTokenMetadata.collateral).safeTransferFrom(msg.sender, address(this), amount);
        }

        // Get the collateral and fee amount
        (uint256 collateralAmount, uint256 feeAmount) = getCollateralAndFeeAmount(amount, riseTokenMetadata.feeInEther);

        // Update the TOKENRISE metadata
        riseTokens[riseTokenMetadata.token].totalCollateral += ((2 * collateralAmount) + feeAmount);
        riseTokens[riseTokenMetadata.token].totalPendingFees += feeAmount;

        // Get the current price of collateral in term of vault underlying asset
        uint256 collateralPrice = IRisedleOracle(riseTokenMetadata.oracleContract).getPrice();

        // Get the borrow amount
        uint8 collateralDecimals = IERC20Metadata(riseTokenMetadata.collateral).decimals();
        uint256 borrowAmount = borrowAndSwap(riseTokenMetadata.swapContract, riseTokenMetadata.collateral, collateralAmount, collateralPrice, collateralDecimals);

        // Set TOKENRISE debt states
        setBorrowStates(token, borrowAmount);

        // Calculate minted amount
        uint256 mintedAmount = getMintAmount(nav, collateralAmount, collateralPrice, borrowAmount, collateralDecimals);

        // Transfer TOKENRISE to the caller
        IRisedleERC20(token).mint(msg.sender, mintedAmount);

        // Emit the event
        emit RiseTokenMinted(msg.sender, token, mintedAmount);
    }

    /**
     * @notice calculateLeverageRatio calculates leverage ratio
     * @return leverageRatioInEther leverage ratio in ether units (e.g. 2 is 2*1e18)
     */
    function calculateLeverageRatio(
        uint256 collateralPerRiseToken,
        uint256 debtPerRiseToken,
        uint256 collateralPrice,
        uint256 etfInitialPrice,
        uint8 collateralDecimals
    ) internal pure returns (uint256 leverageRatioInEther) {
        // Get the collateral value in term of the supply
        uint256 collateralValuePerRiseToken = (collateralPerRiseToken * collateralPrice) / (10**collateralDecimals);

        // Calculate the Net-Asset Value
        uint256 nav = calculateNAV(collateralPerRiseToken, debtPerRiseToken, collateralPrice, etfInitialPrice, collateralDecimals);

        // Calculate the leverage ratio in ether units
        leverageRatioInEther = (collateralValuePerRiseToken * 1 ether) / nav;
    }

    /**
     * @notice swap swaps the inputToken to outputToken
     * @return inputTokenSold The amount of input token sold to get the outputAmount
     */
    function swap(
        address swapContract, // The address of swap contract
        address inputToken, // The address of the token that we want to sell
        address outputToken, // The address of the output token that we want to buy
        uint256 maxInputAmount, // The maximum amount of input token that we want to sell
        uint256 outputAmount // The amount of output token that we want to buy
    ) internal returns (uint256 inputTokenSold) {
        // Allow swap contract to spend the input token from the contract
        IERC20(inputToken).safeApprove(swapContract, maxInputAmount);

        // Swap inputToken to outputToken
        inputTokenSold = IRisedleSwap(swapContract).swap(inputToken, outputToken, maxInputAmount, outputAmount);

        // Reset the approval
        IERC20(inputToken).safeApprove(swapContract, 0);
    }

    /**
     * @notice Run the rebalancing
     * @param token The TOKENRISE address
     */
    function rebalance(address token) external nonReentrant {
        // Accrue interest
        accrueInterest();

        // Make sure the TOKENRISE is exists
        RiseTokenMetadata memory riseTokenMetadata = riseTokens[token];
        require(riseTokenMetadata.feeInEther > 0, "!RTNE");

        // Otherwise get the current leverage ratio
        uint256 totalSupply = IERC20(riseTokenMetadata.token).totalSupply();
        uint256 collateralPrice = IRisedleOracle(riseTokenMetadata.oracleContract).getPrice();
        uint8 collateralDecimals = IERC20Metadata(riseTokenMetadata.collateral).decimals();
        uint256 collateralPerRiseToken = getCollateralPerRiseToken(totalSupply, riseTokenMetadata.totalCollateral, riseTokenMetadata.totalPendingFees, collateralDecimals);
        uint256 debtPerRiseToken = getDebtPerRiseToken(riseTokenMetadata.token, totalSupply, collateralDecimals);
        uint256 leverageRatioInEther = calculateLeverageRatio(collateralPerRiseToken, debtPerRiseToken, collateralPrice, riseTokenMetadata.initialPrice, collateralDecimals);
        uint256 nav = calculateNAV(collateralPerRiseToken, debtPerRiseToken, collateralPrice, riseTokenMetadata.initialPrice, collateralDecimals);

        // Revert if the leverage ratio is in range
        require(leverageRatioInEther < riseTokenMetadata.minLeverageRatioInEther || leverageRatioInEther > riseTokenMetadata.maxLeverageRatioInEther, "!LRIR"); // Leverage ratio in range

        // Calculate the borrow or repay amount
        uint256 borrowOrRepayAmount = (riseTokenMetadata.rebalancingStepInEther * nav * totalSupply) / 1 ether;
        uint256 collateralAmount = (borrowOrRepayAmount * (10**collateralDecimals)) / collateralPrice;

        // Leveraging up when: leverage ratio < min leverage ratio
        // 1. Borrow more USDC
        // 2. Swap USDC to collateral token
        if (leverageRatioInEther < riseTokenMetadata.minLeverageRatioInEther) {
            uint256 maximumCollateralPrice = collateralPrice + ((0.01 ether * collateralPrice) / 1 ether);
            // Maximum plus +1% from the oracle price
            uint256 maxBorrowAmount = (collateralAmount * maximumCollateralPrice) / (10**collateralDecimals);
            if (maxBorrowAmount > riseTokenMetadata.maxRebalancingValue) {
                maxBorrowAmount = riseTokenMetadata.maxRebalancingValue;
            }

            // Swap USDC to collateral
            uint256 borrowedAmount = swap(riseTokenMetadata.swapContract, underlyingToken, riseTokenMetadata.collateral, maxBorrowAmount, collateralAmount);

            // Update the borrow states
            setBorrowStates(token, borrowedAmount);

            // Update the total collateral
            riseTokens[riseTokenMetadata.token].totalCollateral += collateralAmount;
        }

        // Leveraging down when: leverage ratio > max leverage ratio
        // 1. Swap collateral to USDC
        // 2. Repay the debt
        if (leverageRatioInEther > riseTokenMetadata.maxLeverageRatioInEther) {
            uint256 minimumCollateralPrice = collateralPrice - ((0.01 ether * collateralPrice) / 1 ether);
            uint256 maxCollateralAmount = (collateralAmount * minimumCollateralPrice) / (10**collateralDecimals);
            if (borrowOrRepayAmount > riseTokenMetadata.maxRebalancingValue) {
                borrowOrRepayAmount = riseTokenMetadata.maxRebalancingValue;
            }

            // Collateral to USDC
            uint256 collateralSoldAmount = swap(riseTokenMetadata.swapContract, riseTokenMetadata.collateral, underlyingToken, maxCollateralAmount, borrowOrRepayAmount);

            // Repay the debts
            setRepayStates(token, borrowOrRepayAmount);

            // Update the total collateral
            riseTokens[riseTokenMetadata.token].totalCollateral -= collateralSoldAmount;
        }

        emit RiseTokenRebalanced(msg.sender, leverageRatioInEther);
    }
}
