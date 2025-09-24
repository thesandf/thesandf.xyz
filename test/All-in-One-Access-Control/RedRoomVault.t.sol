// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {RedRoomVault} from "../../src/All-in-One-Access-Control/RedRoomVault.sol";
import {FixedRedRoomVault} from "../../src/All-in-One-Access-Control/FixedRedRoomVault.sol";
import {MockERC20} from "../../src/All-in-One-Access-Control/MockERC20.sol";
import {BlackWidowExploit} from "../../src/All-in-One-Access-Control/BlackWidowExploit.sol";

contract RedRoomVaultTest is Test {
    RedRoomVault public vault;
    FixedRedRoomVault public fixedVault;
    MockERC20 public mockToken;
    BlackWidowExploit public exploit;

    address public redRoomAdmin = makeAddr("RedRoomAdmin");
    address public blackWidow = makeAddr("BlackWidow");
    address public treasury = makeAddr("Treasury");

    function setUp() public {
        // Deploy mock token and vulnerable vault (without calling init)
        mockToken = new MockERC20("MockToken", "MKT");
        vault = new RedRoomVault("RedRoomToken", "RRT", treasury);

        // Fund the vault with tokens
        mockToken.mint(address(vault), 10_000 ether);

        // Deploy the exploit contract
        exploit = new BlackWidowExploit(address(vault), address(mockToken), payable(blackWidow));
    }

    /// @notice Demonstrates the full exploit against the vulnerable vault
    function test_Exploit_AllVulnerabilities() public {
        // Vault should start with 10,000 MKT
        assertEq(mockToken.balanceOf(address(vault)), 10_000 ether);

        // Ensure attacker has no roles initially
        assertEq(vault.admins(blackWidow), false);
        assertEq(vault.admins(address(exploit)), false);

        // Execute the exploit (hijack init + drain vault)
        vm.prank(blackWidow);
        exploit.exploitVault();

        // Exploit contract now has admin role
        assertEq(vault.admins(address(exploit)), true);

        // Vault should be drained
        assertEq(mockToken.balanceOf(address(vault)), 0);
        assertEq(mockToken.balanceOf(treasury), 10_000 ether);
    }

    /// @notice Ensures the fixed vault is properly protected
    function test_PreventExploits_FixedContract() public {
        // Deploy and initialize the fixed vault
        fixedVault = new FixedRedRoomVault("FixedRRT", "FRRT");
        fixedVault.initialize(redRoomAdmin, redRoomAdmin, treasury);

        // Attempt re-initialization should revert
        vm.startPrank(blackWidow);
        vm.expectRevert(bytes("InvalidInitialization()"));
        fixedVault.initialize(blackWidow, blackWidow, treasury);
        vm.stopPrank();

        // Attempt to call emergencyWithdraw without permission should fail
        vm.prank(blackWidow);
        vm.expectRevert();
        fixedVault.emergencyWithdraw(address(mockToken), 1_000 ether);
    }
}