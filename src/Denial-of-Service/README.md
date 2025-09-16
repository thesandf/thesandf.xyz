---
title: "Thor vs The Bifrost - Denial of Service (DoS) in Solidity (Gas Griefing Case Study)."
published: 2024-09-10
description: "Thor gets stranded when Loki clogs the Bifrost bridge. Learn how DoS in Solidity works, how attackers block withdrawals, and how patterns like pull-payments and gas-optimized loops prevent disaster."
tags: [Gas-Griefing, Fallback-Revert, Smart Contract DoS Attack , Security, Denial-of-Service, MCU]
category: Audit-Case-Study
draft: false
---

<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "Article",
  "headline": "Thor vs The Bifrost - Denial of Service (DoS) in Solidity (Gas Griefing Case Study)",
  "description": "Thor gets stranded when Loki clogs the Bifrost bridge. Learn how DoS in Solidity works, how attackers block withdrawals, and how patterns like pull-payments and gas-optimized loops prevent disaster.",
  "image": "#",
  "author": {
    "@type": "Person",
    "name": "The Sandf"
  },
  "datePublished": "2024-09-10",
  "mainEntityOfPage": {
    "@type": "WebPage",
    "@id": "https://multiv-rekt.vercel.app/posts/denial-of-service/"
  }
}
</script>

# ⚡ Thor vs The Bifrost - DoS Case Study

## TL;DR

* **Vulnerability:** Denial of Service (gas griefing / revert-in-loop).
* **Impact:** Loki jams the **BifrostBridge**, blocking all Asgardians from crossing (withdrawing funds).
* **Severity:** High
* **Fix:** Use **pull-payments** instead of looped mass payouts; avoid unbounded iterations.

---

## 🎬 Story Time

In *Thor (2011)*, the Bifrost is the magical rainbow bridge that lets Asgardians travel across realms. But what if Loki **clogs the Bifrost** with his tricks, preventing anyone from traveling?

In Solidity, this is a **Denial of Service** attack: one malicious participant makes it impossible for others to withdraw or execute a function.

* **BifrostBridge** = the vulnerable treasury with a payout loop.
* **Thor** = wants to withdraw his rightful share.
* **Loki** = inserts a malicious contract to **block the loop** and strand everyone.

---

## Roles

* **BifrostBridgeVulnerable** → the payout contract (victim).
* **LokiMalicious** → attacker contract that always reverts.
* **Thor (EOA/test)** → just a normal user stuck in the loop.

---

::github{repo="thesandf/Void-Rekt"}

## 📌 Vulnerable Contract - `BifrostBridgeVulnerable.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*
   The BifrostBridge pays Asgardians their Ether by looping through all citizens.
   Loki can jam the bridge by reverting in his fallback, blocking ALL payouts.
*/

contract BifrostBridgeVulnerable {
    address[] public asgardians;
    mapping(address => uint256) public vaultOfAsgard;

    /// @notice Asgardians send their Ether to the Bifrost
    function enterBifrost(address realmWalker) external payable {
        require(msg.value > 0, "Bifrost requires Ether toll");
        if (vaultOfAsgard[realmWalker] == 0) {
            asgardians.push(realmWalker);
        }
        vaultOfAsgard[realmWalker] += msg.value;
    }

    /// @notice Heimdall distributes Ether to all Asgardians (⚠️ Vulnerable)
    function openBifrost() external {
        for (uint256 i = 0; i < asgardians.length; i++) {
            address traveler = asgardians[i];
            uint256 tribute = vaultOfAsgard[traveler];
            if (tribute > 0) {
                //  Loki can revert here and jam the bridge
                (bool sent, ) = payable(traveler).call{value: tribute}("");
                require(sent, "Bifrost jammed!");
                vaultOfAsgard[traveler] = 0;
            }
        }
    }
}
```

> [!NOTE]
`transfer`/`send` forward only 2300 gas; `call` forwards all gas.
A malicious fallback can **revert the whole transaction** or consume huge gas.
`call` is necessary for sending to contracts that may require more gas but introduces this DoS risk.

>[!WARNING]
One bad actor can **block everyone** by reverting in their fallback. Thor is stranded because Loki jammed the Bifrost.

---

## 🪄 Loki’s Malicious Contract

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Loki jams the Bifrost by reverting on receive
contract LokiTrickster {
    receive() external payable {
        revert("Loki jams the Bifrost!");
    }
}
```

