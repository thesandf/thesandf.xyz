// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../../src/Multiverse-Case-Studies/Improper-Input-Validation/MirrorDimensionPortal.sol";
import "../../../src/Multiverse-Case-Studies/Improper-Input-Validation/LokiAttack.sol";

contract MirrorPortalTest is Test {
    MirrorDimensionPortal portal;
    LokiAttack loki;
    address ironMan = makeAddr("ironMan");
    address lokiAddr = makeAddr("loki");

    uint256 amount = 100 ether;

    function setUp() public {
        portal = new MirrorDimensionPortal();
        vm.deal(ironMan, amount);
        vm.startPrank(ironMan);
        portal.deposit{value: amount}();
        vm.stopPrank();
    }

    function testExploit() public {
        vm.startPrank(lokiAddr);
        loki = new LokiAttack(address(portal));
        loki.impersonateIronMan(ironMan, amount);
        vm.stopPrank();

        assertEq(address(loki).balance, amount, "Loki drained funds");
    }
}
