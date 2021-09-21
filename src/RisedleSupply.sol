// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.7;
pragma experimental ABIEncoderV2;

/*

RisedleSupply is a lending pool. The implementation of the contract is
highly inspired by cToken's Compound protocol.

I wrote this for ETHOnline Hackathon 2021. Enjoy.

(c) bayu <https://github.com/pyk> 2021

*/

import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {AccessControl} from "lib/openzeppelin-contracts/contracts/access/AccessControl.sol";

/// @title Risedle's Supply Token Contract
contract RisedleSupply is ERC20, AccessControl {
    /// @notice Only valid borrower can borrow and repay underlying assets
    bytes32 public constant BORROWER_ROLE = keccak256("BORROWER_ROLE");

    /// @notice The underlying assets address contract (ERC20)
    address public immutable underlying;

    /// @notice The borrower address
    address public immutable borrower;

    /**
     * @notice Initialize new Risedle supply token
     * @param name The token name
     * @param symbol The token symbol
     * @param underlying_ The contract address of underlying asset
     * @param borrower_ The borrower address
     */
    constructor(
        string memory name,
        string memory symbol,
        address underlying_,
        address borrower_
    ) ERC20(name, symbol) {
        // Sanity check
        IERC20(underlying_).totalSupply();

        // Set underlying asset contract address
        underlying = underlying_;

        // Grant borrow and repay access to the borrower
        borrower = borrower_;
        _setupRole(BORROWER_ROLE, borrower_);
    }

    /**
     * @notice Similar to cToken decimals
     * @dev https://docs.openzeppelin.com/contracts/4.x/erc20#a-note-on-decimals
     */
    function decimals() public view virtual override returns (uint8) {
        return 8;
    }
}
