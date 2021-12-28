// SPDX-License-Identifier: GPL-3.0-or-later

// Risedle's Vault External Test
// Test & validate user/contract interaction with Risedle's Vault

pragma solidity >=0.8.9;
pragma experimental ABIEncoderV2;

import "lib/ds-test/src/test.sol";
import { IERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { SafeERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

import { Hevm } from "./Hevm.sol";
import { RiseTokenVault } from "../RiseTokenVault.sol";
import { RisedleERC20 } from "../tokens/RisedleERC20.sol";
import { CustomizableOracle } from "../oracles/CustomizableOracle.sol";
import { CustomizableSwap } from "../swaps/CustomizableSwap.sol";

import { IRisedleOracle } from "../interfaces/IRisedleOracle.sol";
import { IRisedleSwap } from "../interfaces/IRisedleSwap.sol";

import { USDC_ADDRESS, WETH_ADDRESS, UNI_ADDRESS } from "chain/Constants.sol";

/// @title DummyUser
/// @author bayu (github.com/pyk)
/// @dev Contract to simulate user interactions
contract DummyUser {
    using SafeERC20 for IERC20;

    RiseTokenVault private _vault;

    constructor(RiseTokenVault vault) {
        _vault = vault;
    }

    /// @notice Mint TOKENRISE using ETH
    function mintWithETH(address token, uint256 amount) public payable {
        // Mint TOKENRISE using ETH
        _vault.mint{ value: amount }(token);
    }

    function mintWithERC20(address token, uint256 collateralAmount) public {
        // Approve to spend the collateral token
        address collateralToken = _vault.getMetadata(token).collateral;
        IERC20(collateralToken).safeApprove(address(_vault), collateralAmount);

        // Mint RISE token
        _vault.mint(token, collateralAmount);

        // Reset the approval
        IERC20(collateralToken).safeApprove(address(_vault), 0);
    }

    receive() external payable {}
}

/// @title RiseTokenVault External test
/// @author bayu (github.com/pyk)
contract RiseTokenVaultExternalTest is DSTest {
    using SafeERC20 for IERC20;
    Hevm hevm;

    /// @notice Run the test setup
    function setUp() public {
        hevm = new Hevm();
    }

    /// @notice Send ETH
    function sendETH(address payable recipient, uint256 amount) public {
        // Transfer ETH to the user
        (bool success, ) = recipient.call{ value: amount }("");
        require(success, "!FTSE"); // Failed to send ETH
    }

    // Utility function to create new ERC20RISE vault and token
    function createNewVault(
        IRisedleOracle oracle,
        IRisedleSwap swap,
        bool isETH,
        address collateral,
        uint256 initialPrice
    ) internal returns (RiseTokenVault vault, RisedleERC20 token) {
        // Update the contract balance to 100K USDC; We use this to supply the vault
        uint256 vaultSupplyAmount = 100_000 * 1e6; // 100K USDC
        hevm.setUSDCBalance(address(this), vaultSupplyAmount);

        // Create new vault first; by default the deployer is the owner
        vault = new RiseTokenVault("Risedle USDC Vault", "rvUSDC", USDC_ADDRESS);

        // Add supply to the vault
        IERC20(USDC_ADDRESS).safeApprove(address(vault), vaultSupplyAmount);
        vault.addSupply(vaultSupplyAmount);

        // Create new UNIRISE
        uint256 feeInEther = 0.001 ether; // 0.1%
        token = new RisedleERC20("UNI 2x Long Risedle", "UNIRISE", address(vault), IERC20Metadata(collateral).decimals());
        vault.create(
            isETH,
            address(token),
            collateral,
            address(oracle),
            address(swap),
            0.05 ether, // Max 5% slippage for mint, redeem and rebalance
            initialPrice, // Initial price
            feeInEther, // creation and redemption fees is 0.1%
            1.7 ether, // Min leverage ratio is 1.7x
            3 ether, // Max leverage ratio is 3x
            250000 * 1e6, // Max value of sell/buy is 250K USDC
            0.3 ether // Rebalancing step is 0.3x
        );
    }

    /// @notice Make sure it fails when user tryin to mint ERC20RISE token with ETH
    function testFail_UserCannotMintERC20RISEWithETH() public {
        // Create new price oracle for the collateral
        CustomizableOracle oracle = new CustomizableOracle();
        oracle.setPrice(15 * 1e6); // Set UNI price to 15 USDC

        // Create new swap contract, with artificial slippage 0.5%
        CustomizableSwap swap = new CustomizableSwap(address(oracle), 0.005 ether);
        // Fund the swap contract with ERC20
        hevm.setUNIBalance(address(swap), 1_000_000 ether); // 1M UNI token

        // Create new vault
        (RiseTokenVault vault, RisedleERC20 unirise) = createNewVault(oracle, swap, false, UNI_ADDRESS, 10 * 1e6);

        // Create new dummy user
        DummyUser user = new DummyUser(vault);
        sendETH(payable(address(user)), 1 ether);

        // Mint the UNIRISE token with ETH, it should be failed
        uint256 depositAmount = 1 ether;
        user.mintWithETH(address(unirise), depositAmount);
    }

    /// @notice Make sure it fails when user trying to mint ETHRISE with zero ETH
    function testFail_UserCannotMintETHRISEWithZeroETH() public {
        // Create new price oracle for the collateral
        CustomizableOracle oracle = new CustomizableOracle();
        oracle.setPrice(4_000 * 1e6); // Set ETH price to 4K USDC

        // Create new swap contract, with artificial slippage 0.5%
        CustomizableSwap swap = new CustomizableSwap(address(oracle), 0.005 ether);
        // Fund the swap contract with WETH
        hevm.setWETHBalance(address(swap), 1_000 ether); // 1K WETH token

        // Create new vault
        (RiseTokenVault vault, RisedleERC20 ethrise) = createNewVault(oracle, swap, true, WETH_ADDRESS, 100 * 1e6);

        // Create new dummy user
        DummyUser user = new DummyUser(vault);
        // Transfer ETH to the user
        sendETH(payable(address(user)), 1 ether);

        // Mint the ETHRISE token with zero ETH, it should be failed
        uint256 depositAmount = 0 ether;
        user.mintWithETH(address(ethrise), depositAmount);
    }

    /// @notice Make sure it fails when user trying to mint and high slippage happen
    function testFail_UserCannotMintERC20RISEWhenHighSlippage() public {
        // Create new price oracle for the collateral
        CustomizableOracle oracle = new CustomizableOracle();
        oracle.setPrice(15 * 1e6); // Set UNI price to 15 USDC

        // Create new swap contract, with artificial slippage 10%
        CustomizableSwap swap = new CustomizableSwap(address(oracle), 0.1 ether);
        // Fund the swap contract with ERC20
        hevm.setUNIBalance(address(swap), 1_000_000 ether); // 1M UNI token

        // Create new vault
        (RiseTokenVault vault, RisedleERC20 unirise) = createNewVault(oracle, swap, false, UNI_ADDRESS, 10 * 1e6);

        // Create new dummy user
        uint256 depositAmount = 10 ether; // 10 UNI token
        DummyUser user = new DummyUser(vault);

        // Fund the user
        hevm.setUNIBalance(address(user), depositAmount);

        // Mint the UNIRISE; due to high slippage it should be failed
        user.mintWithERC20(address(unirise), depositAmount);
    }

    /// @notice Make sure it fails when user trying to mint and high slippage happen
    function testFail_UserCannotMintETHRISEWhenHighSlippage() public {
        // Create new price oracle for the collateral
        CustomizableOracle oracle = new CustomizableOracle();
        oracle.setPrice(4_000 * 1e6); // Set ETH price to 4K USDC

        // Create new swap contract, with artificial slippage 10%
        CustomizableSwap swap = new CustomizableSwap(address(oracle), 0.1 ether);
        // Fund the swap contract with WETH
        hevm.setWETHBalance(address(swap), 1_000 ether); // 1K WETH token

        // Create new vault
        (RiseTokenVault vault, RisedleERC20 ethrise) = createNewVault(oracle, swap, true, WETH_ADDRESS, 100 * 1e6);

        // Create new dummy user
        uint256 depositAmount = 1 ether; // 1 ETH
        DummyUser user = new DummyUser(vault);

        // Transfer ETH to the user
        sendETH(payable(address(user)), depositAmount);

        // Mint the ETHRISE; due to high slippage it should be failed
        user.mintWithETH(address(ethrise), depositAmount);
    }

    /// @notice Make sure it fails when the supply is very low
    function testFail_UserCannotMintERC20RISEWhenNotEnoughSupply() public {
        // Create new price oracle for the collateral
        CustomizableOracle oracle = new CustomizableOracle();
        oracle.setPrice(15 * 1e6); // Set UNI price to 15 USDC

        // Create new swap contract, with artificial slippage 1%
        CustomizableSwap swap = new CustomizableSwap(address(oracle), 0.01 ether);
        // Fund the swap contract with ERC20
        hevm.setUNIBalance(address(swap), 1_000_000 ether); // 1M UNI token

        // Create new vault
        (RiseTokenVault vault, RisedleERC20 unirise) = createNewVault(oracle, swap, false, UNI_ADDRESS, 10 * 1e6);

        // Create new dummy user
        uint256 depositAmount = 100_000 ether; // 100K UNI token
        DummyUser user = new DummyUser(vault);

        // Fund the user
        hevm.setUNIBalance(address(user), depositAmount);

        // Mint the UNIRISE; due to low supply
        user.mintWithERC20(address(unirise), depositAmount);
    }

    /// @notice Make sure it fails when the supply is very low
    function testFail_UserCannotMintETHRISEWhenNotEnoughSupply() public {
        // Create new price oracle for the collateral
        CustomizableOracle oracle = new CustomizableOracle();
        oracle.setPrice(4_000 * 1e6); // Set ETH price to 4K USDC

        // Create new swap contract, with artificial slippage 1%
        CustomizableSwap swap = new CustomizableSwap(address(oracle), 0.01 ether);
        // Fund the swap contract with WETH
        hevm.setWETHBalance(address(swap), 1_000 ether); // 1K WETH token

        // Create new vault
        (RiseTokenVault vault, RisedleERC20 ethrise) = createNewVault(oracle, swap, true, WETH_ADDRESS, 100 * 1e6);

        // Create new dummy user
        uint256 depositAmount = 100 ether; // 100 ETH
        DummyUser user = new DummyUser(vault);
        // Transfer ETH to the user
        sendETH(payable(address(user)), depositAmount);

        // Set the price oracle
        uint256 collateralPrice = 4_000 * 1e6; // 4K USDC
        oracle.setPrice(collateralPrice);

        // Mint the UNIRISE; due to high slippage it should be failed
        user.mintWithETH(address(ethrise), depositAmount);
    }

    // Subsquent minting:
    //    If price is same, nav same, user should receive equal amount of TOKENRISE
    //    If price is up, nav up, user should receive less TOKENRISE
    //    If price is down, nav down, user should receive more TOKENRISE

    /// @notice Make sure the user get the same amount of ETHRISE
    function test_SubsequentMintERC20RISE() public {
        // Create new price oracle for the collateral
        CustomizableOracle oracle = new CustomizableOracle();
        oracle.setPrice(15 * 1e6); // Set UNI price to 15 USDC

        // Create new swap contract, with artificial slippage 0.5%
        CustomizableSwap swap = new CustomizableSwap(address(oracle), 0.005 ether);
        // Fund the swap contract with ERC20
        hevm.setUNIBalance(address(swap), 1_000_000 ether); // 1M UNI token

        // Create new vault
        uint256 initialPrice = 10 * 1e6;
        (RiseTokenVault vault, RisedleERC20 unirise) = createNewVault(oracle, swap, false, UNI_ADDRESS, initialPrice);

        // Create the first dummy user
        uint256 depositAmount = 10 ether; // 10 UNI token
        DummyUser firstUser = new DummyUser(vault);
        hevm.setUNIBalance(address(firstUser), depositAmount);

        // First user mint the UNIRISE
        firstUser.mintWithERC20(address(unirise), depositAmount);

        // Validate the expected values
        // UNIRISE token should be transfered to the firstUser
        assertEq(IERC20(address(unirise)).balanceOf(address(firstUser)), 14.9100750 ether, "firstUser: Wrong UNIRISE balance");

        // The UNI token should be transfered from the user to the contract
        assertEq(IERC20(UNI_ADDRESS).balanceOf(address(firstUser)), 0, "firstUser: UNI token is not transfered");
        assertEq(IERC20(UNI_ADDRESS).balanceOf(address(vault)), 19.99 ether, "firstUser: UNI token is not transfered to the contract"); // Deposit from user + swapped amount

        // Make sure the UNIRISE token vault states is correct
        RiseTokenVault.RiseTokenMetadata memory riseTokenMetadata = vault.getMetadata(address(unirise));

        // Make sure the totalCollateral and totalPendingFees is correct
        assertEq(riseTokenMetadata.totalCollateral, 19.99 ether, "firstUser: UNIRISE total collateral is incorrect"); // 2x collateralAmount + fees
        assertEq(riseTokenMetadata.totalPendingFees, 0.01 ether, "firstUser: UNIRISE total pending fees is incorrect"); // 0.1% from deposit amount

        // Make sure the totalDebt of the UNIRISE token is correct
        assertEq(vault.getOutstandingDebt(address(unirise)), 150599250, "firstUser: UNIRISE borrow amount is incorrect"); // Bought 4000 USDC with ~0.5% slippage

        // Make sure the total available cash is correct
        assertEq(vault.getTotalAvailableCash(), (100_000 * 1e6) - 150599250, "firstUser: Total available cash is invalid");

        // Make sure the NAV doesn't change
        assertEq(vault.getNAV(address(unirise)), initialPrice);

        // ! NEXT MINTING
        // Second user with same deposit amount should have the same amount of minted token
        DummyUser secondUser = new DummyUser(vault);
        hevm.setUNIBalance(address(secondUser), depositAmount);
        secondUser.mintWithERC20(address(unirise), depositAmount);
        assertEq(IERC20(address(unirise)).balanceOf(address(secondUser)), 14.9100750 ether, "secondUser: Wrong UNIRISE balance");

        // ! NEXT MINTING
        // Third user, collateral price go up, nav go up, should receive less amount of UNIRISE token
        oracle.setPrice(20 * 1e6);
        assertEq(vault.getNAV(address(unirise)), 16700168, "thirdUser: NAV invalid"); // ~16 USDC
        DummyUser thirdUser = new DummyUser(vault);
        hevm.setUNIBalance(address(thirdUser), depositAmount);
        thirdUser.mintWithERC20(address(unirise), depositAmount);
        assertEq(IERC20(address(unirise)).balanceOf(address(thirdUser)), 11904131742866299309, "thirdUser: Wrong UNIRISE balance");

        // ! NEXT Minting
        // Fourth user, collateral price go down, nav go down, should receive more amount of ETHRISE token
        oracle.setPrice(17 * 1e6);
        assertEq(vault.getNAV(address(unirise)), 12390447, "fourthUser: NAV invalid"); // ~104 USDC
        DummyUser fourthUser = new DummyUser(vault);
        hevm.setUNIBalance(address(fourthUser), depositAmount);
        fourthUser.mintWithERC20(address(unirise), depositAmount);
        assertEq(IERC20(address(unirise)).balanceOf(address(fourthUser)), 13637994658304095082, "fourthUser: Wrong UNIRISE balance");

        // Validate the UNIRISE token states
        riseTokenMetadata = vault.getMetadata(address(unirise));
        assertEq(riseTokenMetadata.totalCollateral, 79.96 ether, "UNIRISE totalCollateral is invalid");
        assertEq(riseTokenMetadata.totalPendingFees, 0.04 ether, "UNIRISE totalPendingFees is invalid");
        assertEq(vault.getOutstandingDebt(address(unirise)), 672.676650 * 1e6, "UNIRISE outstandingDebt is invalid");
        assertEq(vault.getTotalAvailableCash(), (100_000 * 1e6) - (672.676650 * 1e6), "Total available cash is invalid");
    }

    /// @notice Make sure the user get the same amount of ETHRISE
    function test_SubsequentMintETHRISE() public {
        // Create new price oracle for the collateral
        CustomizableOracle oracle = new CustomizableOracle();
        oracle.setPrice(4_000 * 1e6); // Set ETH price to 4000 USDC

        // Create new swap contract, with artificial slippage 0.5%
        CustomizableSwap swap = new CustomizableSwap(address(oracle), 0.005 ether);
        // Fund the swap contract with WETH
        hevm.setWETHBalance(address(swap), 1_000 ether); // 1000 WETH token

        // Create new vault
        uint256 initialPrice = 100 * 1e6; // Initial price is 100 USDC
        (RiseTokenVault vault, RisedleERC20 ethrise) = createNewVault(oracle, swap, true, WETH_ADDRESS, initialPrice);

        // Create the first dummy user
        uint256 depositAmount = 1 ether; // 1 ETH
        uint256 userBalance = 2 ether; // 2 ETH
        DummyUser firstUser = new DummyUser(vault);
        // Transfer ETH to the firstUser
        sendETH(payable(address(firstUser)), userBalance);

        // First user mint the ETHRISE
        firstUser.mintWithETH(address(ethrise), depositAmount);

        // Validate the expected values
        // ETHRISE token should be transfered to the firstUser
        assertEq(IERC20(address(ethrise)).balanceOf(address(firstUser)), 39.7602000 ether, "firstUser: Wrong ETHRISE balance");

        // The ETH should be transfered from the user to the contract
        assertEq(address(firstUser).balance, userBalance - depositAmount, "firstUser: ETH is not transfered");
        assertEq(IERC20(WETH_ADDRESS).balanceOf(address(vault)), 1.999 ether, "firstUser: WETH token is not transfered to the contract"); // Deposit from user + swapped amount

        // Make sure the ETHRISE token vault states is correct
        RiseTokenVault.RiseTokenMetadata memory riseTokenMetadata = vault.getMetadata(address(ethrise));

        // Make sure the totalCollateral and totalPendingFees is correct
        assertEq(riseTokenMetadata.totalCollateral, 1.999 ether, "firstUser: ETHRISE total collateral is incorrect"); // 2x collateralAmount + fees
        assertEq(riseTokenMetadata.totalPendingFees, 0.001 ether, "firstUser: ETHRISE total pending fees is incorrect"); // 0.1% from deposit amount

        // Make sure the totalDebt of the ETHRISE token is correct
        assertEq(vault.getOutstandingDebt(address(ethrise)), 4015.98 * 1e6, "firstUser: ETHRISE borrow amount is incorrect"); // Bought 4000 USDC with ~0.5% slippage

        // Make sure the total available cash is correct
        assertEq(vault.getTotalAvailableCash(), (100_000 * 1e6) - (4015.98 * 1e6), "firstUser: Total available cash is invalid");

        // Make sure the NAV doesn't change
        assertEq(vault.getNAV(address(ethrise)), initialPrice);

        // ! NEXT MINTING
        // Second user with same deposit amount should have the same amount of minted token
        DummyUser secondUser = new DummyUser(vault);
        sendETH(payable(address(secondUser)), userBalance);
        secondUser.mintWithETH(address(ethrise), depositAmount);
        assertEq(IERC20(address(ethrise)).balanceOf(address(secondUser)), 39.7602000 ether, "secondUser: Wrong ETHRISE balance");

        // ! NEXT MINTING
        // Third user, collateral price go up, nav go up, should receive less amount of UNIRISE token
        oracle.setPrice(4_400 * 1e6);
        assertEq(vault.getNAV(address(ethrise)), 120100502, "thirdUser: NAV invalid"); // ~120 USDC
        DummyUser thirdUser = new DummyUser(vault);
        sendETH(payable(address(thirdUser)), userBalance);
        thirdUser.mintWithETH(address(ethrise), depositAmount);
        assertEq(IERC20(address(ethrise)).balanceOf(address(thirdUser)), 36416350699350115955, "thirdUser: Wrong ETHRISE balance");

        // ! NEXT Minting
        // Fourth user, collateral price go down, nav go down, should receive more amount of ETHRISE token
        oracle.setPrice(4_200 * 1e6);
        assertEq(vault.getNAV(address(ethrise)), 109760382, "fourthUser: NAV invalid"); // ~109 USDC
        DummyUser fourthUser = new DummyUser(vault);
        sendETH(payable(address(fourthUser)), userBalance);
        fourthUser.mintWithETH(address(ethrise), depositAmount);
        assertEq(IERC20(address(ethrise)).balanceOf(address(fourthUser)), 38035773235555976836, "fourthUser: Wrong ETHRISE balance");

        // Validate the ETHRISE token states
        riseTokenMetadata = vault.getMetadata(address(ethrise));
        assertEq(riseTokenMetadata.totalCollateral, 7.99600 ether, "ETHRISE totalCollateral is invalid");
        assertEq(riseTokenMetadata.totalPendingFees, 0.004 ether, "ETHRISE totalPendingFees is invalid");
        assertEq(vault.getOutstandingDebt(address(ethrise)), 16666.317000 * 1e6, "ETHRISE outstandingDebt is invalid");
        assertEq(vault.getTotalAvailableCash(), (100_000 * 1e6) - (16666.317000 * 1e6), "Total available cash is invalid");
    }

    /// @notice User mint token below the NAV price
    function test_MintRISETokenBelowNAVPrice() public {
        // Create new price oracles for the collateral
        CustomizableOracle ethOracle = new CustomizableOracle();
        ethOracle.setPrice(4_000 * 1e6); // Set ETH price to 4K USDC
        CustomizableOracle uniOracle = new CustomizableOracle();
        uniOracle.setPrice(15 * 1e6); // Set UNI price to 15 USDC

        // Create new swap contracts, with artificial slippage 0.5%
        CustomizableSwap swapUSDCToWETH = new CustomizableSwap(address(ethOracle), 0.005 ether);
        hevm.setWETHBalance(address(swapUSDCToWETH), 1_000 ether); // 1000 WETH token
        CustomizableSwap swapUSDCToUNI = new CustomizableSwap(address(uniOracle), 0.005 ether);
        hevm.setUNIBalance(address(swapUSDCToUNI), 1_000_000 ether); // 1M UNI token

        // Create new vaults for ETHRISE & UNIRISE
        uint256 ethriseInitialPrice = 100 * 1e6; // Initial price is 100 USDC
        uint256 uniriseInitialPrice = 10 * 1e6; // Initial price is 15 USDC
        (RiseTokenVault ethriseVault, RisedleERC20 ethrise) = createNewVault(ethOracle, swapUSDCToWETH, true, WETH_ADDRESS, ethriseInitialPrice);
        (RiseTokenVault uniriseVault, RisedleERC20 unirise) = createNewVault(uniOracle, swapUSDCToUNI, false, UNI_ADDRESS, uniriseInitialPrice);

        // Create the dummy users
        DummyUser ethriseUser = new DummyUser(ethriseVault);
        sendETH(payable(address(ethriseUser)), 0.02 ether);
        DummyUser uniriseUser = new DummyUser(uniriseVault);
        hevm.setUNIBalance(address(uniriseUser), 0.5 ether);

        // Mint RISE token with deposit below nav price
        ethriseUser.mintWithETH(address(ethrise), 0.02 ether);
        uniriseUser.mintWithERC20(address(unirise), 0.5 ether);

        // Validate
        assertEq(ethrise.balanceOf(address(ethriseUser)), 0.7952040 ether);
        assertEq(unirise.balanceOf(address(uniriseUser)), 0.7455038 ether);
    }

    /// @notice User mint token equal to the NAV price
    function test_MintRISETokenEqualNAVPrice() public {
        // Create new price oracles for the collateral
        CustomizableOracle ethOracle = new CustomizableOracle();
        ethOracle.setPrice(4_000 * 1e6); // Set ETH price to 4K USDC
        CustomizableOracle uniOracle = new CustomizableOracle();
        uniOracle.setPrice(10 * 1e6); // Set UNI price to 10 USDC

        // Create new swap contracts, with artificial slippage 0.5%
        CustomizableSwap swapUSDCToWETH = new CustomizableSwap(address(ethOracle), 0.005 ether);
        hevm.setWETHBalance(address(swapUSDCToWETH), 1_000 ether); // 1000 WETH token
        CustomizableSwap swapUSDCToUNI = new CustomizableSwap(address(uniOracle), 0.005 ether);
        hevm.setUNIBalance(address(swapUSDCToUNI), 1_000_000 ether); // 1M UNI token

        // Create new vaults for ETHRISE & UNIRISE
        uint256 ethriseInitialPrice = 100 * 1e6; // Initial price is 100 USDC
        uint256 uniriseInitialPrice = 10 * 1e6; // Initial price is 10 USDC
        (RiseTokenVault ethriseVault, RisedleERC20 ethrise) = createNewVault(ethOracle, swapUSDCToWETH, true, WETH_ADDRESS, ethriseInitialPrice);
        (RiseTokenVault uniriseVault, RisedleERC20 unirise) = createNewVault(uniOracle, swapUSDCToUNI, false, UNI_ADDRESS, uniriseInitialPrice);

        // Create the dummy users
        DummyUser ethriseUser = new DummyUser(ethriseVault);
        sendETH(payable(address(ethriseUser)), 0.025 ether);
        DummyUser uniriseUser = new DummyUser(uniriseVault);
        hevm.setUNIBalance(address(uniriseUser), 1 ether);

        // Mint RISE token with deposit below nav price
        ethriseUser.mintWithETH(address(ethrise), 0.025 ether);
        uniriseUser.mintWithERC20(address(unirise), 1 ether);

        // Validate
        assertEq(ethrise.balanceOf(address(ethriseUser)), 0.9940050 ether);
        assertEq(unirise.balanceOf(address(uniriseUser)), 0.9940050 ether);
    }

    // Leverage ratio behaviours
    // 1. When collateral price go up:
    //    - nav go up
    //    - leverage ratio go down
    //    - when rebalacne executed:
    //        - the leverage ratio should be increased
    //        - totalCollateral should be increased
    //        - totalDebt should be increased
    // 2. When collateral price go down:
    //    - nav go down
    //    - leverage ratio go up
    //    - when rebalacne executed:
    //        - the leverage ratio should be decreased
    //        - totalCollateral should be descreased
    //        - totalDebt should be decreased
    //
    // Rebalancing rules:
    // 1. When leverage ratio x < 1.7: leveraging up
    // 2. When leverage ratio x > 3: leveraging down
    // 3. When leverage ratio 1.7 < x < 3: revert, dont do anything

    function test_ETHRISELeverageUp() public {
        // Create new price oracles for the collateral
        CustomizableOracle oracle = new CustomizableOracle();
        oracle.setPrice(4_000 * 1e6); // Set ETH price to 4K USDC

        // Create new swap contracts, with artificial slippage 0.5%
        CustomizableSwap swapContract = new CustomizableSwap(address(oracle), 0.005 ether);
        hevm.setWETHBalance(address(swapContract), 1_000_000 ether); // 1_000_000 WETH token

        // Create new vaults for ETHRISE
        uint256 initialPrice = 100 * 1e6; // Initial price is 100 USDC
        (RiseTokenVault vault, RisedleERC20 ethrise) = createNewVault(oracle, swapContract, true, WETH_ADDRESS, initialPrice);

        // Create the dummy users
        DummyUser user = new DummyUser(vault);
        sendETH(payable(address(user)), 1 ether);

        // Mint ETHRISE
        user.mintWithETH(address(ethrise), 1 ether);

        // Initial leverage ratio is 2.010050251X
        assertEq(vault.getLeverageRatioInEther(address(ethrise)), 2010050250000000000);

        // Set ETH price to go up, then leverage ratio will go down
        oracle.setPrice(4_900 * 1e6);

        // Validate NAV and leverage ratio
        assertEq(vault.getNAV(address(ethrise)), 145226130);
        assertEq(vault.getLeverageRatioInEther(address(ethrise)), 1695501732367308830); // 1.69x

        // Execute the rebalance
        vault.rebalance(address(ethrise));

        // The nav should not change
        assertEq(vault.getNAV(address(ethrise)), 145008291);

        // The leverage ratio should change
        assertEq(vault.getLeverageRatioInEther(address(ethrise)), 1998499478902209805); // 1.99x

        // The ETHRISE debt should be increased
        assertEq(vault.getOutstandingDebt(address(ethrise)), 5756907321);
    }

    function testFail_ETHRISELeverageUpFailedWhenHighSlippage() public {
        // Create new price oracles for the collateral
        CustomizableOracle oracle = new CustomizableOracle();
        oracle.setPrice(4_000 * 1e6); // Set ETH price to 4K USDC

        // Create new swap contracts, with artificial slippage 10%
        CustomizableSwap swapUSDCToWETH = new CustomizableSwap(address(oracle), 0.1 ether);
        hevm.setWETHBalance(address(swapUSDCToWETH), 1_000_000 ether); // 1_000_000 WETH token

        // Create new vaults for ETHRISE
        uint256 initialPrice = 100 * 1e6; // Initial price is 100 USDC
        (RiseTokenVault vault, RisedleERC20 ethrise) = createNewVault(oracle, swapUSDCToWETH, true, WETH_ADDRESS, initialPrice);

        // Create the dummy users
        DummyUser user = new DummyUser(vault);
        sendETH(payable(address(user)), 1 ether);

        // Mint ETHRISE
        user.mintWithETH(address(ethrise), 1 ether);

        // Initial leverage ratio is 2.010050251X
        assertEq(vault.getLeverageRatioInEther(address(ethrise)), 2010050250000000000);

        // Set ETH price to go up, then leverage ratio will go down
        oracle.setPrice(4_900 * 1e6);

        // Validate NAV and leverage ratio
        assertEq(vault.getNAV(address(ethrise)), 145226130);
        assertEq(vault.getLeverageRatioInEther(address(ethrise)), 1695501732367308830); // 1.69x

        // Execute the rebalance; Should be failed with high slippage
        vault.rebalance(address(ethrise));
    }

    function test_ERC20RISELeverageUp() public {
        // Create new price oracles for the collateral
        CustomizableOracle oracle = new CustomizableOracle();
        oracle.setPrice(15 * 1e6); // Set UNI price to 15 USDC

        // Create new swap contracts, with artificial slippage 0.5%
        CustomizableSwap swapContract = new CustomizableSwap(address(oracle), 0.005 ether);
        hevm.setUNIBalance(address(swapContract), 1_000_000 ether); // 1_000_000 UNI token

        // Create new vaults for UNIRISE
        uint256 initialPrice = 10 * 1e6; // Initial price is 10 USDC
        (RiseTokenVault vault, RisedleERC20 unirise) = createNewVault(oracle, swapContract, false, UNI_ADDRESS, initialPrice);

        // Create the dummy users
        DummyUser user = new DummyUser(vault);
        hevm.setUNIBalance(address(user), 10 ether); //

        // Mint UNIRISE
        user.mintWithERC20(address(unirise), 10 ether); // Mint UNIRISE with 10 UNI

        // Initial leverage ratio is 2.010050251X
        assertEq(vault.getLeverageRatioInEther(address(unirise)), 2010050200000000000);

        // Set UNI price to go up, then leverage ratio will go down
        oracle.setPrice(18.4 * 1e6);

        // Validate NAV and leverage ratio
        assertEq(vault.getNAV(address(unirise)), 14556114);
        assertEq(vault.getLeverageRatioInEther(address(unirise)), 1693900995828969187); // 1.69x

        // Execute the rebalance
        vault.rebalance(address(unirise));

        // The nav should not change
        assertEq(vault.getNAV(address(unirise)), 14534280);

        // The leverage ratio should change
        assertEq(vault.getLeverageRatioInEther(address(unirise)), 1996896303084844932); // 1.99x

        // The UNIRISE debt should be increased
        assertEq(vault.getOutstandingDebt(address(unirise)), 216034624);
    }

    function testFail_ERC20RISELeverageUpFailedWhenHighSlippage() public {
        // Create new price oracles for the collateral
        CustomizableOracle oracle = new CustomizableOracle();
        oracle.setPrice(15 * 1e6); // Set UNI price to 15 USDC

        // Create new swap contracts, with artificial slippage 10%
        CustomizableSwap swapContract = new CustomizableSwap(address(oracle), 0.1 ether);
        hevm.setUNIBalance(address(swapContract), 1_000_000 ether); // 1_000_000 UNI token

        // Create new vaults for UNIRISE
        uint256 initialPrice = 10 * 1e6; // Initial price is 10 USDC
        (RiseTokenVault vault, RisedleERC20 unirise) = createNewVault(oracle, swapContract, false, UNI_ADDRESS, initialPrice);

        // Create the dummy users
        DummyUser user = new DummyUser(vault);
        hevm.setUNIBalance(address(user), 10 ether); //

        // Mint UNIRISE
        user.mintWithERC20(address(unirise), 10 ether); // Mint UNIRISE with 10 UNI

        // Initial leverage ratio is 2.010050251X
        assertEq(vault.getLeverageRatioInEther(address(unirise)), 2010050200000000000);

        // Set UNI price to go up, then leverage ratio will go down
        oracle.setPrice(18.4 * 1e6);

        // Validate NAV and leverage ratio
        assertEq(vault.getNAV(address(unirise)), 14556114);
        assertEq(vault.getLeverageRatioInEther(address(unirise)), 1693900995828969187); // 1.69x

        // Execute the rebalance; This should be failed
        vault.rebalance(address(unirise));
    }

    function test_ETHRISELeverageDown() public {
        // Create new price oracles for the collateral
        CustomizableOracle oracle = new CustomizableOracle();
        oracle.setPrice(4_000 * 1e6); // Set ETH price to 4K USDC

        // Create new swap contracts, with artificial slippage 0.5%
        CustomizableSwap swapContract = new CustomizableSwap(address(oracle), 0.005 ether);
        hevm.setUSDCBalance(address(swapContract), 1_000_000 * 1e6); // 1_000_000 USDC
        hevm.setWETHBalance(address(swapContract), 1_000_000 ether); // 1_000_000 WETH

        // Create new vaults for ETHRISE
        uint256 initialPrice = 100 * 1e6; // Initial price is 100 USDC
        (RiseTokenVault vault, RisedleERC20 ethrise) = createNewVault(oracle, swapContract, true, WETH_ADDRESS, initialPrice);

        // Create the dummy users
        DummyUser user = new DummyUser(vault);
        sendETH(payable(address(user)), 1 ether);

        // Mint ETHRISE
        user.mintWithETH(address(ethrise), 1 ether);

        // Initial leverage ratio is ~2X
        assertEq(vault.getLeverageRatioInEther(address(ethrise)), 2010050250000000000);

        // Set ETH price to go down, then leverage ratio will go up
        oracle.setPrice(3_000 * 1e6);

        // Validate NAV and leverage ratio
        assertEq(vault.getNAV(address(ethrise)), 49748743);
        assertEq(vault.getLeverageRatioInEther(address(ethrise)), 3030303057104377491); // 3x

        // Execute the rebalance
        vault.rebalance(address(ethrise));

        // The nav should not change
        assertEq(vault.getNAV(address(ethrise)), 49822995);

        // The leverage ratio should change
        assertEq(vault.getLeverageRatioInEther(address(ethrise)), 2727724356996202255); // 2.7x

        // The ETHRISE debt should be decreased
        assertEq(vault.getOutstandingDebt(address(ethrise)), 3422574009);
    }

    function testFail_ETHRISELeverageDownFailedWhenHighSlippage() public {
        // Create new price oracles for the collateral
        CustomizableOracle oracle = new CustomizableOracle();
        oracle.setPrice(4_000 * 1e6); // Set ETH price to 4K USDC

        // Create new swap contracts, with artificial slippage 10%
        CustomizableSwap swapContract = new CustomizableSwap(address(oracle), 0.1 ether);
        hevm.setUSDCBalance(address(swapContract), 1_000_000 * 1e6); // 1_000_000 USDC
        hevm.setWETHBalance(address(swapContract), 1_000_000 ether); // 1_000_000 WETH

        // Create new vaults for ETHRISE
        uint256 initialPrice = 100 * 1e6; // Initial price is 100 USDC
        (RiseTokenVault vault, RisedleERC20 ethrise) = createNewVault(oracle, swapContract, true, WETH_ADDRESS, initialPrice);

        // Create the dummy users
        DummyUser user = new DummyUser(vault);
        sendETH(payable(address(user)), 1 ether);

        // Mint ETHRISE
        user.mintWithETH(address(ethrise), 1 ether);

        // Set ETH price to go down, then leverage ratio will go up
        oracle.setPrice(3_000 * 1e6);

        // Execute the rebalance; should be failed due to high slippage
        vault.rebalance(address(ethrise));
    }

    function test_ERC20RISELeverageDown() public {
        // Create new price oracles for the collateral
        CustomizableOracle oracle = new CustomizableOracle();
        oracle.setPrice(15 * 1e6); // Set UNI price to 15 USDC

        // Create new swap contracts, with artificial slippage 0.5%
        CustomizableSwap swapContract = new CustomizableSwap(address(oracle), 0.005 ether);
        hevm.setUNIBalance(address(swapContract), 1_000_000 ether); // 1_000_000 UNI token
        hevm.setUSDCBalance(address(swapContract), 1_000_000 * 1e6); // 1_000_000 USDC token

        // Create new vaults for UNIRISE
        uint256 initialPrice = 10 * 1e6; // Initial price is 10 USDC
        (RiseTokenVault vault, RisedleERC20 unirise) = createNewVault(oracle, swapContract, false, UNI_ADDRESS, initialPrice);

        // Create the dummy users
        DummyUser user = new DummyUser(vault);
        hevm.setUNIBalance(address(user), 10 ether);

        // Mint UNIRISE
        user.mintWithERC20(address(unirise), 10 ether); // Mint UNIRISE with 10 UNI

        // Initial leverage ratio is 2.010050251X
        assertEq(vault.getLeverageRatioInEther(address(unirise)), 2010050200000000000);

        // Set UNI price to go down, then leverage ratio will go up
        oracle.setPrice(11.2 * 1e6);

        // Validate NAV and leverage ratio
        assertEq(vault.getNAV(address(unirise)), 4907873);
        assertEq(vault.getLeverageRatioInEther(address(unirise)), 3058020246245165675); // 3.1x

        // Execute the rebalance
        vault.rebalance(address(unirise));

        // The nav should not change
        assertEq(vault.getNAV(address(unirise)), 4915198);

        // The leverage ratio should change
        assertEq(vault.getLeverageRatioInEther(address(unirise)), 2755400291097123656); // 2.7x

        // The UNIRISE debt should be increased
        assertEq(vault.getOutstandingDebt(address(unirise)), 128646224);
    }

    function testFail_ERC20RISELeverageDownFailedWhenHighSlippage() public {
        // Create new price oracles for the collateral
        CustomizableOracle oracle = new CustomizableOracle();
        oracle.setPrice(15 * 1e6); // Set UNI price to 15 USDC

        // Create new swap contracts, with artificial slippage 10%
        CustomizableSwap swapContract = new CustomizableSwap(address(oracle), 0.1 ether);
        hevm.setUNIBalance(address(swapContract), 1_000_000 ether); // 1_000_000 UNI token
        hevm.setUSDCBalance(address(swapContract), 1_000_000 * 1e6); // 1_000_000 USDC token

        // Create new vaults for UNIRISE
        uint256 initialPrice = 10 * 1e6; // Initial price is 10 USDC
        (RiseTokenVault vault, RisedleERC20 unirise) = createNewVault(oracle, swapContract, false, UNI_ADDRESS, initialPrice);

        // Create the dummy users
        DummyUser user = new DummyUser(vault);
        hevm.setUNIBalance(address(user), 10 ether);

        // Mint UNIRISE
        user.mintWithERC20(address(unirise), 10 ether); // Mint UNIRISE with 10 UNI

        // Set UNI price to go down, then leverage ratio will go up
        oracle.setPrice(11.2 * 1e6);

        // Execute the rebalance; This should be failed
        vault.rebalance(address(unirise));
    }

    function testFail_ETHRISERebalanceInRangeShouldBeReverted() public {
        // Create new price oracles for the collateral
        CustomizableOracle oracle = new CustomizableOracle();
        oracle.setPrice(15 * 1e6); // Set UNI price to 15 USDC

        // Create new swap contracts, with artificial slippage 0.05%
        CustomizableSwap swapContract = new CustomizableSwap(address(oracle), 0.005 ether);
        hevm.setUNIBalance(address(swapContract), 1_000_000 ether); // 1_000_000 UNI token
        hevm.setUSDCBalance(address(swapContract), 1_000_000 * 1e6); // 1_000_000 USDC token

        // Create new vaults for UNIRISE
        uint256 initialPrice = 10 * 1e6; // Initial price is 10 USDC
        (RiseTokenVault vault, RisedleERC20 unirise) = createNewVault(oracle, swapContract, false, UNI_ADDRESS, initialPrice);

        // Create the dummy users
        DummyUser user = new DummyUser(vault);
        hevm.setUNIBalance(address(user), 10 ether);

        // Mint UNIRISE
        user.mintWithERC20(address(unirise), 10 ether); // Mint UNIRISE with 10 UNI

        // Execute the rebalance; This should be failed
        vault.rebalance(address(unirise));
    }

    function testFail_ERC20RISERebalanceInRangeShouldBeReverted() public {
        // Create new price oracles for the collateral
        CustomizableOracle oracle = new CustomizableOracle();
        oracle.setPrice(15 * 1e6); // Set UNI price to 15 USDC

        // Create new swap contracts, with artificial slippage 0.5%
        CustomizableSwap swapContract = new CustomizableSwap(address(oracle), 0.005 ether);
        hevm.setUNIBalance(address(swapContract), 1_000_000 ether); // 1_000_000 UNI token
        hevm.setUSDCBalance(address(swapContract), 1_000_000 * 1e6); // 1_000_000 USDC token

        // Create new vaults for UNIRISE
        uint256 initialPrice = 10 * 1e6; // Initial price is 10 USDC
        (RiseTokenVault vault, RisedleERC20 unirise) = createNewVault(oracle, swapContract, false, UNI_ADDRESS, initialPrice);

        // Create the dummy users
        DummyUser user = new DummyUser(vault);
        hevm.setUNIBalance(address(user), 10 ether);

        // Mint UNIRISE
        user.mintWithERC20(address(unirise), 10 ether); // Mint UNIRISE with 10 UNI

        // Execute the rebalance
        vault.rebalance(address(unirise));
    }

    // Test Redeem
    // mint, no price change, then redeem, User should receive their collateral back minus 0.2% fee
    // mint, price go up, then redeem, User should receive their collateral back plus their profit
    // mint, price go down, then redeem, User should receive less than their collateral
}
