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
    address public admin;

    /// @notice The total amount of borrowed assets in the vault
    uint256 public totalBorrowed;

    /// @notice The total amount of collected fees in the vault
    uint256 public totalCollectedFees;

    /// @notice Optimal utilization rate stored in wad
    ///         For example, 90% or 0.9 is equal to
    uint256 public OPTIMAL_UTILIZATION_RATE_WAD;

    /// @notice Interest slope 1, stored in wad
    uint256 public INTEREST_SLOPE_1_WAD;

    /// @notice Interest slop 2, stored in wad
    uint256 public INTEREST_SLOPE_2_WAD;

    /// @notice Number of seconds in a year, stored in wad
    uint256 public immutable SECONDS_PER_YEAR_WAD = 31536000000000000000000000;

    /// @notice 1.0 stored as wad, 1e18 precision
    uint256 public immutable ONE_WAD = 1000000000000000000;

    /// @notice Maximum borrow rate per second
    uint256 public immutable MAX_BORROW_RATE_PER_SECOND_WAD = 50735667174; // Approx 393% APY

    /// @notice Timestammp that interest was last accrued at
    uint256 public lastTimestampInterestAccrued;

    /// @notice Event emitted when the utulization rate is invalid
    event UtiliationRateInvalid(
        uint256 cash,
        uint256 borrowed,
        uint256 reserved,
        uint256 rate
    );

    /// @notice Event emitted when the borrow rate is invalid
    event BorrowRatePerSecondInvalid(uint256 utilizationRateWad);

    /// @notice Event emitted then failed to calculate the timestamp delta
    event TimestampDeltaInvalid(uint256 previous, uint256 current);

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
     *         the vault. If there is an overflow or underflow, simply
     *         return the value with invalid=true.
     * @return invalid True if overflow/underflow and reserved amount too large
     * @return rateWad The utilization rate as wad, valid if invalid=false
     */
    function getUtilizationRateWad()
        internal
        view
        returns (bool invalid, uint256 rateWad)
    {
        // Utilization Rate = (total borrowed) / (total borrowed + total available cash - total collected fees)
        // Get the current cash
        uint256 totalAvailableCash = getAvailableCash();

        // Utilization rate is 0% when there is no borrowed asset
        if (totalBorrowed == 0) {
            return (false, 0);
        }

        // Utilization rate is 100% when there is no cash available
        if (totalAvailableCash == 0 && totalBorrowed > 0) {
            return (false, ONE_WAD);
        }

        // Perform safe arithmetic with overflow/underflow flagging
        uint256 z; // temporary variable
        (invalid, z) = madd(totalAvailableCash, totalBorrowed);
        if (invalid) return (invalid, z);
        (invalid, z) = msub(z, totalCollectedFees);
        if (invalid) return (invalid, z);
        (invalid, rateWad) = mwdiv(totalBorrowed, z);
        // Capped rateWad
        rateWad = min(rateWad, ONE_WAD);
    }

    /**
     * @notice getBorrowRatePerSecondWad calculates the borrow rate per second.
     * @param utilizationRateWad The current utilization rate, stored as wad
     * @return invalid True if overflow/underflow and reserved amount too large
     * @return borrowRatePerSecondWad Borrow rate per second as Wad
     */
    function getBorrowRatePerSecondWad(uint256 utilizationRateWad)
        internal
        view
        returns (bool invalid, uint256 borrowRatePerSecondWad)
    {
        // utilizationRateWad should in range [0, 1e18], Otherwise return max borrow rate
        if (utilizationRateWad >= ONE_WAD)
            return (false, MAX_BORROW_RATE_PER_SECOND_WAD);

        // Calculate the borrow rate
        // See the formula here: https://observablehq.com/@pyk/ethrise
        if (utilizationRateWad <= OPTIMAL_UTILIZATION_RATE_WAD) {
            uint256 z; // temporary variable
            (invalid, z) = mwdiv(
                utilizationRateWad,
                OPTIMAL_UTILIZATION_RATE_WAD
            );
            if (invalid) return (invalid, z);
            (invalid, z) = mwmul(z, INTEREST_SLOPE_1_WAD); // Borrow rate per year
            if (invalid) return (invalid, z);
            (invalid, borrowRatePerSecondWad) = mwdiv(z, SECONDS_PER_YEAR_WAD);
            return (invalid, borrowRatePerSecondWad);
        } else {
            // temporary variables
            uint256 x;
            uint256 y;
            uint256 z;

            (invalid, x) = msub(
                utilizationRateWad,
                OPTIMAL_UTILIZATION_RATE_WAD
            );
            if (invalid) return (invalid, x);
            (invalid, y) = msub(ONE_WAD, utilizationRateWad);
            if (invalid) return (invalid, y);
            (invalid, z) = mwdiv(x, y);
            if (invalid) return (invalid, z);
            (invalid, z) = mwmul(z, INTEREST_SLOPE_2_WAD);
            if (invalid) return (invalid, z);
            (invalid, z) = madd(INTEREST_SLOPE_1_WAD, z); // Borrow rate per year
            if (invalid) return (invalid, z);
            (invalid, borrowRatePerSecondWad) = mwdiv(z, SECONDS_PER_YEAR_WAD);
            if (invalid) return (invalid, borrowRatePerSecondWad);
            // Make sure the borrow rate is not absurdly high
            uint256 cappedBorrowRatePerSecondWad = min(
                borrowRatePerSecondWad,
                MAX_BORROW_RATE_PER_SECOND_WAD
            );
            return (false, cappedBorrowRatePerSecondWad);
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
        // uint256 currentAvailableCash = getAvailableCash();
        // uint256 currentTotalBorrowed = totalBorrowed;
        // uint256 currentTotalReserved = totalReserved;

        // Get the current borrow rate;
        // bool invalid;
        // uint256 utilizationRateWad;
        // (invalid, utilizationRateWad) = getUtilizationRateWad(
        //     currentAvailableCash,
        //     currentTotalBorrowed,
        //     currentTotalReserved
        // );
        // // If utilization rate is invalid then emit UtilizationRateInvalid event
        // if (invalid) {
        //     emit UtilizationRateInvalid(
        //         currentAvailableCash,
        //         currentTotalBorrowed,
        //         currentTotalReserved,
        //         utilizationRateWad
        //     );
        //     return;
        // }

        // uint256 borrowRatePerSecondWad;
        // (invalid, borrowRatePerSecondWad) = getBorrowRatePerSecondWad(
        //     utilizationRateWad
        // );
        // // If borrow rate is invalid then emit BorrowRatePerSecondInvalid event
        // if (invalid) {
        //     emit BorrowRatePerSecondInvalid(utilizationRateWad);
        //     return;
        // }

        // // Calculate elapsed timestamp between last accrued
        // uint256 timestampDelta;
        // (invalid, timestampDelta) = msub(currentTimestamp, previousTimestamp);
        // if (invalid) {
        //     emit TimestampDeltaInvalid(previousTimestamp, currentTimestamp);
        //     return;
        // }

        /*
         * Calculate the interest accumulated into borrows and reserves and the new index:
         *  simpleInterestFactor = borrowRatePerSecond * timestampDelta
         *  interestAccumulated = simpleInterestFactor * totalBorrows
         *  totalBorrowsNew = interestAccumulated + totalBorrows
         *  totalReservesNew = interestAccumulated * reserveFactor + totalReserves
         *  borrowIndexNew = simpleInterestFactor * borrowIndex + borrowIndex
         */
        // uint256 interestFactor;
        // (invalid, interestFactor) = mwmul(
        //     borrowRatePerSecondWad,
        //     timestampDelta
        // );
        // if (invalid) return;

        // // interestAccumulated is stored in decimal same as the total borrowed
        // uint256 interestAccummulated;
        // (invalid, interestAccummulated) = mwmul(interestFactor, totalBorrowed);
        // if (invalid) return;
        // (invalid, interestAccummulated) = mwdiv(interestAccummulated, ONE_WAD);
        // if (invalid) return;

        // // Total borrows new
        // uint256 totalBorrowedNew = interestAccummulated + totalBorrowed;
        // uint256 totalReserved = sd; // TODO: continue here
        // // uint256 borrowRatePerSecondWad = getBorrowRatePerSecondWad(
        // //     utilizationRateWad
        // // );
    }
}