**Exploit Flow:**

1. Loki enters the Bifrost (deposits).
2. Heimdall (`openBifrost`) tries to send tribute.
3. Loki’s contract reverts → the entire bridge halts.
4. Thor and others are stranded with their funds stuck.

![DoS Exploit Flow](/DoS.svg)

---

##  Gas Analysis – Gas Griefing

* The vulnerable `openBifrost()` loop grows linearly with the number of Asgardians.
* Even if Loki **did not revert**, a long list of Asgardians could **exhaust gas**, causing a transaction failure.
* Partial reverts during the loop **waste all gas spent so far**, effectively denying service.
* Key takeaway: DoS isn’t just about stolen funds - it can also be about **making legitimate users’ transactions impossible**.

---

## Fixed Contract - `BifrostBridgeFixed.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Safe Bifrost with resilient withdrawals
contract BifrostBridgeFixed {
    mapping(address => uint256) public vaultOfAsgard;

    /// @notice Deposit Ether to Bifrost
    function enterBifrost() external payable {
        require(msg.value > 0, "Bifrost requires Ether toll");
        vaultOfAsgard[msg.sender] += msg.value;
    }

    /// @notice Withdraw Ether safely, preserving vault on failure
    function crossBifrostSafe() external {
        uint256 tribute = vaultOfAsgard[msg.sender];
        require(tribute > 0, "No tribute to cross");

        vaultOfAsgard[msg.sender] = 0;

        (bool sent, ) = payable(msg.sender).call{value: tribute}("");
        if (!sent) {
            // Restore balance so user can retry
            vaultOfAsgard[msg.sender] = tribute;
        }
    }
}
```

**Fixes applied:**

* No looping over Asgardians.
* Each Asgardian (`crossBifrost`) claims their own tribute.
* Loki can jam only himself, not the whole bridge.

---

##  Foundry Test - `DoSBifrost.t.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {BifrostBridgeVulnerable} from "../../src/Denial-of-Service/BifrostBridgeVulnerable.sol";
import {BifrostBridgeFixed} from "../../src/Denial-of-Service/BifrostBridgeFixed.sol";
import {LokiTrickster} from "../../src/Denial-of-Service/LokiTrickster.sol";

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
        assertEq(address(thor).balance, 1 ether );
        assertEq(address(jane).balance, 1 ether );
        assertEq(address(lokiUser).balance, 1 ether );
    }

    function test_CannotWithdrawWithoutDeposit() public {
        vm.expectRevert("No tribute to cross");
        bifrostSafe.crossBifrostSafe();
    }
}
```

---
## Why it’s a Denial of Service

* Funds aren’t stolen; **access is denied**.
* One malicious actor can block **all legitimate users** from interacting with the contract.
* This is a **classic DoS pattern**: revert-in-loop or gas exhaustion.

---

## Auditor’s Checklist

* [ ] Loops with unbounded iteration?
* [ ] External calls inside loops?
* [ ] Use of `require` on external transfers?
* [ ] No pull-payment alternative?
* [ ] Gas analysis for potential griefing?

---

## Recommendations

* Prefer **pull-payments** (`crossBifrost`) instead of mass payouts (`openBifrost`).
* Avoid loops with external calls.
* Simulate malicious recipients (like Loki) in tests.
* Analyze gas cost for large arrays and partial failures.

---

## References & Inspiration (Updated)

* **MCU:** *Thor (2011)* – Loki jams the Bifrost, blocking all crossings.

* **Historical & Recent DoS-type incidents:**

  **1. Governance Token DoS (2018)** – Reverting reward pool participants froze all withdrawals.
  **2. King of the Ether Throne (2016)** – Malicious fallback froze throne ownership.
  **3. OWASP SC10:2025 – DoS Patterns** – Reverting fallback or gas exhaustion in loops halts contracts.

* OpenZeppelin [PullPayment](https://docs.openzeppelin.com/contracts/5.x/api/security#PullPayment) pattern.

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
Educational minimal reproduction. MCU analogy (Loki clogging Bifrost) makes it memorable, but reflects **real-world DoS scenarios** blocking legitimate users’ withdrawals or actions.

::github{repo="thesandf/Void-Rekt"}

---


