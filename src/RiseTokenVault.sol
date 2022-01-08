// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (c) 2021 Bayu - All rights reserved
pragma solidity >=0.8.9;
pragma experimental ABIEncoderV2;

import { IERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20Metadata } from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { RisedleVault } from "./RisedleVault.sol";
import { RisedleERC20 } from "./tokens/RisedleERC20.sol";
import { IRisedleOracle } from "./interfaces/IRisedleOracle.sol";
import { IRisedleSwap } from "./interfaces/IRisedleSwap.sol";
import { IRisedleERC20 } from "./interfaces/IRisedleERC20.sol";
import { IWETH9 } from "./interfaces/IWETH9.sol";

/// @title Rise Token Vault
/// @author bayu (github.com/pyk)
/// @dev It implements leveraged tokens. User can mint leveraged tokens, redeem leveraged tokens and trigger the rebalance. Rebalance only get execute when the criteria is met.
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
        uint256 totalCollateralPlusFee; // Total amount of underlying managed by this ETF
        uint256 totalPendingFees; // Total amount of creation and redemption pending fees in ETF underlying
        uint256 minLeverageRatioInEther; // Minimum leverage ratio in ether units (e.g. 2x is 2 ether = 2*1e18)
        uint256 maxLeverageRatioInEther; // Maximum leverage ratio  in ether units (e.g. 3x is 3 ether = 3*1e18)
        uint256 maxRebalancingValue; // The maximum value of buy/sell when rebalancing (e.g. 500K USDC is 500000 * 1e6)
        uint256 rebalancingStepInEther; // The rebalancing step in ether units (e.g. 0.2 is 0.2 ether or 0.2 * 1e18)
        uint256 maxTotalCollateral; // Limit the mint amount
    }

    /// @notice Mapping TOKENRISE to their metadata
    mapping(address => RiseTokenMetadata) riseTokens;

    event RiseTokenCreated(address indexed creator, address token); // Event emitted when new TOKENRISE is created
    event RiseTokenMinted(address indexed user, address indexed riseToken, uint256 mintedAmount); // Event emitted when TOKENRISE is minted
    event RiseTokenRebalanced(address indexed executor, uint256 previousLeverageRatioInEther); // Event emitted when TOKENRISE is successfully rebalanced
    event RiseTokenBurned(address indexed user, address indexed riseToken, uint256 redeemedAmount); // Event emitted when TOKENRISE is burned
    event MaxTotalCollateralUpdated(address indexed token, uint256 newMaxTotalCollateral); // Event emitted when max collateral is set
    event OracleContractUpdated(address indexed token, address indexed oracle); // Event emitted when new oracle contract is set
    event SwapContractUpdated(address indexed token, address indexed swap); // Event emitted when new swap contract is set

    /// @notice Construct new RiseTokenVault
    constructor(
        string memory name, // The name of the vault's token (e.g. Risedle USDC Vault)
        string memory symbol, // The symbol of the vault's token (e.g rvUSDC)
        address underlying, // The ERC20 address of the vault's underlying token (e.g. address of USDC token)
        address feeRecipient // Vault's fee recipient
    ) RisedleVault(name, symbol, underlying, feeRecipient) {}

    /// @notice create creates new TOKENRISE
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
        RiseTokenMetadata memory riseTokenMetadata = riseTokens[tokenRiseAddress];
        require(riseTokenMetadata.feeInEther == 0, "!AE"); // Make sure token metadata is not exists

        // Create new Rise metadata
        riseTokens[tokenRiseAddress] = RiseTokenMetadata({
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
            totalCollateralPlusFee: 0,
            totalPendingFees: 0,
            maxTotalCollateral: 0
        });

        // Emit event
        emit RiseTokenCreated(msg.sender, tokenRiseAddress);
    }

    /// @notice getMetadata returns the metadata of the TOKENRISE
    function getMetadata(address token) external view returns (RiseTokenMetadata memory) {
        return riseTokens[token];
    }

    /// @notice calculateCollateralPerRiseToken returns the collateral shares per TOKENRISE
    function calculateCollateralPerRiseToken(
        uint256 riseTokenSupply, // The total supply of the TOKENRISE
        uint256 totalCollateralPlusFee, // The total collateral managed by the TOKENRISE
        uint256 totalPendingFees, // The total pending fees in the TOKENRISE
        uint8 collateralDecimals // The collateral decimals (e.g. ETH is 18 decimals)
    ) internal pure returns (uint256 collateralPerRiseToken) {
        if (riseTokenSupply == 0) return 0;
        collateralPerRiseToken = ((totalCollateralPlusFee - totalPendingFees) * (10**collateralDecimals)) / riseTokenSupply; // Get collateral per TOKENRISE
    }

    /// @notice getCollateralPerRiseToken returns the collateral shares per TOKENRISE
    function getCollateralPerRiseToken(address token) external view returns (uint256 collateralPerRiseToken) {
        RiseTokenMetadata memory riseTokenMetadata = riseTokens[token];
        if (riseTokenMetadata.feeInEther == 0) return 0; // Make sure the TOKENRISE is exists
        uint256 riseTokenSupply = IERC20(riseTokenMetadata.token).totalSupply();
        uint8 collateralDecimals = IERC20Metadata(riseTokenMetadata.token).decimals();
        collateralPerRiseToken = calculateCollateralPerRiseToken(riseTokenSupply, riseTokenMetadata.totalCollateralPlusFee, riseTokenMetadata.totalPendingFees, collateralDecimals);
    }

    /// @notice calculateDebtPerRiseToken returns the debt shares per TOKENRISE
    function calculateDebtPerRiseToken(
        address token, // The address of TOKENRISE (ERC20)
        uint256 totalSupply, // The current total supply of the TOKENRISE
        uint8 collateralDecimals // The decimals of the collateral token (e.g. ETH have 18 decimals)
    ) internal view returns (uint256 debtPerRiseToken) {
        if (totalSupply == 0) return 0;
        uint256 totalDebt = getOutstandingDebt(token); // Get total TOKENRISE debt
        if (totalDebt == 0) return 0;
        uint256 a = (totalDebt * (10**collateralDecimals));
        uint256 b = totalSupply;
        debtPerRiseToken = a / b + (a % b == 0 ? 0 : 1); // Rounds up instead of rounding down
    }

    /// @notice getDebtPerRiseToken returns the debt shares per TOKENRISE
    function getDebtPerRiseToken(address token) external view returns (uint256 debtPerRiseToken) {
        RiseTokenMetadata memory riseTokenMetadata = riseTokens[token];
        if (riseTokenMetadata.feeInEther == 0) return 0; // Make sure the TOKENRISE is exists
        uint256 totalSupply = IERC20(riseTokenMetadata.token).totalSupply();
        uint8 collateralDecimals = IERC20Metadata(riseTokenMetadata.token).decimals();
        debtPerRiseToken = calculateDebtPerRiseToken(riseTokenMetadata.token, totalSupply, collateralDecimals);
    }

    /// @notice calculateNAV calculates the net-asset value of the ETF
    function calculateNAV(
        uint256 collateralPerRiseToken, // The amount of collateral per TOKENRISE (e.g 0.5 ETH is 0.5*1e18)
        uint256 debtPerRiseToken, // The amount of debt per TOKENRISE (e.g. 50 USDC is 50*1e6)
        uint256 collateralPrice, // The collateral price in term of supply asset (e.g 100 USDC is 100*1e6)
        uint256 etfInitialPrice, // The initial price of the ETF in terms od supply asset (e.g. 100 USDC is 100*1e6)
        uint8 collateralDecimals // The decimals of the collateral token
    ) internal pure returns (uint256 nav) {
        if (collateralPerRiseToken == 0 || debtPerRiseToken == 0) return etfInitialPrice;
        uint256 collateralValuePerRiseToken = (collateralPerRiseToken * collateralPrice) / (10**collateralDecimals); // Get the collateral value in term of the supply
        nav = collateralValuePerRiseToken - debtPerRiseToken; // Calculate the NAV
    }

    /// @notice Get the net-asset value of the TOKENRISE
    function getNAV(address token) public view returns (uint256 nav) {
        RiseTokenMetadata memory riseTokenMetadata = riseTokens[token];
        if (riseTokenMetadata.feeInEther == 0) return 0; // Make sure the TOKENRISE is exists
        uint256 collateralPrice = IRisedleOracle(riseTokenMetadata.oracleContract).getPrice(); // For example WETH/USDC would trading around 4000 USDC (4000 * 1e6)
        uint256 totalSupply = IERC20(riseTokenMetadata.token).totalSupply(); // Get collateral per TOKENRISE and debt per TOKENRISE
        uint8 collateralDecimals = IERC20Metadata(riseTokenMetadata.token).decimals();
        uint256 collateralPerRiseToken = calculateCollateralPerRiseToken(totalSupply, riseTokenMetadata.totalCollateralPlusFee, riseTokenMetadata.totalPendingFees, collateralDecimals);
        uint256 debtPerRiseToken = calculateDebtPerRiseToken(riseTokenMetadata.token, totalSupply, collateralDecimals);

        nav = calculateNAV(collateralPerRiseToken, debtPerRiseToken, collateralPrice, riseTokenMetadata.initialPrice, collateralDecimals);
    }

    /// @notice getCollateralAndFeeAmount splits collateral and fee amount
    function getCollateralAndFeeAmount(uint256 amount, uint256 feeInEther) internal pure returns (uint256 collateralAmount, uint256 feeAmount) {
        feeAmount = (amount * feeInEther) / 1 ether;
        collateralAmount = amount - feeAmount;
    }

    /// @notice swap swaps the inputToken to outputToken
    function swap(
        address swapContract, // The address of swap contract
        address inputToken, // The address of the token that we want to sell
        address outputToken, // The address of the output token that we want to buy
        uint256 maxInputAmount, // The maximum amount of input token that we want to sell
        uint256 outputAmount // The amount of output token that we want to buy
    ) internal returns (uint256 inputTokenSold) {
        IERC20(inputToken).safeApprove(swapContract, maxInputAmount); // Allow swap contract to spend the input token from the contract
        inputTokenSold = IRisedleSwap(swapContract).swap(inputToken, outputToken, maxInputAmount, outputAmount); // Swap inputToken to outputToken
        IERC20(inputToken).safeApprove(swapContract, 0); // Reset the approval
    }

    /// @notice getMintAmount returns the amount of TOKENRISE need to be minted
    function getMintAmount(
        uint256 nav, // The net asset value of TOKENRISE (e.g. 200 USDC is 200 * 1e6)
        uint256 collateralAmount, // The amount of the collateral (e.g. 1 ETH is 1e18)
        uint256 collateralPrice, // The price of the collateral (e.g. 4000 USDC is 4000 * 1e6)
        uint256 borrowAmount, // The amount of borrow (e.g 200 USDC is 200 * 1e6)
        uint8 collateralDecimals // The decimals of the collateral token (e.g. ETH have 18 decimals)
    ) internal pure returns (uint256 mintedAmount) {
        // Calculate the total investment
        uint256 totalInvestment = ((2 * collateralAmount * collateralPrice) / (10**collateralDecimals)) - borrowAmount; // totalInvestment = (2 x collateralValue) - borrowAmount
        mintedAmount = (totalInvestment * (10**collateralDecimals)) / nav; // Get minted amount
    }

    /// @notice Mint new TOKENRISE
    function mintRiseToken(
        address token, // The address of TOKENRISE
        address minter, // The minter address
        address recipient, // The TOKENRISE recipient
        uint256 amount // The Amount
    ) internal nonReentrant {
        RiseTokenMetadata memory riseTokenMetadata = riseTokens[token];
        require(riseTokenMetadata.feeInEther > 0, "!RTNE"); // Make sure the TOKENRISE is exists
        if (riseTokenMetadata.maxTotalCollateral > 0) require(riseTokenMetadata.totalCollateralPlusFee + (2 * amount) < riseTokenMetadata.maxTotalCollateral, "!CIR"); // Cap is reached
        accrueInterest(); // Accrue interest
        uint256 nav = getNAV(token); // For example, If ETHRISE nav is 200 USDC, it will returns 200 * 1e6
        if (minter != address(this)) IERC20(riseTokenMetadata.collateral).safeTransferFrom(minter, address(this), amount); // Don't get WETH from the user
        (uint256 collateralAmount, uint256 feeAmount) = getCollateralAndFeeAmount(amount, riseTokenMetadata.feeInEther); // Get the collateral and fee amount
        riseTokens[riseTokenMetadata.token].totalCollateralPlusFee += ((2 * collateralAmount) + feeAmount); // Update the TOKENRISE metadata
        riseTokens[riseTokenMetadata.token].totalPendingFees += feeAmount;
        uint256 collateralPrice = IRisedleOracle(riseTokenMetadata.oracleContract).getPrice(); // Get the current price of collateral in term of vault underlying asset
        uint8 collateralDecimals = IERC20Metadata(riseTokenMetadata.collateral).decimals();
        uint256 maxCollateralPrice = collateralPrice + ((riseTokenMetadata.maxSwapSlippageInEther * collateralPrice) / 1 ether); // Maximum slippage from the oracle price; It can be +X% from the oracle price
        uint256 maxBorrowAmount = (collateralAmount * maxCollateralPrice) / (10**collateralDecimals); // Calculate the maximum borrow amount
        require(getTotalAvailableCash() > maxBorrowAmount, "!NES"); // Make sure we do have enough vault's underlying available
        uint256 borrowedAmount = swap(riseTokenMetadata.swapContract, underlyingToken, riseTokenMetadata.collateral, maxBorrowAmount, collateralAmount);
        setBorrowStates(token, borrowedAmount); // Set TOKENRISE debt states
        uint256 mintedAmount = getMintAmount(nav, collateralAmount, collateralPrice, borrowedAmount, collateralDecimals); // Calculate minted amount
        IRisedleERC20(token).mint(recipient, mintedAmount); // Transfer TOKENRISE to the caller
        emit RiseTokenMinted(recipient, token, mintedAmount);
    }

    /// @notice Mint new ETHRISE. The ETH will automatically wrapped to WETH first
    function mint(address token) external payable {
        RiseTokenMetadata memory riseTokenMetadata = riseTokens[token];
        require(riseTokenMetadata.feeInEther > 0, "!RTNE"); // Make sure the TOKENRISE is exists
        require(riseTokenMetadata.isETH, "!TRNE"); // TOKENRISE is not ETH enabled
        require(msg.value > 0, "!EIZ"); // ETH is zero
        IWETH9(riseTokenMetadata.collateral).deposit{ value: msg.value }(); // Wrap the ETH to WETH
        mintRiseToken(token, address(this), msg.sender, msg.value); // Mint the ETHRISE token as the contract and send the ETHRISE to the user
    }

    /// @notice Mint new ETHRISE and sent minted token to the recipient
    function mint(address token, address recipient) external payable {
        RiseTokenMetadata memory riseTokenMetadata = riseTokens[token];
        require(riseTokenMetadata.feeInEther > 0, "!RTNE"); // Make sure the TOKENRISE is exists
        require(riseTokenMetadata.isETH, "!TRNE"); // TOKENRISE is not ETH enabled
        require(msg.value > 0, "!EIZ"); // ETH is zero
        IWETH9(riseTokenMetadata.collateral).deposit{ value: msg.value }(); // Wrap the ETH to WETH
        mintRiseToken(token, address(this), recipient, msg.value); // Mint the ETHRISE token as the contract and send the ETHRISE to the user
    }

    /// @notice Mint new ERC20RISE
    function mint(address token, uint256 amount) external {
        mintRiseToken(token, msg.sender, msg.sender, amount);
    }

    /// @notice Mint new ERC20RISE with custom recipient
    function mint(
        address token,
        address recipient,
        uint256 amount
    ) external {
        mintRiseToken(token, msg.sender, recipient, amount);
    }

    /// @notice calculateLeverageRatio calculates leverage ratio
    function calculateLeverageRatio(
        uint256 collateralPerRiseToken,
        uint256 debtPerRiseToken,
        uint256 collateralPrice,
        uint256 etfInitialPrice,
        uint8 collateralDecimals
    ) internal pure returns (uint256 leverageRatioInEther) {
        uint256 collateralValuePerRiseToken = (collateralPerRiseToken * collateralPrice) / (10**collateralDecimals);
        uint256 nav = calculateNAV(collateralPerRiseToken, debtPerRiseToken, collateralPrice, etfInitialPrice, collateralDecimals);
        leverageRatioInEther = (collateralValuePerRiseToken * 1 ether) / nav;
    }

    /// @notice Get the leverage ratio
    function getLeverageRatioInEther(address token) external view returns (uint256 leverageRatioInEther) {
        RiseTokenMetadata memory riseTokenMetadata = riseTokens[token];
        if (riseTokenMetadata.feeInEther == 0) return 0; // Make sure the TOKENRISE is exists
        uint256 totalSupply = IERC20(riseTokenMetadata.token).totalSupply();
        uint8 collateralDecimals = IERC20Metadata(riseTokenMetadata.collateral).decimals();
        uint256 collateralPerRiseToken = calculateCollateralPerRiseToken(totalSupply, riseTokenMetadata.totalCollateralPlusFee, riseTokenMetadata.totalPendingFees, collateralDecimals);
        uint256 debtPerRiseToken = calculateDebtPerRiseToken(riseTokenMetadata.token, totalSupply, collateralDecimals);
        uint256 collateralPrice = IRisedleOracle(riseTokenMetadata.oracleContract).getPrice();
        leverageRatioInEther = calculateLeverageRatio(collateralPerRiseToken, debtPerRiseToken, collateralPrice, riseTokenMetadata.initialPrice, collateralDecimals);
    }

    /// @notice Run the rebalancing
    function rebalance(address token) external nonReentrant {
        RiseTokenMetadata memory riseTokenMetadata = riseTokens[token];
        require(riseTokenMetadata.feeInEther > 0, "!RTNE"); // Make sure the TOKENRISE is exists
        accrueInterest(); // Accrue interest

        // Otherwise get the current leverage ratio
        uint256 totalSupply = IERC20(riseTokenMetadata.token).totalSupply();
        uint256 collateralPrice = IRisedleOracle(riseTokenMetadata.oracleContract).getPrice();
        uint8 collateralDecimals = IERC20Metadata(riseTokenMetadata.collateral).decimals();
        uint256 collateralPerRiseToken = calculateCollateralPerRiseToken(totalSupply, riseTokenMetadata.totalCollateralPlusFee, riseTokenMetadata.totalPendingFees, collateralDecimals);
        uint256 debtPerRiseToken = calculateDebtPerRiseToken(riseTokenMetadata.token, totalSupply, collateralDecimals);
        uint256 leverageRatioInEther = calculateLeverageRatio(collateralPerRiseToken, debtPerRiseToken, collateralPrice, riseTokenMetadata.initialPrice, collateralDecimals);
        uint256 nav = calculateNAV(collateralPerRiseToken, debtPerRiseToken, collateralPrice, riseTokenMetadata.initialPrice, collateralDecimals);
        require(leverageRatioInEther < riseTokenMetadata.minLeverageRatioInEther || leverageRatioInEther > riseTokenMetadata.maxLeverageRatioInEther, "!LRIR"); // Leverage ratio in range
        uint256 borrowOrRepayAmount = (riseTokenMetadata.rebalancingStepInEther * ((nav * totalSupply) / (10**collateralDecimals))) / 1 ether;
        uint256 collateralAmount = (borrowOrRepayAmount * (10**collateralDecimals)) / collateralPrice;

        // Leveraging up when: leverage ratio < min leverage ratio. Borrow more USDCa and Swap USDC to collateral token
        if (leverageRatioInEther < riseTokenMetadata.minLeverageRatioInEther) {
            uint256 maximumCollateralPrice = collateralPrice + ((riseTokenMetadata.maxSwapSlippageInEther * collateralPrice) / 1 ether);
            uint256 maxBorrowAmount = (collateralAmount * maximumCollateralPrice) / (10**collateralDecimals);
            if (maxBorrowAmount > riseTokenMetadata.maxRebalancingValue) {
                maxBorrowAmount = riseTokenMetadata.maxRebalancingValue;
            }
            uint256 borrowedAmount = swap(riseTokenMetadata.swapContract, underlyingToken, riseTokenMetadata.collateral, maxBorrowAmount, collateralAmount);
            setBorrowStates(token, borrowedAmount);
            riseTokens[riseTokenMetadata.token].totalCollateralPlusFee += collateralAmount;
        }

        // Leveraging down when: leverage ratio > max leverage ratio. Swap collateral to USDC and Repay the debt
        if (leverageRatioInEther > riseTokenMetadata.maxLeverageRatioInEther) {
            uint256 minimumCollateralPrice = collateralPrice - ((riseTokenMetadata.maxSwapSlippageInEther * collateralPrice) / 1 ether);
            uint256 maxCollateralAmount = (borrowOrRepayAmount * (10**collateralDecimals)) / minimumCollateralPrice;
            if (borrowOrRepayAmount > riseTokenMetadata.maxRebalancingValue) {
                maxCollateralAmount = (riseTokenMetadata.maxRebalancingValue * (10**collateralDecimals)) / minimumCollateralPrice;
            }
            uint256 collateralSoldAmount = swap(riseTokenMetadata.swapContract, riseTokenMetadata.collateral, underlyingToken, maxCollateralAmount, borrowOrRepayAmount);
            setRepayStates(token, borrowOrRepayAmount);
            riseTokens[riseTokenMetadata.token].totalCollateralPlusFee -= collateralSoldAmount;
        }

        emit RiseTokenRebalanced(msg.sender, leverageRatioInEther);
    }

    function updateRedeemStates(
        address token, // TOKENRISE address
        uint256 collateral, // Collateral amount
        uint256 fee // Fee amount
    ) internal {
        riseTokens[token].totalCollateralPlusFee -= collateral;
        riseTokens[token].totalPendingFees += fee;
    }

    function calculateRedeemAmount(RiseTokenMetadata memory riseTokenMetadata, uint256 amount) internal returns (uint256 redeemAmount) {
        uint256 totalSupply = IERC20(riseTokenMetadata.token).totalSupply();
        uint8 collateralDecimals = IERC20Metadata(riseTokenMetadata.collateral).decimals();
        uint256 collateralPrice = IRisedleOracle(riseTokenMetadata.oracleContract).getPrice();
        uint256 collateralPerRiseToken = calculateCollateralPerRiseToken(totalSupply, riseTokenMetadata.totalCollateralPlusFee, riseTokenMetadata.totalPendingFees, collateralDecimals);
        uint256 debtPerRiseToken = calculateDebtPerRiseToken(riseTokenMetadata.token, totalSupply, collateralDecimals);
        uint256 repayAmount = (debtPerRiseToken * amount) / (10**collateralDecimals);
        setRepayStates(riseTokenMetadata.token, repayAmount);
        uint256 collateralOwnedByUser = (amount * collateralPerRiseToken) / (10**collateralDecimals);
        uint256 minimumCollateralPrice = collateralPrice - ((riseTokenMetadata.maxSwapSlippageInEther * collateralPrice) / 1 ether);
        uint256 maxCollateralAmount = (((repayAmount * (10**collateralDecimals)) / ((collateralOwnedByUser * minimumCollateralPrice) / (10**collateralDecimals))) * collateralOwnedByUser) / (10**collateralDecimals);
        uint256 collateralSoldAmount = swap(riseTokenMetadata.swapContract, riseTokenMetadata.collateral, underlyingToken, maxCollateralAmount, repayAmount);
        uint256 feeAmount;
        (redeemAmount, feeAmount) = getCollateralAndFeeAmount(collateralOwnedByUser - collateralSoldAmount, riseTokenMetadata.feeInEther);
        updateRedeemStates(riseTokenMetadata.token, (collateralOwnedByUser - feeAmount), feeAmount);
    }

    /// @notice redeem Burn the TOKENRISE then send the collateral token to the sender
    function redeem(address token, uint256 amount) external nonReentrant {
        accrueInterest(); // Accrue interest
        RiseTokenMetadata memory riseTokenMetadata = riseTokens[token];
        require(riseTokenMetadata.feeInEther > 0, "!RTNE"); // Make sure the TOKENRISE is exists
        uint256 redeemAmount = calculateRedeemAmount(riseTokenMetadata, amount);
        IRisedleERC20(token).burn(msg.sender, amount);
        // Send the remaining collateral to the investor minus the fee
        if (riseTokenMetadata.isETH) {
            IWETH9(riseTokenMetadata.collateral).withdraw(redeemAmount);
            (bool success, ) = msg.sender.call{ value: redeemAmount }("");
            require(success, "!ERF"); // ETH Redeem failed
        } else {
            IERC20(riseTokenMetadata.collateral).safeTransfer(msg.sender, redeemAmount);
        }

        emit RiseTokenBurned(msg.sender, token, redeemAmount);
    }

    /// @notice collectPendingFees withdraws collected fees to the FEE_RECIPIENT address
    function collectPendingFees(address token) external {
        accrueInterest(); // Accrue interest
        RiseTokenMetadata memory riseTokenMetadata = riseTokens[token];
        require(riseTokenMetadata.feeInEther > 0, "!RTNE"); // Make sure the TOKENRISE is exists
        IERC20(riseTokenMetadata.collateral).safeTransfer(FEE_RECIPIENT, riseTokenMetadata.totalPendingFees);
        riseTokens[token].totalCollateralPlusFee -= riseTokenMetadata.totalPendingFees;
        riseTokens[token].totalPendingFees = 0;

        emit FeeCollected(msg.sender, riseTokenMetadata.totalPendingFees, FEE_RECIPIENT);
    }

    /// @notice Set the cap
    function setMaxTotalCollateral(address token, uint256 maxTotalCollateral) external onlyOwner {
        RiseTokenMetadata memory riseTokenMetadata = riseTokens[token];
        require(riseTokenMetadata.feeInEther > 0, "!RTNE"); // Make sure the TOKENRISE is exists
        riseTokens[token].maxTotalCollateral = maxTotalCollateral;
        emit MaxTotalCollateralUpdated(token, maxTotalCollateral);
    }

    /// @notice Set the oracle contract
    function setOracleContract(address token, address newOracle) external onlyOwner {
        RiseTokenMetadata memory riseTokenMetadata = riseTokens[token];
        require(riseTokenMetadata.feeInEther > 0, "!RTNE"); // Make sure the TOKENRISE is exists
        riseTokens[token].oracleContract = newOracle;
        emit OracleContractUpdated(token, newOracle);
    }

    /// @notice Set the swap contract
    function setSwapContract(address token, address newSwap) external onlyOwner {
        RiseTokenMetadata memory riseTokenMetadata = riseTokens[token];
        require(riseTokenMetadata.feeInEther > 0, "!RTNE"); // Make sure the TOKENRISE is exists
        riseTokens[token].swapContract = newSwap;
        emit SwapContractUpdated(token, newSwap);
    }

    /// @notice Receive ETH
    receive() external payable {}
}
