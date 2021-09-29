// SPDX-License-Identifier: GPL-3.0-or-later

// Risedle's ETF External Test
// Test & validate user/contract interaction with Risedle's ETF

import "lib/ds-test/src/test.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import {HEVM} from "./utils/HEVM.sol";
import {RisedleVault} from "../RisedleVault.sol";
import {RisedleETF} from "../RisedleETF.sol";

contract RisedleETFExternalTest is DSTest {
    address constant USDT_ADDRESS = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    IERC20 constant USDT = IERC20(USDT_ADDRESS);

    address constant WETH_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    IERC20 constant WETH = IERC20(WETH_ADDRESS);

    // HEVM
    HEVM hevm;

    /// @notice Run the test setup
    function setUp() public {
        hevm = new HEVM();
    }

    /// @notice Utility function to create new vault
    function createNewVault(address governor, address feeReceiver)
        internal
        returns (RisedleVault)
    {
        // Create new vault
        RisedleVault vault = new RisedleVault(
            "Risedle USDT Vault",
            "rvUSDT",
            USDT_ADDRESS,
            governor,
            feeReceiver
        );
        return vault;
    }

    /// @notice Utility function to create new ETF
    function createNewETF(
        address governor,
        address feeReceiver,
        uint256 initialPrice
    ) internal returns (RisedleETF) {
        // Create new ETF
        RisedleETF etf = new RisedleETF(
            "ETH 2x Leverage Risedle",
            "ETHRISE",
            WETH_ADDRESS,
            governor,
            feeReceiver,
            initialPrice
        );
    }

    /// @notice Make sure setVault can only called once
    function testFail_SetVaultOnlyCalledOnce() public {
        // Set random address as governor and fee receiver
        address governor = hevm.addr(1);
        address feeReceiver = hevm.addr(2);

        // Create new vault
        RisedleVault vault = createNewVault(governor, feeReceiver);

        // Create new ETF
        uint256 initialPrice = 100 * 1e6; // 100 USDT
        RisedleETF etf = createNewETF(governor, feeReceiver, initialPrice);

        // Run the setVault function as public user
        etf.setVault(address(vault));

        // Run once again, it should be failed
        etf.setVault(address(vault));
    }
}
