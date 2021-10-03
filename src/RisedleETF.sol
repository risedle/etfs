// SPDX-License-Identifier: GPL-3.0-or-later

// Risedle's ETF Contract
// The 2x Leveraged version of any ERC20
//
// I wrote this for ETHOnline Hackathon 2021. Enjoy.

// Copyright (c) 2021 Bayu - All rights reserved
// github: pyk

pragma solidity ^0.8.7;
pragma experimental ABIEncoderV2;

import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";

import "./IRisedleVault.sol";

/// @title Risedle ETF
contract RisedleETF is ERC20, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice The underlying assets address contract (ERC20)
    address internal immutable underlying;

    /// @notice The ETF's fee recipient address
    address internal feeRecipient;

    /// @notice The Risedle Vault address
    address internal vault;

    /// @notice To make sure that setupVault only run once
    bool internal vaultAdded;

    /// @notice The ETF's initial price in term of vault's underlying address
    /// @dev For example 100 USDT would be 100 * 1e6, coz USDT have 6 decimals
    uint256 internal immutable INITIAL_ETF_PRICE;

    /// @notice The ETF's creation and redemption fee in ether units
    uint256 internal FEE_IN_ETHER = 0.001 ether; // 0.1% creation and redemption fee

    /// @notice The ETF's pending fees
    uint256 internal totalPendingCreationFees;
    uint256 internal totalPendingRedemptionFees;

    /// @notice Event emitted when the vault is set
    event ETFVaultConfigured(address setter, address vault);

    /// @notice Event emitted when the fee recipient is updated
    event FeeRecipientUpdated(address updater, address newfeeRecipient);

    /**
     * @notice Construct new ETF
     * @param name The ETF's name
     * @param symbol The ETF's token symbol
     * @param underlying_ The ERC20 contract address of underlying asset
     * @param feeRecipient_ The account address that receive the ETF fee
     * @param initialETFPrice The initial ETF price in term of vault's underlying asset
     */
    constructor(
        string memory name,
        string memory symbol,
        address underlying_,
        address feeRecipient_,
        uint256 initialETFPrice
    ) ERC20(name, symbol) {
        // Set the underlying ETF's asset
        underlying = underlying_;

        // Set the fee recipient address
        feeRecipient = feeRecipient_;

        // Set the initial price
        INITIAL_ETF_PRICE = initialETFPrice;

        // Set vault added to false
        vaultAdded = false;
    }

    /**
     * @notice getETFInformation returns information about the ETF
     * @dev Returns all public info in one function so we can save gas
     * @return underlying_ Address of the underlying asset
     * @return feeRecipient_ Address of the fee recipient
     * @return vault_ Address of the vault
     * @return vaultAdded_ True if the ETF vaule has beed added
     * @return initialPrice_ Initial price of the ETF
     */
    function getETFInformation()
        external
        view
        returns (
            address underlying_,
            address feeRecipient_,
            address vault_,
            bool vaultAdded_,
            uint256 initialPrice_
        )
    {
        underlying_ = underlying;
        feeRecipient_ = feeRecipient;
        vault_ = vault;
        vaultAdded_ = vaultAdded;
        initialPrice_ = INITIAL_ETF_PRICE;
    }

    /**
     * @notice setVault sets the ETF's vault
     * @dev setVault as public coz we want to be able to set the vault when we do
     *      the internal testing (internal) and after deployment (external)
     * @param vault_ The Risedle Vault address
     */
    function setVault(address vault_) public {
        require(!vaultAdded, "!vaultAdded");
        // Set vaultAdded to true
        vaultAdded = true;

        // Set the vault address
        vault = vault_;
        emit ETFVaultConfigured(msg.sender, vault_);
    }

    /**
     * @notice setFeeRecipient updates the fee recipient address.
     * @dev Only governor can call this function
     */
    function setFeeRecipient(address account) external onlyOwner {
        feeRecipient = account;

        emit FeeRecipientUpdated(msg.sender, account);
    }

    /**
     * @notice setFee updates the creation and redemption fees
     * @dev Only governor can update the creation and redemption fees
     * @param fee Fee in ether units (e.g. 0.1% is 0.001 ether)
     */
    function setFee(uint256 fee) external onlyOwner {
        FEE_IN_ETHER = fee;
    }

    /**
     * @notice getFees returns current fees in ether units,
     *         totalPendingCreationFees and totalPendingRedemptionFees
     * @dev We use this function to save gas
     */
    function getFees()
        external
        view
        returns (
            uint256 feeInEther_,
            uint256 totalPendingCreationFees_,
            uint256 totalPendingRedemptionFees_
        )
    {
        feeInEther_ = FEE_IN_ETHER;
        totalPendingCreationFees_ = totalPendingCreationFees;
        totalPendingRedemptionFees_ = totalPendingRedemptionFees;
    }

    /**
     * @notice getPrincipalAndFeeAmount splits principal and fee amount
     * @dev we use principalAmount to get borrowAmount
     * @param amount The amount of underlying asset deposited by the investor
     * @return principalAmount The principal amount
     * @return feeAmount The fee amount collected by the protocol
     */
    function getPrincipalAndFeeAmount(uint256 amount)
        internal
        view
        returns (uint256 principalAmount, uint256 feeAmount)
    {
        feeAmount = (amount * FEE_IN_ETHER) / 1 ether;
        principalAmount = amount - feeAmount;
    }

    /**
     * @notice Investors supplies underlying assets into the ETF and receives
     *         ETF tokens in exchange
     * @param amount The amount of the underlying asset to supply
     */
    function mint(uint256 amount) external nonReentrant {
        // Get principal and fee amount
        // (uint256 principalAmount, uint256 feeAmount) = getPrincipalAndFeeAmount(
        //     amount
        // );
        // Get the borrowAmount based on the principalAmount
        // Convert the ETF underlying asset to the Vault underlying asset
        // TODO:
        // 1. get ETH/USD price
        // 2. Convert principalAmount to borrowAmount based on the ETH/USD price
    }
}
