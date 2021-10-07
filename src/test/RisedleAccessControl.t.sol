// SPDX-License-Identifier: GPL-3.0-or-later

// Risedle's Vault Access Control Test
// Make sure the Governor ownership is working as expected

pragma solidity ^0.8.7;
pragma experimental ABIEncoderV2;

import "lib/ds-test/src/test.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

// chain/* is replaced by DAPP_REMAPPINGS at compile time,
// this allow us to use custom address on specific chain
// See .dapprc
import {USDT_ADDRESS, WETH_ADDRESS, CHAINLINK_ETH_USD} from "chain/Constants.sol";

import {Hevm} from "./Hevm.sol";
import {Risedle} from "../Risedle.sol";

/// @notice Dummy contract to simulate random account to execute collect fee
contract FeeCollector {
    Risedle _vault;

    constructor(Risedle vault) {
        _vault = vault;
    }

    function collectPendingFees() public {
        _vault.collectPendingFees();
    }
}

contract RisedleAccessControlTest is DSTest {
    // Test utils
    IERC20 constant USDT = IERC20(USDT_ADDRESS);
    Hevm hevm;

    /// @notice Run the test setup
    function setUp() public {
        hevm = new Hevm();
    }

    /// @notice Utility function to create new vault
    function createNewVault() internal returns (Risedle) {
        // Create new vault
        Risedle vault = new Risedle(
            "Risedle USDT Vault",
            "rvUSDT",
            USDT_ADDRESS,
            6
        );
        return vault;
    }

    /// @notice Make sure the governor is properly set
    function test_GovernorIsProperlySet() public {
        // Create new vault
        Risedle vault = createNewVault();

        // The governor is the one who create/deploy the vault
        assertEq(vault.owner(), address(this));
    }

    /// @notice Make sure non-governor account cannot set vault parameters
    function testFail_NonGovernorCannotSetVaultParameters() public {
        address governor = hevm.addr(2); // Use random address as governor
        Risedle vault = createNewVault();
        vault.transferOwnership(governor);

        // Make sure this is fail
        vault.setVaultParameters(
            0.1 ether,
            0.2 ether,
            0.3 ether,
            0.4 ether,
            0.1 ether
        );
    }

    /// @notice Make sure governor can update the vault parameters
    function test_GovernorCanSetVaultParameters() public {
        // This contract is the governor by default
        Risedle vault = createNewVault();

        // Update vault's parameters
        uint256 optimalUtilizationRate = 0.8 ether;
        uint256 slope1 = 0.4 ether;
        uint256 slope2 = 0.9 ether;
        uint256 maxBorrowRatePerSeconds = 0.7 ether;
        uint256 fee = 0.9 ether;
        vault.setVaultParameters(
            optimalUtilizationRate,
            slope1,
            slope2,
            maxBorrowRatePerSeconds,
            fee
        );

        // Make sure the parameters is updated
        (uint256 u, uint256 s1, uint256 s2, uint256 mr, uint256 f) = vault
            .getVaultParameters();

        assertEq(u, optimalUtilizationRate);
        assertEq(s1, slope1);
        assertEq(s2, slope2);
        assertEq(mr, maxBorrowRatePerSeconds);
        assertEq(f, fee);
    }

    /// @notice Make sure non-governor account cannot change the fee recipient
    function testFail_NonGovernorCannotSetFeeRecipientAddress() public {
        // Set governor
        address governor = hevm.addr(2);
        Risedle vault = createNewVault();
        vault.transferOwnership(governor);

        // Make sure it fails
        vault.setFeeRecipient(hevm.addr(3));
    }

    /// @notice Make sure governor can update the fee recipient
    function test_GovernorCanSetFeeRecipientAddress() public {
        // Set the new fee recipient
        address newReceiver = hevm.addr(2);

        // Create new vault
        Risedle vault = createNewVault();

        // Update the fee recipient
        vault.setFeeRecipient(newReceiver);

        // If we are then the operation is succeed
        // Need to make sure via other external test tho
        assertTrue(true);
    }

    /// @notice Test accrue interest as public
    function test_AnyoneCanAccrueInterest() public {
        // Create new vault
        address governor = hevm.addr(2);
        Risedle vault = createNewVault();
        vault.transferOwnership(governor);

        // Set the timestamp
        uint256 previousTimestamp = block.timestamp;
        hevm.warp(previousTimestamp);

        // Public accrue interest
        vault.accrueInterest();

        // Make sure is not failed
        assertTrue(true);
    }

    /// @notice Only governance can create new ETF
    function testFail_NonGovernanceCannotCreateNewETF() public {
        // Create new vault
        address governance = hevm.addr(2);
        Risedle vault = createNewVault();
        vault.transferOwnership(governance);

        // Make sure this action is failed
        vault.createNewETF(
            WETH_ADDRESS,
            CHAINLINK_ETH_USD,
            100 * 1e6,
            hevm.addr(2)
        );
    }

    /// @notice Governance can create new ETF
    function test_GovernanceCanCreateNewETF() public {
        // Create new vault as governance
        Risedle vault = createNewVault();

        // Create new ETF as governance
        uint256 initialPrice = 100 * 1e6; // 100 USDT
        address etfToken = hevm.addr(1); // Set random address
        vault.createNewETF(
            WETH_ADDRESS,
            CHAINLINK_ETH_USD,
            initialPrice,
            etfToken
        );

        // Get the ETF info
        Risedle.ETFInfo memory info = vault.getETFInfo(etfToken);

        // Make sure the info is correct
        assertEq(info.underlying, WETH_ADDRESS);
        assertEq(info.feed, CHAINLINK_ETH_USD);
        assertEq(info.initialPrice, initialPrice);
        assertEq(info.token, etfToken);
    }
}
