// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.7;
pragma experimental ABIEncoderV2;

/*
       _______         __
.----.|_     _|.-----.|  |--..-----..-----.
|   _|  |   |  |  _  ||    < |  -__||     |
|__|    |___|  |_____||__|__||_____||__|__|

rToken - High yield token for lender.

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http:www.gnu.org/licenses/>.

I wrote this for ETHOnline Hackathon 2021. Enjoy.

(c) bayu <https://github.com/pyk> 2021

*/

import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {AccessControl} from "lib/openzeppelin-contracts/contracts/access/AccessControl.sol";

/**
 * @title rToken is a simple mintable & burnable token with access control
 */
contract Token is ERC20, AccessControl {
    /// @notice Decimals of the token
    /// @dev https://docs.openzeppelin.com/contracts/4.x/erc20#a-note-on-decimals
    uint8 private immutable _decimals;

    /// @notice Admin address
    address private immutable _admin;

    /**
     * @notice Construct new token
     * @param tokenName The token name
     * @param tokenSymbol The token symbol
     * @param tokenDecimals The token decimals number
     * @param adminAddress The account address that granted access to mint & burn token
     */
    constructor(
        string memory tokenName,
        string memory tokenSymbol,
        uint8 tokenDecimals,
        address adminAddress
    ) ERC20(tokenName, tokenSymbol) {
        // Set decimals
        _decimals = tokenDecimals;
        _admin = adminAddress;

        // Grant the admin role to a specified account
        // https://docs.openzeppelin.com/contracts/4.x/access-control#granting-and-revoking
        _setupRole(DEFAULT_ADMIN_ROLE, adminAddress);
    }

    /// @dev https://docs.openzeppelin.com/contracts/4.x/erc20#a-note-on-decimals
    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    /// @notice Returns of the admin address that can mint/burn token
    function admin() external view returns (address) {
        return _admin;
    }

    /**
     * @notice mint mints new token, only admin is granted to mint new token
     * @param to The account address of the recipient
     * @param amount The token amount to be minted
     */
    function mint(address to, uint256 amount)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _mint(to, amount);
    }

    /**
     * @notice burn burns the tokens, only admin is granted to burn the token
     * @param from The account address to be burned
     * @param amount The token amount to be burned
     */
    function burn(address from, uint256 amount)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _burn(from, amount);
    }
}
