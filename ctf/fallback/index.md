---
title: 'Ethernaut - Fallback'
description: 'Claim ownership and drain the contract by exploiting weak access control in the receive fallback function. Learn about Solidity receive/fallback mechanics and the critical importance of secure defaults.'
date: 2025-07-01
tags: ['solidity', 'security', 'fallback', 'ethernaut', 'ctf']
image: '../../../../public/ethernaut.png'
authors: ['thesandf']
---

# 🪂 Fallback - The Silent Entry Point

## Challenge Overview

In this level, we are presented with a simple smart contract that manages user contributions. To pass the level, we must accomplish two objectives:
1. **Claim ownership** of the contract.
2. **Reduce its balance to 0** (drain all funds).

**The Catch:** The owner contribution is initialized to `1000 ETH`, and the standard `contribute()` function only allows payments under `0.001 ETH`. We cannot simply out-contribute the owner through normal means.

---

## Technical Analysis

### Vulnerability: Under-protected Fallback State Mutation

In Solidity, a contract can receive native Ether directly via the special `receive()` or `fallback()` external payable functions when call data is empty.

Let's examine the `receive()` function in `Fallback.sol`:

```solidity
receive() external payable {
    require(msg.value > 0 && contributions[msg.sender] > 0);
    owner = msg.sender;
}
```

#### The Root Cause
This function is triggered whenever native Ether is sent to the contract without any data payload. While it attempts to enforce access control via `require(msg.value > 0 && contributions[msg.sender] > 0)`, the constraints are trivial to satisfy:
1. **`contributions[msg.sender] > 0`**: We can satisfy this by making a tiny contribution using `contribute()` first.
2. **`msg.value > 0`**: We simply send a non-zero transaction (e.g., 1 wei) directly to the contract.

Once these conditions are met, the contract immediately updates the `owner` state variable to `msg.sender` (the player), granting us admin permissions over the entire contract.

---

## The Exploit: Step-by-Step Walkthrough

1. **Establish a Contribution Record**: Call `contribute()` sending a tiny amount of Ether (e.g., `0.0001 ETH` or `1 wei`). This sets `contributions[player] > 0`.
2. **Trigger the Receive Fallback**: Send a transaction containing `1 wei` directly to the contract's address with empty calldata. This fires the `receive()` function, satisfying the `require` statement, and updates `owner = player`.
3. **Drain the Vault**: Now that we are the owner, call the `withdraw()` function to transfer the entire contract balance to our account.

---

## Proof of Concept (PoC)

Below is the JavaScript console walkthrough that can be executed directly inside the Ethernaut console:

```javascript
// 1. Make a tiny contribution to satisfy contributions[msg.sender] > 0
await contract.contribute({ value: toWei('0.0005') });

// 2. Send 1 wei directly to trigger the receive() fallback and claim ownership
await sendTransaction({
  from: player,
  to: contract.address,
  value: toWei('0.000001')
});

// Verify ownership transition
const currentOwner = await contract.owner();
console.log("Is player owner?", currentOwner === player);

// 3. Withdraw all funds as the new owner
await contract.withdraw();
```

---

## Auditor's Lessons

1. **Avoid State Changes in Fallbacks**: The `receive()` and `fallback()` functions should remain highly simplified. Do not perform state-critical operations (like modifying ownership or access rights) within fallbacks.
2. **Strict Access Controls**: State changes affecting system hierarchy must be guarded by strict, multi-step authorization mechanisms, never implicit transitions based on direct value transfers.
3. **Understand EVM Entry Points**: Be aware that any user can send Ether to a contract, and receive/fallback mechanisms will capture these transactions. Developers must treat these entry points with the same security rigor as normal public functions.

---

## Remediation

To secure this contract, we must separate payment reception from administrative state changes. Administrative changes should be handled through dedicated, explicit functions, and the `receive()` function should be kept passive:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SecureFallback {
    mapping(address => uint256) public contributions;
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    function contribute() public payable {
        require(msg.value < 0.001 ether, "Exceeds contribution limit");
        contributions[msg.sender] += msg.value;
    }

    // Keep receive() passive and safe
    receive() external payable {
        contributions[msg.sender] += msg.value;
    }

    function withdraw() public onlyOwner {
        payable(owner).transfer(address(this).balance);
    }
}
```
