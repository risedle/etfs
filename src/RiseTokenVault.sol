// SPDX-License-Identifier: GPL-3.0-or-later

// Risedle RISE Token Vault Contract
// RISE token is 2x leverage long token.
//
// Copyright (c) 2021 Bayu - All rights reserved
// github: pyk
// email: bayu@risedle.com
pragma solidity 0.8.9;
pragma experimental ABIEncoderV2;

import { IERC20Metadata } from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { RisedleVault } from "./RisedleVault.sol";
import { RisedleERC20 } from "./tokens/RisedleERC20.sol";

contract RiseTokenVault is RisedleVault {
    /// @notice RiseTokenMetadata contains the metadata of RISE token
    struct RiseTokenMetadata {
        address token; // Address of ETF token ERC20, make sure this vault can mint & burn this token
        address collateral; // ETF underlying asset (e.g. WETH address)
        address feed; // Chainlink feed like contract (e.g. ETH/USD)
        address swap; // Uniswap v3 swap like contract
        uint256 initialPrice; // In term of vault's underlying asset (e.g. 100 USDC -> 100 * 1e6, coz is 6 decimals for USDC)
        uint256 feeInEther; // Creation and redemption fee in ether units (e.g. 0.1% is 0.001 ether)
        uint256 totalCollateral; // Total amount of underlying managed by this ETF
        uint256 totalPendingFees; // Total amount of creation and redemption pending fees in ETF underlying
    }

    /// @notice Mapping RISE token to their metadata
    mapping(address => RiseTokenMetadata) riseTokens;

    /// @notice Event emitted when new RISE token is created
    event RiseTokenCreated(address indexed creator, address token);

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
        address feed, // Chainlink like price feed (e.g. ETH/USD)
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
        RiseTokenMetadata memory riseTokenMetadata = RiseTokenMetadata(riseTokenAddress, collateral, feed, swap, initialPrice, feeInEther, 0, 0);

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
     * @notice Mint new RISE token
     * @param token The address of RISE token
     * @param amount The collateral amount
     */
    function mint(address token, uint256 amount) external nonReentrant {
        // Accrue interest
        accrueInterest();
    }
}
