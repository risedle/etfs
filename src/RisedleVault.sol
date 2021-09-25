// SPDX-License-Identifier: GPL-3.0-or-later

// Risedle's Vault Contract
// The money market protocol that powers Risedle ETFs.
//
// The interest rate model is available here: https://observablehq.com/@pyk/ethrise
// It uses wad, a decimal number with 18 digits of precision, to represent the
// interest rate.
//
// I wrote this for ETHOnline Hackathon 2021. Enjoy.

// Copyright (c) 2021 Bayu - All rights reserved
// github: pyk

pragma solidity ^0.8.7;
pragma experimental ABIEncoderV2;

import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessControl} from "lib/openzeppelin-contracts/contracts/access/AccessControl.sol";
import {DSMath} from "lib/meth/src/math.sol";

/// @title Risedle's Vault
contract RisedleVault is ERC20, AccessControl, DSMath {
    using SafeERC20 for IERC20;

    /// @notice Only valid borrower can borrow and repay underlying assets
    bytes32 public constant BORROWER_ROLE = keccak256("BORROWER_ROLE");

    /// @notice The underlying assets address contract (ERC20)
    address public immutable underlying;

    /// @notice The vault's admin address
    address public immutable admin;

    /// @notice The total amount of borrowed assets
    uint256 public totalBorrowed;

    /// @notice The total amount of reserved assets
    uint256 public totalReserved;

    /// @notice Optimal utilization rate stored in wad
    ///         For example, 90% or 0.9 is equal to
    uint256 public OPTIMAL_UTILIZATION_RATE_WAD;

    /// @notice Interest slope 1, stored in wad
    uint256 public INTEREST_SLOPE_1_WAD;

    /// @notice Interest slop 2, stored in wad
    uint256 public INTEREST_SLOPE_2_WAD;

    /// @notice Number of seconds in a year, stored in wad
    uint256 public immutable SECONDS_PER_YEAR_WAD = 31536000000000000000000000;

    /// @notice 1.0 stored as wad
    uint256 public immutable ONE_WAD = 1000000000000000000;

    /// @notice Maximum borrow rate per second
    uint256 public immutable MAX_BORROW_RATE_PER_SECOND_WAD = 50735667174; // Approx 393% APY

    /// @notice Timestammp that interest was last accrued at
    uint256 public lastTimestampInterestAccrued;

    /**
     * @notice Contruct new vault
     * @param name The vault's token name
     * @param symbol The vault's token symbol
     * @param underlying_ The ERC20 contract address of underlying asset
     * @param admin_ The vault's admin address
     */
    constructor(
        string memory name,
        string memory symbol,
        address underlying_,
        address admin_
    ) ERC20(name, symbol) {
        // Sanity check
        IERC20(underlying_).totalSupply();

        // Set underlying asset contract address
        underlying = underlying_;

        // Setup admin role
        admin = admin_;
        _setupRole(DEFAULT_ADMIN_ROLE, admin_);

        // Set initial interest rate model parameters
        // See visualization here: https://observablehq.com/@pyk/ethrise
        OPTIMAL_UTILIZATION_RATE_WAD = 900000000000000000; // 90% utilization
        INTEREST_SLOPE_1_WAD = 200000000000000000; // 20% slope 1
        INTEREST_SLOPE_2_WAD = 600000000000000000; // 60% slope 2
    }

    /**
     * @notice Similar to cToken decimals
     * @dev https://docs.openzeppelin.com/contracts/4.x/erc20#a-note-on-decimals
     */
    function decimals() public view virtual override returns (uint8) {
        return 8;
    }

    /**
     * @notice grantAsBorrower grants account access to borrow the underlying asset of RisedleUSD
     * @dev Only admin can call this function
     * @param account The contract address granted access to borrow
     */
    function grantAsBorrower(address account)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _setupRole(BORROWER_ROLE, account);
    }

    /**
     * @notice isBorrower returns true if account is borrower
     * @param account The contract address
     */
    function isBorrower(address account) public view returns (bool) {
        return hasRole(BORROWER_ROLE, account);
    }

    /**
     * @notice getAvailableCash returns the total amount of underlying asset
     *         that available to borrow
     * @return The quantity of underlying assets owned by this contract
     */
    function getAvailableCash() internal view returns (uint256) {
        IERC20 underlyingToken = IERC20(underlying);
        return underlyingToken.balanceOf(address(this));
    }

    /**
     * @notice getUtilizationRateWad calculates the utilization rate of
     *         the lending pool. If there is an overflow or underflow, simply
     *         return the value with invalid=true.
     * @param cash The amount of cash available to borrow in the lending pool
     * @param borrowed The amount of borrowed asset in the lending pool
     * @param reserved The amount of reserved asset in the lending pool
     * @return invalid True if overflow/underflow and reserved amount too large
     * @return rateWad The utilization rate as wad, valid if invalid=false
     */
    function getUtilizationRateWad(
        uint256 cash,
        uint256 borrowed,
        uint256 reserved
    ) public pure returns (bool invalid, uint256 rateWad) {
        // Utilization rate is 0% when there is no borrowed asset
        if (borrowed == 0) {
            return (false, 0);
        }
        // Utilization rate is 100% when there is no cash available
        if (cash == 0 && borrowed > 0) {
            return (false, ONE_WAD);
        }

        // Ut = Bt/(Ct + Bt - Rt)
        // Perform safe arithmetic with overflow/underflow flagging
        (invalid, rateWad) = madd(cash, borrowed);
        if (invalid) return (invalid, rateWad);
        (invalid, rateWad) = msub(rateWad, reserved);
        if (invalid) return (invalid, rateWad);
        (invalid, rateWad) = mwdiv(borrowed, rateWad);
    }

    /**
     * @notice getBorrowRatePerSecondWad calculates the borrow rate per second.
     * @param utilizationRateWad The current utilization rate, stored as wad
     * @return The borrow rate as a wad
     */
    function getBorrowRatePerSecondWad(uint256 utilizationRateWad)
        internal
        view
        returns (uint256)
    {
        // Calculate the borrow rate
        if (utilizationRateWad <= OPTIMAL_UTILIZATION_RATE_WAD) {
            uint256 borrowRatePerYearWad = wmul(
                wdiv(utilizationRateWad, OPTIMAL_UTILIZATION_RATE_WAD),
                INTEREST_SLOPE_1_WAD
            );
            uint256 borrowRatePerSecondWad = wdiv(
                borrowRatePerYearWad,
                SECONDS_PER_YEAR_WAD
            );
            return borrowRatePerSecondWad;
        } else {
            uint256 borrowRatePerYearWad = add(
                INTEREST_SLOPE_1_WAD,
                wmul(
                    wdiv(
                        sub(utilizationRateWad, OPTIMAL_UTILIZATION_RATE_WAD),
                        sub(ONE_WAD, utilizationRateWad)
                    ),
                    INTEREST_SLOPE_2_WAD
                )
            );
            uint256 borrowRatePerSecondWad = wdiv(
                borrowRatePerYearWad,
                SECONDS_PER_YEAR_WAD
            );
            // Make sure the borrow rate is not absurd high
            uint256 cappedBorrowRateWad = min(
                borrowRatePerSecondWad,
                MAX_BORROW_RATE_PER_SECOND_WAD
            );
            return cappedBorrowRateWad;
        }
    }

    /**
     * @notice accrueInterest accrues interest to totalBorrowed and totalReserved
     * @dev This calculates interest accrued from the last checkpointed timestamp
     *   up to the current timestamp and writes new checkpoint to storage.
     */
    function accrueInterest() public {
        // Get the current timestamp & last timestamp accrued
        uint256 currentTimestamp = block.timestamp;
        uint256 previousTimestamp = lastTimestampInterestAccrued;

        // If currentTimestamp and previousTimestamp is similar then return
        if (currentTimestamp == previousTimestamp) {
            return;
        }

        // Get the current available cash, total borrowed and total reserved asset
        uint256 currentAvailableCash = getAvailableCash();
        uint256 currentTotalBorrowed = totalBorrowed;
        uint256 currentTotalReserved = totalReserved;

        // Get the current borrow rate;
        // uint256 utilizationRateWad = getUtilizationRateWad(
        //     currentAvailableCash,
        //     currentTotalBorrowed,
        //     currentTotalReserved
        // );
        // uint256 borrowRatePerSecondWad = getBorrowRatePerSecondWad(
        //     utilizationRateWad
        // );
    }
}
