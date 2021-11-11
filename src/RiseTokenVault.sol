// SPDX-License-Identifier: GPL-3.0-or-later

// Risedle RISE Token Vault Contract
// RISE token is 2x leverage long token.
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

    /// @notice RiseTokenMetadata contains the metadata of RISE token
    struct RiseTokenMetadata {
        address token; // Address of ETF token ERC20, make sure this vault can mint & burn this token
        address collateral; // ETF underlying asset (e.g. WETH address)
        address oracle; // Contract address that implement IRisedleOracle interface
        address swap; // Contract address that implment IRisedleSwap interface
        uint256 initialPrice; // In term of vault's underlying asset (e.g. 100 USDC -> 100 * 1e6, coz is 6 decimals for USDC)
        uint256 feeInEther; // Creation and redemption fee in ether units (e.g. 0.1% is 0.001 ether)
        uint256 totalCollateral; // Total amount of underlying managed by this ETF
        uint256 totalPendingFees; // Total amount of creation and redemption pending fees in ETF underlying
    }

    /// @notice Mapping RISE token to their metadata
    mapping(address => RiseTokenMetadata) riseTokens;

    /// @notice Event emitted when new RISE token is created
    event RiseTokenCreated(address indexed creator, address token);

    /// @notice Event emitted when RISE token is minted
    event RiseTokenMinted(address indexed user, address indexed riseToken, uint256 mintedAmount);

    /**
     * @notice Construct new RiseTokenVault
     */
    constructor(
        string memory name, // The name of the vault's token (e.g. Risedle USDC Vault)
        string memory symbol, // The symbol of the vault's token (e.g rvUSDC)
        address underlying // The ERC20 address of the vault's underlying token (e.g. address of USDC token)
    ) RisedleVault(name, symbol, underlying) {}

    /**
     * @notice create creates new RISE token
     * @dev Only admin can call this function
     * @return The address of the new RISE token
     */
    function create(
        string memory name, // The name of the RISE token (e.g. ETH 2x Leverage Risedle)
        string memory symbol, // The symbol of the RISE token (e.g. ETHRISE)
        address collateral, // The underlying token of RISE token (e.g. WETH)
        address oracle, // Contract address that implement IRisedleOracle interface
        address swap, // Uniswap V3 like token swapper
        uint256 initialPrice, // Initial price of the ETF based on the Vault's underlying asset (e.g. 100 USDC => 100 * 1e6)
        uint256 feeInEther // Creation and redemption fee in ether units (e.g. 0.001 ether = 0.1%)
    ) external onlyOwner returns (address) {
        // Get collateral decimals
        uint8 collateralDecimals = IERC20Metadata(collateral).decimals();

        // Create new RISE token
        RisedleERC20 riseToken = new RisedleERC20(
            name,
            symbol,
            address(this), // Set the vault contract as the token owner
            collateralDecimals
        );

        // Create new Rise metadata
        address riseTokenAddress = address(riseToken);
        RiseTokenMetadata memory riseTokenMetadata = RiseTokenMetadata(riseTokenAddress, collateral, oracle, swap, initialPrice, feeInEther, 0, 0);

        // Map new info to their token
        riseTokens[riseTokenAddress] = riseTokenMetadata;

        // Emit event
        emit RiseTokenCreated(msg.sender, riseTokenAddress);

        return riseTokenAddress;
    }

    /**
     * @notice getMetadata returns the metadata of the RISE token
     * @param token The address of the RISE token
     * @return The metadata of the RISE token
     */
    function getMetadata(address token) external view returns (RiseTokenMetadata memory) {
        return riseTokens[token];
    }

    /**
     * @notice getCollateralPerRiseToken returns the collateral shares per RISE token
     * @return collateralPerRiseToken The amount of collateral per RISE token (e.g. 0.5 ETH is 0.5*1e18)
     */
    function getCollateralPerRiseToken(
        uint256 riseTokenSupply, // The total supply of the RISE token
        uint256 totalCollateral, // The total collateral managed by the RISE token
        uint256 totalPendingFees, // The total pending fees in the RISE token
        uint8 collateralDecimals // The collateral decimals (e.g. ETH is 18 decimals)
    ) internal pure returns (uint256 collateralPerRiseToken) {
        if (riseTokenSupply == 0) return 0;

        // Get collateral per RISE token
        collateralPerRiseToken = ((totalCollateral - totalPendingFees) * (10**collateralDecimals)) / riseTokenSupply;
    }

    /**
     * @notice getDebtPerRiseToken returns the debt shares per RISE token
     * @return debtPerRiseToken The amount of debt per RISE token (e.g. 80 USDC is 80*1e6)
     */
    function getDebtPerRiseToken(
        address token, // The address of RISE token (ERC20)
        uint256 totalSupply, // The current total supply of the RISE token
        uint8 collateralDecimals // The decimals of the collateral token (e.g. ETH have 18 decimals)
    ) internal view returns (uint256 debtPerRiseToken) {
        if (totalSupply == 0) return 0;

        // Get total RISE token debt
        uint256 totalDebt = getOutstandingDebt(token);
        if (totalDebt == 0) return 0;

        // Get debt per RISE token
        debtPerRiseToken = (totalDebt * (10**collateralDecimals)) / totalSupply;
    }

    /**
     * @notice calculateNAV calculates the net-asset value of the ETF
     * @return nav The NAV price of the RISE token in term of vault underlying asset (e.g. 50 USDC is 50*1e6)
     */
    function calculateNAV(
        uint256 collateralPerRiseToken, // The amount of collateral per RISE token (e.g 0.5 ETH is 0.5*1e18)
        uint256 debtPerRiseToken, // The amount of debt per RISE token (e.g. 50 USDC is 50*1e6)
        uint256 collateralPrice, // The collateral price in term of supply asset (e.g 100 USDC is 100*1e6)
        uint256 etfInitialPrice, // The initial price of the ETF in terms od supply asset (e.g. 100 USDC is 100*1e6)
        uint8 collateralDecimals // The decimals of the collateral token
    ) internal pure returns (uint256 nav) {
        if (collateralPerRiseToken == 0 || debtPerRiseToken == 0) return etfInitialPrice;

        // Get the collateral value in term of the supply
        uint256 collateralValuePerETF = (collateralPerRiseToken * collateralPrice) / (10**collateralDecimals);

        // Calculate the NAV
        nav = collateralValuePerETF - debtPerRiseToken;
    }

    /**
     * @notice Get the net-asset value of the RISE token
     * @param token The address of RISE token
     * @return nav The NAV value of RISE token in term of vault's underlying asset.
     * For example ETHRISE in USDC vault would be 200 * 1e6
     */
    function getNAV(address token) public view returns (uint256 nav) {
        // Make sure the RISE token is exists
        RiseTokenMetadata memory riseTokenMetadata = riseTokens[token];
        if (riseTokenMetadata.feeInEther == 0) return 0;

        // Get the current price of the RISE token collateral in term of vault's underlying token
        // For example WETH/USDC would trading around 4000 USDC (4000 * 1e6)
        uint256 collateralPrice = IRisedleOracle(riseTokenMetadata.oracle).getPrice();

        // Get collateral per RISE token and debt per RISE token
        uint256 totalSupply = IERC20(riseTokenMetadata.token).totalSupply();
        uint8 collateralDecimals = IERC20Metadata(riseTokenMetadata.token).decimals();
        uint256 collateralPerRiseToken = getCollateralPerRiseToken(totalSupply, riseTokenMetadata.totalCollateral, riseTokenMetadata.totalPendingFees, collateralDecimals);
        uint256 debtPerRiseToken = getDebtPerRiseToken(riseTokenMetadata.token, totalSupply, collateralDecimals);

        nav = calculateNAV(collateralPerRiseToken, debtPerRiseToken, collateralPrice, riseTokenMetadata.initialPrice, collateralDecimals);
    }

    /**
     * @notice getCollateralAndFeeAmount splits collateral and fee amount
     * @param amount The amount of RISE token collateral deposited by the user
     * @param feeInEther The RISE token creation and redemption fee in ether units (e.g. 0.001 ether = 0.1%)
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
        address swap, // The address of swap contract
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
        IERC20(underlyingToken).safeApprove(swap, maxSupplyOut);

        // Buy more collateral using the Risedle Swap contract
        // We want to get exact amount of collateral with minimal vault's underlying as possible
        borrowAmount = IRisedleSwap(swap).swap(underlyingToken, collateralToken, maxSupplyOut, collateralAmount);

        // Reset the approval
        IERC20(underlyingToken).safeApprove(swap, 0);
    }

    /**
     * @notice getMintAmount returns the amount of RISE token need to be minted
     * @return mintedAmount The amount of ETF token need to be minted
     */
    function getMintAmount(
        uint256 nav, // The net asset value of RISE token (e.g. 200 USDC is 200 * 1e6)
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
     * @notice Mint new RISE token
     * @param token The address of RISE token
     * @param amount The collateral amount
     */
    function mint(address token, uint256 amount) external nonReentrant {
        // Accrue interest
        accrueInterest();

        // Make sure the RISE token is exists
        RiseTokenMetadata memory riseTokenMetadata = riseTokens[token];
        require(riseTokenMetadata.feeInEther > 0, "!RTNE");

        // Get the current net-asset value of the RISE token in term of underlying
        // For example, If ETHRISE nav is 200 USDC, it will returns 200 * 1e6
        uint256 nav = getNAV(token);

        // Transfer the collateral to the vault
        IERC20(riseTokenMetadata.collateral).safeTransferFrom(msg.sender, address(this), amount);

        // Get the collateral and fee amount
        (uint256 collateralAmount, uint256 feeAmount) = getCollateralAndFeeAmount(amount, riseTokenMetadata.feeInEther);

        // Update the RISE token metadata
        riseTokens[riseTokenMetadata.token].totalCollateral += ((2 * collateralAmount) + feeAmount);
        riseTokens[riseTokenMetadata.token].totalPendingFees += feeAmount;

        // Get the current price of collateral in term of vault underlying asset
        uint256 collateralPrice = IRisedleOracle(riseTokenMetadata.oracle).getPrice();

        // Get the borrow amount
        uint8 collateralDecimals = IERC20Metadata(riseTokenMetadata.collateral).decimals();
        uint256 borrowAmount = borrowAndSwap(riseTokenMetadata.swap, riseTokenMetadata.collateral, collateralAmount, collateralPrice, collateralDecimals);

        // Set RISE token debt states
        setBorrowStates(token, borrowAmount);

        // Calculate minted amount
        uint256 mintedAmount = getMintAmount(nav, collateralAmount, collateralPrice, borrowAmount, collateralDecimals);

        // Transfer RISE token to the caller
        IRisedleERC20(token).mint(msg.sender, mintedAmount);

        // Emit the event
        emit RiseTokenMinted(msg.sender, token, mintedAmount);
    }
}
