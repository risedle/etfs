// SPDX-License-Identifier: GPL-3.0-or-later

// Rise Token Vault Access control test
// Make sure the ownership is working as expected
pragma solidity >=0.8.9;
pragma experimental ABIEncoderV2;

import "lib/ds-test/src/test.sol";
import { Hevm } from "./Hevm.sol";
import { RisedleVault } from "../RisedleVault.sol";
import { USDC_ADDRESS } from "chain/Constants.sol";

contract RisedleVaultAccessControlTest is DSTest {
    Hevm hevm;

    /// @notice Run the test setup
    function setUp() public {
        hevm = new Hevm();
    }

    /// @notice Make sure non-owner cannot set vault parameters
    function testFail_NonOwnerCannotSetVaultParameters() public {
        RisedleVault vault = new RisedleVault("Risedle Vault", "rvUSDC", USDC_ADDRESS, address(this));

        // Transfer ownership
        address newOwner = hevm.addr(1);
        vault.transferOwnership(newOwner);

        // Try set vault; should be failed
        vault.setVaultParameters(0, 0, 0, 0, 0);
    }

    /// @notice Make sure owner can set vault parameters
    function test_OwnerCanSetVaultParameters() public {
        RisedleVault vault = new RisedleVault("Risedle Vault", "rvUSDC", USDC_ADDRESS, address(this));

        // Set vault
        vault.setVaultParameters(0, 0, 0, 0, 0);

        // Get the params
        (uint256 u, uint256 i1, uint256 i2, uint256 br, uint256 pr) = vault.getVaultParameters();
        assertEq(u, 0);
        assertEq(i1, 0);
        assertEq(i2, 0);
        assertEq(br, 0);
        assertEq(pr, 0);
    }

    /// @notice Make sure non-owner cannot set fee recipient
    function testFail_NonOwnerCannotSetFeeRecipient() public {
        RisedleVault vault = new RisedleVault("Risedle Vault", "rvUSDC", USDC_ADDRESS, address(this));

        // Transfer ownership
        address newOwner = hevm.addr(1);
        vault.transferOwnership(newOwner);

        // Try set fee recipient; should be failed
        address feeRecipient = hevm.addr(2);
        vault.setFeeRecipient(feeRecipient);
    }

    /// @notice Make sure owner can set vault parameters
    function test_OwnerCanSetFeeRecipient() public {
        RisedleVault vault = new RisedleVault("Risedle Vault", "rvUSDC", USDC_ADDRESS, address(this));

        address feeRecipient = hevm.addr(1);
        vault.setFeeRecipient(feeRecipient);

        assertEq(vault.FEE_RECIPIENT(), feeRecipient);
    }

    /// @notice Make sure non-owner cannot set max vault's total deposit
    function testFail_NonOwnerCannotSetMaxTotalDeposit() public {
        RisedleVault vault = new RisedleVault("Risedle Vault", "rvUSDC", USDC_ADDRESS, address(this));

        // Transfer ownership
        address newOwner = hevm.addr(1);
        vault.transferOwnership(newOwner);

        // Try set max total deposit; should be failed
        vault.setVaultMaxTotalDeposit(1_000_000 * 1e6);
    }

    /// @notice Make sure owner can set max total deposit
    function test_OwnerCanSetMaxTotalDeposit() public {
        RisedleVault vault = new RisedleVault("Risedle Vault", "rvUSDC", USDC_ADDRESS, address(this));
        vault.setVaultMaxTotalDeposit(1_000_000 * 1e6);
        assertEq(vault.maxTotalDeposit(), 1_000_000 * 1e6);
    }
}
