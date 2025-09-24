// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {HulkRageToken} from "../../src/Arithmetic-Overflow-Underflow/Post/HulkRageToken.sol";
import {IronManSuit} from "../../src/Arithmetic-Overflow-Underflow/Post/IronManSuit.sol";
import {ThorBreaker} from "../../src/Arithmetic-Overflow-Underflow/ThorBreaker.sol";

contract ThorBreakerTest is Test {
    HulkRageToken hulk;
    IronManSuit ironMan;
    ThorBreaker thor;

    function setUp() public {
        hulk = new HulkRageToken();
        ironMan = new IronManSuit();
        thor = new ThorBreaker(address(hulk), address(ironMan));
    }

    function test_Break_Hulk() public {
        thor.breakHulk();
        uint8 finalRage = hulk.rage(address(thor));
        assertEq(finalRage, 4, "Overflow exploit failed");
    }

    function test_Break_IronMan() public {
        thor.breakIronMan();
        uint256 finalEnergy = ironMan.energy(address(thor));
        assertEq(finalEnergy, type(uint256).max - 99, "Underflow exploit failed");
    }
}
