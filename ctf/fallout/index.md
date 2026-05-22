---
title: 'Ethernaut - Fallout'
description: 'Exploiting a simple typographical error in a smart contract constructor. Learn how a single character typo can turn a critical initialization function into a public exploit vector.'
date: 2025-07-02
tags: ['solidity', 'security', 'initialization', 'ethernaut', 'ctf']
image: '../../../../public/ethernaut.png'
exclude: false
authors: ['thesandf']
---

# ☢️ Fallout - The Constructor Typo

## Challenge Overview

In this level, we are tasked with claiming ownership of the `Fallout` smart contract.

**The Catch:** The contract has an apparent constructor meant to initialize ownership upon deployment. However, a subtle naming mismatch exists, leaving the initialization vector entirely open to public execution.

---

## Technical Analysis

### Vulnerability: Mislabeled Constructor Function

In Solidity versions prior to `0.4.22`, constructors were declared as public functions matching the exact name of the contract. If the function name did not exactly match the contract name (including capitalization), it was treated as a standard public, callable function.

Let's inspect the initialization function of `Fallout.sol`:

```solidity
contract Fallout {
    /* constructor */
    function Fal1out() public payable {
        owner = msg.sender;
        allocations[owner] = msg.value;
    }
}
```

#### The Root Cause
A typographical error was introduced: the constructor function is named `Fal1out` (using the number `1`) instead of matching the contract name `Fallout` (using the letter `l`). 

Because of this typo:
1. The function `Fal1out` is **not** treated as a constructor by the compiler.
2. The contract is deployed with **no** constructor, and the `owner` state variable remains uninitialized (set to `address(0)`).
3. `Fal1out()` remains a standard, public, payable function that anyone can call at any point post-deployment to claim ownership.

---

## The Exploit: Step-by-Step Walkthrough

1. **Invoke the Typo Function**: Call the public `Fal1out()` function directly on the contract. We can optionally send `0 ETH` or a tiny amount since the function is marked as `payable`.
2. **Claim Ownership**: The contract updates `owner = msg.sender` (the player).
3. **Drain allocations (Optional)**: Call any administrative functions restricted by the `onlyOwner` modifier.

---

## Proof of Concept (PoC)

Below is the console walkthrough:

```javascript
// 1. Invoke the public Fal1out function directly
await contract.Fal1out({ value: toWei('0.0001') });

// Verify ownership transition
const currentOwner = await contract.owner();
console.log("Is player owner?", currentOwner === player);
```

---

## Auditor's Lessons

1. **Use Modern Solidity Construction**: Modern Solidity versions (>= `0.4.22`) deprecate contract-named constructors in favor of the explicit `constructor` keyword. Never use legacy patterns in modern development.
2. **Automated Linting and Compilation Warning Checks**: Modern compilers and static analysis tools (like Slither) instantly catch SWC-118 (Incorrect Constructor Name) vulnerabilities. Ensure linting is part of the continuous integration pipeline.
3. **Meticulous Code Reviews**: Subtle visual differences (such as `l` vs `1`, or `O` vs `0`) can be easily missed by human eyes but have catastrophic security implications.

---

## Remediation

Modernize the contract structure by upgrading the compiler version and replacing the legacy named function with the explicit `constructor` keyword:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SecureFallout {
    mapping(address => uint256) public allocations;
    address payable public owner;

    // Use explicit constructor keyword
    constructor() {
        owner = payable(msg.sender);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "caller is not the owner");
        _;
    }

    function allocate() public payable {
        allocations[msg.sender] += msg.value;
    }
}
```
