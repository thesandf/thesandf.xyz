---
title: "Thor vs Hulk & Iron Man - Arithmetic Overflow & Underflow in Solidity"
published: 2024-09-04
description: "Thor challenges Hulk’s rage and Iron Man’s power suit to explain arithmetic overflow & underflow in Solidity. Includes vulnerable code, exploits, and fixes."
image: /overflow-underflow.jpg
tags: [Solidity, Smart Contracts, Security, Arithmetic, MCU]
category: Audit-Case-Study
draft: false
---

<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "Article",
  "headline": "Thor vs Hulk & Iron Man - Arithmetic Overflow & Underflow in Solidity",
  "description": "Thor challenges Hulk’s rage and Iron Man’s power suit to explain arithmetic overflow & underflow in Solidity. Includes vulnerable code, exploits, and fixes.",
  "image": "https://multiv-rekt.vercel.app/overflow-underflow.jpg",
  "author": {
    "@type": "Person",
    "name": "The Sandf"
  },
  "datePublished": "2024-09-04",
  "mainEntityOfPage": {
    "@type": "WebPage",
    "@id": "https://multiv-rekt.vercel.app/posts/arithmetic-overflow-underflow/"
  }
}
</script>


# ⚡ Thor Breaks Math - Arithmetic Overflow & Underflow in Solidity

**MCU Analogy: The Hulk’s Rage vs. The Iron Man Suit**

---

## Executive Summary

Arithmetic overflow and underflow are classic vulnerabilities that plagued Solidity contracts before version 0.8.0.

* **Pre-0.8.0**: Arithmetic was *unchecked by default*. Overflows/underflows silently wrapped.
* **Post-0.8.0**: Arithmetic is *checked by default*. Overflows/underflows revert, unless explicitly wrapped in an `unchecked {}` block.

This case study illustrates both versions through an MCU analogy:

* **Hulk 🟢 (Overflow)**: Unlimited rage that cannot be contained in finite bounds.
* **Iron Man Suit 🤖 (Underflow)**: Energy drained below zero, causing catastrophic wraparound.

---

##  🎬 Story Time - The Battle

Thor ⚡️ enters the battlefield. His mission: **test the limits of Hulk’s rage and Iron Man’s power suit**.

* **Round 1: HulkRageToken (Overflow)**
  Thor pushes Hulk’s rage meter past its limits. At first, Hulk gets angrier, but once his rage exceeds the storage limit (`uint8 = 255`), it wraps around to a calm number. Thor laughs - *the strongest Avenger has been tricked by math*.

* **Round 2: IronManSuit (Underflow)**
  Thor drains the Iron Man suit’s energy beyond zero. Instead of shutting down, the suit glitches, overflowing into maximum power (`2²⁵⁶ − 1`). The suit explodes into chaos, handing Thor unlimited energy.

---

::github{repo="thesandf/Void-Rekt"}

## Vulnerable Contracts (Pre-0.8.0)

### HulkRageToken.sol (Overflow)

