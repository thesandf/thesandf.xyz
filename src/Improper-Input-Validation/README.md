---
title: "Doctor Strange and the Mirror Portal – Improper Input Validation (Case Study)"
published: 2024-09-18
description: "Doctor Strange guards the Mirror Portal, but improper input validation lets villains sneak through exits. Inspired by a $41M real-world validator exploit, this case study shows how missing require checks drain treasuries - and how to fix them."
image: /loki-like-that.gif
tags: [Solidity, Smart Contracts, Security, InputValidation, MCU]
category: MCU-Audit-Case-Study
draft: false
---

<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "Article",
  "headline": "Doctor Strange and the Mirror Portal – Improper Input Validation (Case Study)",
  "description": "Doctor Strange guards the Mirror Portal, but improper input validation lets villains sneak through exits. Inspired by a $41M validator exploit, this MCU case study shows how attackers impersonate heroes - and how to fix it.",
  "image": "https://multiv-rekt.vercel.app/loki-like-that.gif",
  "author": {
    "@type": "Person",
    "name": "The Sandf"
  },
  "datePublished": "2024-09-18",
  "mainEntityOfPage": {
    "@type": "WebPage",
    "@id": "https://multiv-rekt.vercel.app/posts/improper-input-validation/"
  }
}
</script>

# Loki Impersonates Iron Man – Input Validation Exploit Case Study

## TL;DR

- **Vulnerability:** Missing input validation in `exitPortal()` → anyone can impersonate a validator/hero.  
- **Impact:** Loki tricks the Mirror Dimension into letting him withdraw funds while pretending to be Iron Man.  
- **Severity:** Critical.  
- **Fix:** Require proper identity/authentication (consensus proof, signatures) before allowing exits.  

---

## 🎬 Story Time

In the MCU, Doctor Strange protects the **Mirror Dimension**, where only trusted Avengers should pass through portals.  

But what if Strange fails to **check who’s walking out**?  

Enter **Loki**, the God of Mischief. If the portal only checks “is there an address?” instead of “is this really Iron Man?”, Loki can slip out disguised as Tony Stark and drain Stark’s treasure.  

This mirrors a real smart contract bug: missing **input validation** on withdrawal/exit functions.  

> *Fun fact: Loki doesn’t appear in **Doctor Strange (2016)**, but a post-credits scene shows Strange agreeing to help Thor search for Odin - with Loki tagging along. Loki’s impersonator skills make him the perfect metaphor here.*  

::github{repo="thesandf/Void-Rekt"}

---

## 📌 Vulnerable Contract

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MirrorDimensionPortal {
    mapping(address => uint256) public balances;

    function deposit() external payable {
        require(msg.value > 0, "zero deposit");
        balances[msg.sender] += msg.value;
    }

    /// @notice Vulnerable exit function
    function exitPortal(address validator, uint256 amount) external {
        // Missing: require(msg.sender == validator)
        // Missing: consensus proof / signature verification
        require(amount > 0 && balances[validator] >= amount, "insufficient balance");

        balances[validator] -= amount;
        payable(msg.sender).transfer(amount);
    }
}
```
>[!WARNING]
Anyone can pass in `validator = IronMan` but call from `msg.sender = Loki`.  
The portal happily pays Loki.

---

##  Proof of Exploit

Attacker contract:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MirrorDimensionPortal} from "./MirrorDimensionPortal.sol";

contract LokiAttack {
    MirrorDimensionPortal public portal;

    constructor(address _portal) {
        portal = MirrorDimensionPortal(_portal);
    }

    function impersonateIronMan(address ironMan, uint256 amount) external {
        portal.exitPortal(ironMan, amount);
    }

    receive() external payable {}
}
```

### Flow:
1. Iron Man deposits 100 ETH.  
2. Loki calls `exitPortal(IronMan, 100 ether)`.  
3. Contract doesn’t validate sender.  
4. Funds are sent to Loki.  

---

## Fixed Contract

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MirrorDimensionPortalFixed {
    mapping(address => uint256) public balances;

    function deposit() external payable {
        require(msg.value > 0, "zero deposit");
        balances[msg.sender] += msg.value;
    }

    function exitPortal(uint256 amount) external {
        require(amount > 0, "invalid amount");
        require(balances[msg.sender] >= amount, "insufficient balance");

        balances[msg.sender] -= amount;
        (bool sent,) = payable(msg.sender).call{value: amount}("");
        require(sent, "send failed");
    }
}
```

Fixes:  
- Only `msg.sender` can withdraw their own funds.  
- Stub for **validator proofs** or **signature-based authorization**.  
- Safer `.call` pattern for transfers.  

>[!NOTE]
Note: This demo uses `.call` for clarity and to show a realistic transfer. For production, prefer the pull-payment pattern and use `nonReentrant` + CEI. See `MirrorPortalPullPayment.sol` for a production-ready pattern.

---

##  Real-World Parallels

1. **Ethereum Validator Exit – \$41M Hack (2025)**  
   Missing validation in validator exits allowed unauthorized withdrawals.  
   👉 Loki pretending to be Iron Man.  
   [u.today report](https://u.today/ethereum-validator-exits-post-41-million-hack)  

2. **Improper Input Validation in DeFi**  
   Missing `require()` checks enable impersonation/unauthorized access.  
   👉 Doctor Strange forgetting to check the exit.  
   [Metana.io blog](https://metana.io/blog/improper-input-validation-in-smart-contracts/)  

---

## Auditor’s Checklist

- [ ] Validate ownership/signatures for addresses.  
- [ ] Require consensus proofs for validator exits.  
- [ ] Never let arbitrary addresses withdraw funds.  
- [ ] Simulate attacker contracts in tests.  

---

## Recommendations

- Always match `msg.sender` with the acting account.  
- Use **ECDSA signatures** or consensus proofs.  
- Prefer pull-payment patterns.  
- Include impersonation scenarios in test suites.  

---

## Test Snippet (Foundry)

```solidity
pragma solidity ^0.8.20;
import "forge-std/Test.sol";
import "../../src/Improper-Input-Validation/MirrorDimensionPortal.sol";
import "../../src/Improper-Input-Validation/LokiAttack.sol";

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
```

Run locally:

```bash
forge test -vv
```

---

##  Closing Thought

Just like Loki slipping out of the Mirror Dimension disguised as Iron Man, attackers exploit **missing validation** to impersonate and steal.  

Doctor Strange’s lesson for Solidity devs:  
👉 **Always check who’s walking through your portal.**

> [!NOTE]
This repo is an **educational minimal reproduction** of reentrancy. The MCU analogy (Loki Impersonates Iron Man) makes the bug memorable, but the exploit reflects **real-world \$41M hacks**.


::github{repo="thesandf/Void-Rekt"}

---
