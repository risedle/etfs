// SPDX-License-Identifier: GPL-3.0-or-later

// Risedle's Faucet Token Contract
// Dummy ERC20 token that anyone can mint and burn. For testing/demo purpose.
//
// I wrote this for ETHOnline Hackathon 2021. Enjoy.

// Copyright (c) 2021 Bayu - All rights reserved
// github: pyk

pragma solidity >=0.8.9;
pragma experimental ABIEncoderV2;

import { ERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract RisedleFaucetToken is ERC20, Ownable {
    uint8 private faucetTokenDecimals;
    uint256 private faucetMaxAmount;
    mapping(address => bool) isMinted;

    constructor(
        string memory name,
        string memory symbol,
        uint8 tokenDecimals,
        uint256 faucetAmount
    ) ERC20(name, symbol) {
        faucetTokenDecimals = tokenDecimals;
        faucetMaxAmount = faucetAmount;
    }

    function decimals() public view virtual override returns (uint8) {
        return faucetTokenDecimals;
    }

    function mint(uint256 amount) external onlyOwner {
        _mint(msg.sender, amount);
    }

    function burn(uint256 amount) external onlyOwner {
        _burn(msg.sender, amount);
    }

    function mint() external {
        require(isMinted[msg.sender] == false, "!max");
        _mint(msg.sender, faucetMaxAmount);
        isMinted[msg.sender] = true;
    }
}