**Context**:  Read about `overflow/underflow` in <0.8.0 [`docu here`](#).
* This contract demonstrates an Arithmetic Overflow vulnerability 
* that existed in Solidity versions <0.8.0.
* In these versions, arithmetic operations (addition, subtraction, multiplication)
* did NOT revert on overflow/underflow - they silently wrapped around.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

// Example:
//   If rage[msg.sender] = 250 (uint8) and user calls getAngry(10),
//   result = 260 → wraps back to 4.
// This breaks logic, since Hulk's rage "resets" unexpectedly.
//
// ⚠️ Important for Auditors:
// - Overflow in <0.8.0 is silent and must be mitigated using SafeMath (OpenZeppelin).
// - From Solidity 0.8.0 onwards, overflow/underflow reverts by default,
//   unless explicitly wrapped in an `unchecked` block.

contract HulkRageToken {
    mapping(address => uint8) public rage;

    function getAngry(uint8 _increaseAmount) public {
        // Vulnerable: Silent overflow in <0.8.0.
        rage[msg.sender] += _increaseAmount;
    }
}

```

---

### IronManSuit.sol (Underflow)

**Context**: Read about `overflow/underflow` in <0.8.0 [`docu here`](#).
* This contract demonstrates an Arithmetic Underflow vulnerability 
* that existed in Solidity versions <0.8.0.
* In these versions, subtraction on unsigned integers (uint) 
* did NOT revert when going below zero - instead, it silently wrapped 
* to a very large number (close to 2^256).


```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

// Example:
//   If energy[msg.sender] = 0 and user calls drainEnergy(100),
//   result = 0 - 100 → wraps to (2^256 - 100).
// This means Iron Man’s suit suddenly shows *massive* energy instead of depleting.
//
// ⚠️ Important for Auditors:
// - Underflow in <0.8.0 is silent and must be mitigated using SafeMath (OpenZeppelin).
// - From Solidity 0.8.0 onwards, subtraction below zero reverts by default,
//   unless explicitly wrapped in an `unchecked` block.

contract IronManSuit {
    mapping(address => uint256) public energy;

    constructor() {
        energy[msg.sender] = 1000;
    }

    function drainEnergy(uint256 _drainAmount) public {
        // Vulnerable: Silent underflow in <0.8.0.
        energy[msg.sender] -= _drainAmount;
    }
}
```

---

## Vulnerable Contracts (Post-0.8.0 with `unchecked`)

### HulkRageToken.sol

**Context**:  Read about `unchecked` [`docu here`](#).
 * - Solidity ^0.8.0 introduced "checked arithmetic" by default.
 *   → Normally, `uint8 + uint8` that exceeds 255 will revert.
 * - Using `unchecked { ... }` disables these checks.
 *   → Overflow silently wraps around (like in <0.8.0).

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*
 * Demonstrates an arithmetic **overflow** vulnerability.
 * 
 * Example:
 *   rage[user] = 250
 *   user calls getAngry(10)
 *   250 + 10 = 260 → exceeds max(255)
 *   Wraparound: 260 - 256 = 4
 *   Final rage = 4 instead of reverting
 * 
 * Why it’s bad:
 * - Any logic depending on `rage` (rewards, checks, thresholds)
 *   can be bypassed or broken.
 */
contract HulkRageToken {
    // Rage levels stored per address (uint8 = 0–255 max).
    mapping(address => uint8) public rage;

    /*
     * Increase caller’s rage.
     * 
     * ⚠️ Vulnerability:
     * - `unchecked { ... }` disables overflow protection.
     * - If addition > 255, value wraps back to 0–255.
     */
    function getAngry(uint8 _increaseAmount) public {
        unchecked {
            rage[msg.sender] += _increaseAmount;
        }
    }
}

```

---

### IronManSuit.sol

 **Context**: Read about `unchecked` [`docu here`](#).
 * - Solidity ^0.8.0 checks arithmetic by default.
 *   → Normally, `0 - 1` would revert with an error.
 * - Using `unchecked { ... }` disables this safety.
 *   → Subtraction below zero wraps around to max(uint256).

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
/*
 * Demonstrates an arithmetic **underflow** vulnerability.
 *
 * Example:
 *   energy[user] = 0
 *   user calls drainEnergy(100)
 *   0 - 100 = -100 (invalid for uint256)
 *   Wraparound: uint256 max (2^256 - 1) - 99
 *   Final energy = 115792089237316195423570985008687907853269984665640564039457584007913129639935
 *
 * Why it’s bad:
 * - Attacker can convert a zero balance into an **enormous value**.
 * - Breaks tokenomics, supply constraints, or game mechanics.
 */
contract IronManSuit {
    // Each address has an energy balance (uint256 can hold huge numbers).
    mapping(address => uint256) public energy;

    constructor() {
        // Deployer starts with some energy.
        energy[msg.sender] = 1000;
    }

    /*
     * Drain caller’s energy.
     * 
     * ⚠️ Vulnerability:
     * - No check if user has enough energy.
     * - Underflow causes wraparound to a massive value.
     */
    function drainEnergy(uint256 _drainAmount) public {
        unchecked {
            energy[msg.sender] -= _drainAmount;
        }
    }
}
```

---

## Proof of Exploit

### ThorBreaker.sol

```solidity
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
```
---

## Foundry Test Example (`ThorBreakerTest.t.sol`)

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HulkRageToken} from "../../src/Arithmetic-Overflow-Underflow/Post/HulkRageToken.sol";
import {IronManSuit} from "../../src/Arithmetic-Overflow-Underflow/Post/IronManSuit.sol";
import {ThorBreaker} from "../../src/Arithmetic-Overflow-Underflow/ThorBreaker.sol";

contract ThorBreakerTest is Test {
    HulkRageToken hulk;
    IronManSuit ironMan;
    ThorBreaker thor;

    function setUp() public {
        hulk = new HulkRageToken();
        ironMan = new IronManSuit();
        thor = new ThorBreaker(address(hulk), address(ironMan));
    }

    function test_Break_Hulk() public {
        thor.breakHulk();
        uint8 finalRage = hulk.rage(address(thor));
        assertEq(finalRage, 4, "Overflow exploit failed");
    }

    function test_Break_IronMan() public {
        thor.breakIronMan();
        uint256 finalEnergy = ironMan.energy(address(thor));
        assertEq(finalEnergy, type(uint256).max - 99, "Underflow exploit failed");
    }
}
```

---

### Running the Tests

With Foundry:

```bash
forge test -vv
```

You’ll see logs like:

```
[PASS] test_Break_Hulk() (gas: xxxx)
[PASS] test_Break_Iron-Man() (gas: xxxx)
```
---

## Fixed Contracts

### HulkRageTokenFixed.sol

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract HulkRageTokenFixed {
    mapping(address => uint8) public rage;

    function getAngry(uint8 _increaseAmount) public {
        rage[msg.sender] += _increaseAmount; //  Checked by default
    }
}
```

---

### IronManSuitFixed.sol

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract IronManSuitFixed {
    mapping(address => uint256) public energy;

    constructor() {
        energy[msg.sender] = 1000;
    }

    function drainEnergy(uint256 _drainAmount) public {
        require(energy[msg.sender] >= _drainAmount, "Not enough energy");
        energy[msg.sender] -= _drainAmount;
    }
}
```

---

## Auditor’s Checklist

* [ ] Using Solidity <0.8.0 (unchecked arithmetic by default)?
* [ ] Any explicit `unchecked` blocks in 0.8+ without proper validation?
* [ ] Missing `require()` checks on subtraction?
* [ ] Edge cases tested for `0` and `max(uintX)` values?

---

## Severity & Impact

* **Overflow (HulkRageToken)**
  *Severity: High* – can bypass logic checks.

* **Underflow (IronManSuit)**
  *Severity: Critical* – attacker can gain massive balances.

**Business Risk**: Broken tokenomics, infinite balances, game-breaking logic, financial loss.

---

## Recommendations

* **Always use Solidity ≥0.8.0** where safe math is default.
* **Avoid `unchecked`** unless gas-optimized and justified.
* **Validate inputs** before subtraction.
* **For legacy code (<0.8.0)**: use **OpenZeppelin SafeMath**.
* **Test edge cases** thoroughly.

---

## References & Inspiration

* **MCU:** *Thor: Ragnarok (2017)* – Thor battles Hulk’s uncontrollable rage, and Iron Man’s armor glitches under stress. Perfect metaphors for overflow and underflow.

* **Historical Exploits:**

  1. **BatchOverflow (2018)** – A famous ERC20 vulnerability where multiplication overflow allowed attackers to mint **unlimited tokens**.

     * Root cause: Missing SafeMath checks in token logic.
     * Impact: Billions of tokens created out of thin air.
     * [PeckShield Postmortem](https://medium.com/@peckshield/peckshield-discovered-batchoverflow-bug-in-multiple-erc20-smart-contracts-8f60f173f4e7)

  2. **Rubixi Ponzi (2016)** – Early contracts failed to account for safe arithmetic, enabling logic bypasses and unstable payouts.

  3. **Fomo3D-style Games** – Relied on countdowns and counters that were exploitable via wraparound if unchecked.

* **Modern Fixes:**

  * **Solidity ≥0.8.0**: Arithmetic checked by default - no silent overflow/underflow.
  * **`unchecked {}`**: Still dangerous if used carelessly.
  * **OpenZeppelin SafeMath (pre-0.8.0)**: Historical go-to for preventing arithmetic bugs.
---

>[!NOTE]
Like Hulk’s uncontrollable rage and Iron Man’s unstable suit, **unchecked arithmetic is dangerous**. Modern Solidity makes it safer, but auditors must stay vigilant for legacy contracts and unsafe use of `unchecked`.

::github{repo="thesandf/Void-Rekt"}

---
