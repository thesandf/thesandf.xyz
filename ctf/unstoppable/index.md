---
title: 'Damn Vulnerable DeFi - Unstoppable'
description: 'A masterclass in Denial of Service (DoS) via ledger inconsistency. Learn how a single permissionless transfer can permanently paralyze an ERC4626 vault.'
date: 2025-07-01
tags: ['solidity', 'security', 'erc4626', 'dos', 'audit', 'damn-vulnerable-defi','ctf']
image: '../../../../public/damn-vulnerable-defi.png'
authors: ['thesandf']
---

# 🛡️ Unstoppable - Ledger Inconsistency DoS

## Challenge Overview

The `UnstoppableVault` is a standard **ERC4626 Vault** that also implements the ERC3156 Flash Loan interface. 

**The Goal:** Trigger a permanent Denial of Service (DoS) on the vault. Make it impossible for any user to deposit, withdraw, or take a flash loan ever again.

**The Twist:** You don't need any special permissions, and the exploit requires only a single, simple transaction.

---

## Technical Analysis

### The Vulnerable Code

The heart of the vulnerability lies in a strict equality check inside the `flashLoan` function:

```solidity
uint256 balanceBefore = totalAssets();
if (convertToShares(totalSupply) != balanceBefore) revert InvalidBalance();
```

### Root Cause: Internal vs. External Accounting

1.  **`balanceBefore`**: This is the **actual on-chain token balance** of the vault contract (`token.balanceOf(address(this))`).
2.  **`convertToShares(totalSupply)`**: This is the **internal accounting** of what the balance *should* be based on the total shares issued to users.

In a perfect world, these two numbers should match. However, the contract assumes that the only way for the token balance to increase is through the `deposit` or `mint` functions.

### The Exploit (The "Donation" Attack)

ERC20 tokens allow anyone to transfer tokens to any address using `transfer()`. If an attacker directly transfers even **1 wei** of the underlying token to the vault address:

*   The **on-chain balance** (`totalAssets()`) increases.
*   The **internal accounting** (`totalSupply`) remains unchanged because no new shares were minted.

This creates a permanent mismatch: `totalAssets() > convertToShares(totalSupply)`. 

Because the `flashLoan` function (and potentially other core functions) contains the `revert InvalidBalance()` check, the entire contract becomes a "brick." Every subsequent call will fail.

---

## Auditor's Detection Methodology

When auditing an **ERC4626** vault, always scan for these high-risk patterns:

1.  **Direct `balanceOf(address(this))` usage**: Using the real-time balance for critical logic instead of internal state variables.
2.  **Strict Equality (`==` or `!=`)**: Forcing on-chain balances to exactly match internal math.
3.  **Lack of Transfer Isolation**: Not accounting for "accidental" or malicious direct token transfers (donations).

---

## Proof of Concept (PoC)

In Foundry, the exploit is trivial:

```solidity
function test_unstoppable() public checkSolvedByPlayer {
    // Directly transfer 1 token to the vault to break the internal/external balance parity
    token.transfer(address(vault), 1); 
}
```

**Result:**
```bash
[PASS] test_unstoppable()
```

---

## Remediation

1.  **Remove Strict Equality Checks**: Never rely on `token.balanceOf(address(this))` being equal to internal accounting for core business logic.
2.  **Use Internal Accounting**: Track the `totalManagedAssets` using a state variable that only updates during `deposit()` and `withdraw()`.
3.  **Handle Surplus Gracefully**: If the on-chain balance exceeds internal accounting, treat the surplus as "donated" funds that can be distributed to existing shareholders or harvested by an admin, rather than reverting.

---

## Real-World Impact

This vulnerability falls under the **Ledger Inconsistency / Share Inflation** category. It has been seen in numerous DeFi projects where "vault harvesting" or "donation" attacks were used to either break the exchange rate or DoS the contract.

*   **Resupply Protocol (2025):** Lost **$9.56M** due to an ERC4626 donation-based exchange rate manipulation.
*   **Yearn Finance:** Historically addressed several "dust" donation attacks that attempted to manipulate share values.
