---
title: 'Ethernaut - Token'
description: 'Exploiting arithmetic underflows in Solidity versions before 0.8.0. Learn how unsigned integer wrapping can bypass balance checks to mint an astronomical supply of tokens.'
date: 2025-07-05
tags: ['solidity', 'security', 'underflow', 'arithmetic', 'ethernaut', 'ctf']
image: '../../../../public/ethernaut.png'
authors: ['thesandf']
---

# 🪙 Token - The Underflow Glitch

## Challenge Overview

In this level, we are given a basic token contract and start with a balance of **20 tokens**. Our goal is to acquire a large number of additional tokens.

**The Catch:** We only have 20 tokens, and we cannot mint or purchase more through standard avenues.

---

## Technical Analysis

### Vulnerability: Arithmetic Underflow in Legacy Solidity

The `Token` contract is compiled with Solidity `^0.6.0` and implements a standard token transfer:

```solidity
function transfer(address _to, uint256 _value) public returns (bool) {
    require(balances[msg.sender] - _value >= 0);
    balances[msg.sender] -= _value;
    balances[_to] += _value;
    return true;
}
```

#### The Root Cause
Two critical flaws are present here:
1. **Solidity version < `0.8.0`**: Prior to version `0.8.0`, arithmetic operations in Solidity did not revert on overflow or underflow. Instead, they wrapped around.
2. **Unsigned Integer Wrapping**: `balances[msg.sender] - _value` uses `uint256`. Unsigned integers cannot represent negative numbers. If we attempt to subtract a value larger than our current balance (e.g., `20 - 21`), the result underflows and wraps around to $2^{256} - 1$.

Because the expression underflows:
*   The check `balances[msg.sender] - _value >= 0` always evaluates to `true` (since any `uint256` value, including the wrapped underflow, is always $\ge 0$).
*   `balances[msg.sender] -= _value` underflows our balance to an astronomical value near $2^{256}$.

---

## The Exploit: The Multi-Step Solution

1. **Identify a Target**: Select any address other than ours (e.g., the contract's address or a random address).
2. **Perform the Underflow Transfer**: Call `transfer(target, 21)` from our account (which has 20 tokens).
3. **Inspect the Wealth**: The subtraction `20 - 21` underflows, and our balance becomes $2^{256} - 1$.

---

## Proof of Concept (PoC)

Below is the JavaScript console commands to execute in the Ethernaut console:

```javascript
// Transfer 21 tokens to a dummy address (more than our current 20)
const dummyAddress = "0x0000000000000000000000000000000000000000";
await contract.transfer(dummyAddress, 21);

// Verify our new astronomical balance
const newBalance = await contract.balanceOf(player);
console.log("Player's balance:", newBalance.toString());
```

---

## Auditor's Lessons

1. **Upgrade Your Compiler**: Always use modern Solidity versions (>= `0.8.0`) where arithmetic overflows and underflows revert automatically by default.
2. **Use SafeMath for Legacy Code**: If you must audit or maintain legacy contracts (compiled with < `0.8.0`), ensure all mathematical operations are processed using OpenZeppelin's `SafeMath` library.
3. **Flawed Assertions**: Avoid checking if an unsigned integer is greater than or equal to 0 (e.g., `uint >= 0`), as this statement is tautological and always returns `true`.

---

## Remediation

The simplest and most secure fix is upgrading to Solidity `0.8.0` or higher, which handles checks natively:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SecureToken {
    mapping(address => uint256) public balances;
    uint256 public totalSupply;

    constructor(uint256 _initialSupply) {
        balances[msg.sender] = totalSupply = _initialSupply;
    }

    function transfer(address _to, uint256 _value) public returns (bool) {
        // Underflow will automatically revert here in solidity >= 0.8.0
        require(balances[msg.sender] >= _value, "Insufficient balance");
        balances[msg.sender] -= _value;
        balances[_to] += _value;
        return true;
    }

    function balanceOf(address _owner) public view returns (uint256 balance) {
        return balances[_owner];
    }
}
```
