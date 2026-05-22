---
title: 'Damn Vulnerable DeFi - The Rewarder'
description: 'A vulnerable Merkle reward distributor that fails to bind claims to the intended recipient, allowing attackers to steal every unclaimed reward.'
date: 2025-07-05
tags: ['solidity', 'security', 'merkle-tree', 'access-control', 'audit', 'damn-vulnerable-defi', 'ctf']
image: '../../../../public/damn-vulnerable-defi.png'
authors: ['thesandf']
---

# 🎁 The Rewarder - Merkle Proof Hijacking

## Challenge Overview

`TheRewarderDistributor` uses Merkle Trees to distribute rewards in multiple tokens such as DVT and WETH. The contract uses a bitmap to prevent double claims and supports batch claiming for gas efficiency.

**Goal:** Drain all unclaimed rewards from the distributor and send them to the recovery account.

---

# Technical Analysis

## The Vulnerable Code

The vulnerability exists inside the `claimRewards` function.

```solidity
// Merkle leaf used for verification
bytes32 leaf = keccak256(
    abi.encodePacked(
        inputClaim.batchNumber,
        inputClaim.amount,
        inputClaim.tokenIndex
    )
);

// Verify Merkle proof
if (!MerkleProof.verify(inputClaim.proof, root, leaf)) {
    revert InvalidProof();
}

// Transfer rewards to caller
inputTokens[inputClaim.tokenIndex].transfer(
    msg.sender,
    inputClaim.amount
);
````

---

## Root Cause: Missing Recipient Binding

The contract verifies only:

* `batchNumber`
* `amount`
* `tokenIndex`

But it completely ignores the actual reward recipient.

This means the Merkle proof only proves:

> “Someone can claim this amount.”

It does **not** prove:

> “This specific user is the rightful owner of the reward.”

Because the recipient address is not included in the Merkle leaf, anyone can reuse another user’s valid proof and redirect the rewards to themselves.

---

# Why This Is Dangerous

A secure Merkle distributor should include the beneficiary address inside the leaf:

```solidity
keccak256(
    abi.encodePacked(
        beneficiary,
        batchNumber,
        amount,
        tokenIndex
    )
);
```

And the contract should also verify:

```solidity
require(beneficiary == msg.sender);
```

Without this binding, proofs become transferable.

Merkle proofs are public data and are usually exposed through:

* frontend JSON files
* APIs
* event logs
* snapshots

An attacker can simply collect valid proofs and reuse them to steal every unclaimed reward.

---

# The Exploit

## Attack Steps

1. Collect publicly available Merkle proofs.
2. Extract valid:

   * batch numbers
   * amounts
   * token indexes
   * proofs
3. Call `claimRewards`.
4. Since the contract transfers tokens directly to `msg.sender`, the attacker receives all rewards.

---

## Exploit Example

```solidity
claims[0] = Claim({
    batchNumber: 0,
    amount: 115 ether,
    tokenIndex: 0,
    proof: dvtProof
});

claims[1] = Claim({
    batchNumber: 0,
    amount: 1 ether,
    tokenIndex: 1,
    proof: wethProof
});

distributor.claimRewards(claims, tokensToClaim);
```

The proof remains valid because the recipient address is never verified.

---

# Impact

An attacker can:

* steal every unclaimed reward
* drain the entire distributor contract
* bypass the intended whitelist system

This vulnerability completely breaks the security model of the Merkle distributor.

---

# Remediation

Always bind the Merkle proof to the intended recipient.

## Secure Leaf Construction

```solidity
bytes32 leaf = keccak256(
    abi.encodePacked(
        beneficiary,
        batchNumber,
        amount,
        tokenIndex
    )
);
```

## Verify Ownership

```solidity
require(beneficiary == msg.sender, "Not reward owner");
```

This ensures proofs cannot be reused by arbitrary users.

---

# Key Takeaways

* Merkle proofs must include user identity.
* Public proofs are not secrets.
* Never transfer assets to `msg.sender` unless ownership is verified.
* Missing recipient binding turns Merkle distributions into public withdrawals.

---
