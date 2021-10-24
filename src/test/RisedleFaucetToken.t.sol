// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.7;
pragma experimental ABIEncoderV2;

import "lib/ds-test/src/test.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {RisedleFaucetToken} from "../RisedleFaucetToken.sol";
import {Hevm} from "./Hevm.sol";

contract RisedleFaucetTokenTest is DSTest {
    Hevm hevm;

    function setUp() public {
        hevm = new Hevm();
    }

    function test_OwnerCanMintAnyAmountToken() public {
        RisedleFaucetToken token = new RisedleFaucetToken(
            "Risedle WETH Faucet",
            "WETH",
            18,
            5 ether
        );

        token.mint(100 ether);

        assertEq(IERC20(address(token)).balanceOf(address(this)), 100 ether);
    }

    function test_PublicCanMintToken() public {
        RisedleFaucetToken token = new RisedleFaucetToken(
            "Risedle WETH Faucet",
            "WETH",
            18,
            5 ether
        );
        // Transfer ownership to random address
        address newOwner = hevm.addr(1);
        token.transferOwnership(newOwner);

        token.mint();

        assertEq(IERC20(address(token)).balanceOf(address(this)), 5 ether);
    }

    function testFail_PublicCannotMintRandomAmountOfToken() public {
        RisedleFaucetToken token = new RisedleFaucetToken(
            "Risedle WETH Faucet",
            "WETH",
            18,
            5 ether
        );
        // Transfer ownership to random address
        address newOwner = hevm.addr(1);
        token.transferOwnership(newOwner);

        token.mint(100 ether); // should be failed
    }

    function testFail_PublicCannotMintTokenTwice() public {
        RisedleFaucetToken token = new RisedleFaucetToken(
            "Risedle WETH Faucet",
            "WETH",
            18,
            5 ether
        );
        // Transfer ownership to random address
        address newOwner = hevm.addr(1);
        token.transferOwnership(newOwner);

        token.mint();
        token.mint(); // Should be failed
    }
}
