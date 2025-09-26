// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {BifrostBridgeVulnerable} from
    "../../../src/Multiverse-Case-Studies/Denial-of-Service/BifrostBridgeVulnerable.sol";
import {BifrostBridgeFixed} from "../../../src/Multiverse-Case-Studies/Denial-of-Service/BifrostBridgeFixed.sol";
import {LokiTrickster} from "../../../src/Multiverse-Case-Studies/Denial-of-Service/LokiTrickster.sol";

contract DoSBifrostTest is Test {
    BifrostBridgeVulnerable bifrostVuln;
    BifrostBridgeFixed bifrostSafe;
    LokiTrickster loki;
    address thor = makeAddr("Thor");

    function setUp() public {
        // Deploy contracts
        bifrostVuln = new BifrostBridgeVulnerable();
        bifrostSafe = new BifrostBridgeFixed();
        loki = new LokiTrickster();

        // Fund users
        vm.deal(thor, 1 ether);
        vm.deal(address(loki), 1 ether);

        // Deposit into vulnerable contract
        bifrostVuln.enterBifrost{value: 1 ether}(thor);
        bifrostVuln.enterBifrost{value: 1 ether}(address(loki));
    }

    function test_BifrostJammedByLoki() public {
        // Expect revert because Loki reverts in openBifrost
        vm.expectRevert();
        bifrostVuln.openBifrost();
    }

    function test_ThorCrossesSafeBifrost() public {
        vm.prank(thor);
        bifrostSafe.enterBifrost{value: 1 ether}();

        uint256 beforeBalance = thor.balance;
        uint256 beforeVault = bifrostSafe.vaultOfAsgard(thor);

        vm.prank(thor);
        bifrostSafe.crossBifrostSafe();

        // Assert Thor received funds
        assertEq(address(thor).balance, beforeBalance + beforeVault);
        // Assert vault cleared
        assertEq(bifrostSafe.vaultOfAsgard(thor), 0);
    }

    function test_LokiCannotBlockThor() public {
        // Loki enters safe contract
        vm.prank(address(loki));
        bifrostSafe.enterBifrost{value: 1 ether}();

        // Loki tries to withdraw but reverts internally (simulated in crossBifrostSafe)
        vm.prank(address(loki));
        bifrostSafe.crossBifrostSafe();

        // Thor enters and withdraws safely
        vm.prank(thor);
        bifrostSafe.enterBifrost{value: 1 ether}();

        vm.prank(thor);
        bifrostSafe.crossBifrostSafe();

        // Assert Thor successfully received funds
        assertEq(address(thor).balance, 1 ether);
        assertEq(bifrostSafe.vaultOfAsgard(thor), 0);
    }

    function test_MultipleUsersSafeWithdrawal() public {
        address lokiUser = makeAddr("LokiUser");
        address jane = makeAddr("Jane");

        vm.deal(lokiUser, 1 ether);
        vm.deal(jane, 1 ether);

        // Deposits
        vm.prank(thor);
        bifrostSafe.enterBifrost{value: 0.5 ether}();
        vm.prank(jane);
        bifrostSafe.enterBifrost{value: 0.3 ether}();
        vm.prank(lokiUser);
        bifrostSafe.enterBifrost{value: 0.2 ether}();

        // Withdrawals
        vm.prank(thor);
        bifrostSafe.crossBifrostSafe();
        vm.prank(jane);
        bifrostSafe.crossBifrostSafe();
        vm.prank(lokiUser);
        bifrostSafe.crossBifrostSafe();

        // Assert vaults cleared
        assertEq(bifrostSafe.vaultOfAsgard(thor), 0);
        assertEq(bifrostSafe.vaultOfAsgard(jane), 0);
        assertEq(bifrostSafe.vaultOfAsgard(lokiUser), 0);

        // Assert balances
        assertEq(address(thor).balance, 1 ether);
        assertEq(address(jane).balance, 1 ether);
        assertEq(address(lokiUser).balance, 1 ether);
    }

    function test_CannotWithdrawWithoutDeposit() public {
        vm.expectRevert("No tribute to cross");
        bifrostSafe.crossBifrostSafe();
    }
}
