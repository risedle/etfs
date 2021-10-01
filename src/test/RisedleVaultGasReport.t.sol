// SPDX-License-Identifier: GPL-3.0-or-later

// Risedle's Vault Internal Test
// Test & validate all internal functionalities

pragma solidity ^0.8.7;
pragma experimental ABIEncoderV2;

import "lib/ds-test/src/test.sol";

import {RisedleVault} from "../RisedleVault.sol";

// chain/* is replaced by DAPP_REMAPPINGS at compile time,
// this allow us to use custom address on specific chain
// See .dapprc
import {USDT_ADDRESS} from "chain/Constants.sol";

// Set Risedle's Vault properties
string constant vaultTokenName = "Risedle USDT Vault";
string constant vaultTokenSymbol = "rvUSDT";
address constant vaultUnderlying = USDT_ADDRESS;
uint8 constant vaultUnderlyingDecimals = 6;

contract RisedleVaultGasReportTest is
    DSTest,
    RisedleVault(
        vaultTokenName,
        vaultTokenSymbol,
        vaultUnderlying,
        vaultUnderlyingDecimals
    )
{
    /// @notice Report gas usage of getTotalAvailableCash
    function test_GasGetTotalAvailableCash() public view {
        getTotalAvailableCash();
    }

    /// @notice Report gas usage of getUtilizationRateInEther
    function test_GasGetUtilizationRateInEther() public view {
        getUtilizationRateInEther(0, 0);
    }

    /// @notice Report gas usage of getBorrowRatePerSecondInEther above optimal
    function test_GasGetBorrowRatePerSecondInEtherAboveOptimal() public view {
        getBorrowRatePerSecondInEther(0.97 ether);
    }

    /// @notice Report gas usage of getBorrowRatePerSecondInEther below optimal
    function test_GasGetBorrowRatePerSecondInEtherBelowOptimal() public view {
        getBorrowRatePerSecondInEther(0.5 ether);
    }

    /// @notice Report gas usage of getInterestAmount
    function test_GasGetInterestAmount() public view {
        getInterestAmount(0.5 ether, 0.00001 ether, 3 hours);
    }

    /// @notice Report gas usage of accrueInterest
    function test_GasAccrueInterest() public {
        accrueInterest();
    }
}
