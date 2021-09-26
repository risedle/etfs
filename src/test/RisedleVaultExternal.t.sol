// SPDX-License-Identifier: GPL-3.0-or-later

// Risedle's Vault External Test
// Test & validate user/contract interaction with Risedle's Vault

pragma solidity ^0.8.7;
pragma experimental ABIEncoderV2;

import "lib/ds-test/src/test.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

import {HEVM} from "./utils/HEVM.sol";
import {RisedleVault} from "../RisedleVault.sol";

/// @notice Dummy contract to simulate the borrower
contract Borrower {

}

/// @notice Dummy contract to simulate the lender
contract Lender {
    using SafeERC20 for IERC20;

    // Vault
    RisedleVault private _vault;
    IERC20 underlying;

    constructor(RisedleVault vault) {
        _vault = vault;
        underlying = IERC20(vault.underlying());
    }

    /// @notice lender supply asset
    function lend(uint256 amount) public {
        // approve vault to spend the underlying asset
        underlying.safeApprove(address(_vault), type(uint256).max);
        // address usdtAddress = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
        // IERC20 USDT = IERC20(usdtAddress);
        // USDT.approve(address(_vault), amount);
        // USDT.approve(address(_vault), uint256((2**256) - 1));

        // Supply asset
        _vault.mint(amount);
    }
}

contract RisedleVaultExternalTest is DSTest {
    RisedleVault rvUSDT;
    address rvUSDTAdmin;
    HEVM hevm;

    function setUp() public {
        // Set this contract as admin
        rvUSDTAdmin = address(this);
        address usdtAddress = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
        rvUSDT = new RisedleVault(
            "Risedle USDT Vault",
            "rvUSDT",
            usdtAddress,
            rvUSDTAdmin
        );

        // Initialize new hevm
        hevm = new HEVM();
    }

    /// @notice Make sure the admin is properly set
    function test_AdminIsProperlySet() public {
        // Make sure the admin is set
        assertTrue(rvUSDT.hasRole(rvUSDT.DEFAULT_ADMIN_ROLE(), rvUSDTAdmin));

        // Check with non-admin address
        address nonAdmin = address(rvUSDT);
        assertFalse(rvUSDT.hasRole(rvUSDT.DEFAULT_ADMIN_ROLE(), nonAdmin));
    }

    /// @notice Make sure admin can grant borrower role
    function test_AdminCanGrantBorrower() public {
        // Create new borrower actor
        Borrower borrower = new Borrower();

        // Grant borrower
        rvUSDT.grantAsBorrower(address(borrower));

        // Make sure the role has been set
        assertTrue(rvUSDT.isBorrower(address(borrower)));

        // Even the admin itself is not borrower
        assertFalse(rvUSDT.isBorrower(rvUSDTAdmin));
    }

    /// @notice Make sure the lender can supply asset to the vault
    function test_LenderCanSupplyAssetToTheVault() public {
        // Create new vault
        rvUSDTAdmin = address(this); // Set this contract as admin
        address usdtAddress = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
        IERC20 USDT = IERC20(usdtAddress);
        RisedleVault vault = new RisedleVault(
            "Risedle USDT Vault",
            "rvUSDT",
            usdtAddress,
            rvUSDTAdmin
        );

        // Create new lender
        Lender lender = new Lender(vault);

        // Set the lender USDT balance
        uint256 amount = 1000 * 1e6; // 1000 USDT
        hevm.setUSDTBalance(address(lender), amount);
        uint256 lenderBalance = USDT.balanceOf(address(lender));
        assertEq(amount, lenderBalance);

        // Lender add supply to the vault
        lender.lend(amount);

        // Lender should receive the same amount of vault token
        uint256 lenderVaultTokenBalance = vault.balanceOf(address(lender));
        assertEq(lenderVaultTokenBalance, amount);

        // The vault should receive the USDT
        assertEq(USDT.balanceOf(address(vault)), amount);
    }
}
