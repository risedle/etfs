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
import {USDC_ADDRESS, CHAINLINK_USDC_USD, UNISWAPV3_SWAP_ROUTER} from "chain/Constants.sol";

import {Hevm} from "./Hevm.sol";
import {Risedle} from "../Risedle.sol";

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
}
