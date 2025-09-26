// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {StarkSwap} from "../../../src/Multiverse-Case-Studies/Sandwich-MEV/StarkSwap.sol";

contract StarkSwapTest is Test {
    StarkSwap dex;
    address IronMan = makeAddr("IronMan");
    address Quicksilver = makeAddr("Quicksilver");

    function setUp() public {
        dex = new StarkSwap();
        vm.deal(IronMan, 10 ether);
        vm.deal(Quicksilver, 10 ether);
    }

    function testSandwichAttack() public {
        // --- STEP 1: FRONT-RUN (First Slice) ---
        vm.prank(Quicksilver);
        dex.buy{value: 1 ether}(10); // Quicksilver buys 1 ETH worth of tokens
        uint256 Q_tokens_acquired = dex.balances(Quicksilver);

        // --- STEP 2: VICTIM'S TRADE (The Filling) ---
        // Executes against the worsened price
        vm.prank(IronMan);
        dex.buy{value: 1 ether}(10); // Iron Man buys 1 ETH worth of tokens

        // --- STEP 3: BACK-RUN (Second Slice) ---
        // Quicksilver sells the tokens at the new high price
        vm.prank(Quicksilver);
        uint256 Q_eth_revenue = dex.sell(Q_tokens_acquired, 0);

        // Check 1: Proof Iron Man suffered loss (Initial 1 ETH for ~100 tokens)
        assertLt(dex.balances(IronMan), 95 ether, "Iron Man received significantly fewer tokens due to front-running.");

        // Check 2: Proof Quicksilver profited
        uint256 Q_cost = 1 ether;
        uint256 netProfit = Q_eth_revenue - Q_cost;

        console.log("Q's ETH Cost (Front-Run):", Q_cost);
        console.log("Q's ETH Revenue (Back-Run):", Q_eth_revenue);
        console.log("Quicksilver's Net Profit (MEV):", netProfit);

        assertGt(netProfit, 0, "Quicksilver failed to extract profit.");
    }
}
