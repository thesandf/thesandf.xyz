---
title: "Arithmetic Overflow & Underflow"
published: 2024-09-04
description: "Official-style documentation page explaining overflow and underflow in Solidity, version differences, examples, security impact, and fixes."
tags: [Solidity, Overflow, Underflow, SafeMath, Unchecked]
category: Solidity Docs
draft: false
---

# Arithmetic Overflow & Underflow

## 📖 Definition

* **Overflow**: Happens when a number exceeds the maximum value of its type and wraps back to zero (or the minimum value).
* **Underflow**: Happens when a number goes below zero and wraps around to the maximum possible value of its type.

---

##  Example with `uint8`

```solidity
uint8 x = 255; 
x = x + 1; 
// Overflow → wraps to 0
```

```solidity
uint8 y = 0; 
y = y - 1; 
// Underflow → wraps to 255
```

---

##  Solidity Version Behavior

* **Before Solidity 0.8.0**

  * Arithmetic operations do **not** revert.
  * Overflow/underflow wraps silently.
  * Developers used **SafeMath** library (OpenZeppelin) to catch errors.

* **Solidity 0.8.0 and above**

  * Arithmetic operations **revert automatically** on overflow/underflow.
  * You can still use `unchecked { ... }` to deliberately allow wraparound (usually for gas optimization).

---

##  Vulnerable Code (<0.8.0)

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

contract OverflowUnderflowExample {
    uint8 public value;

    function add(uint8 _amount) public {
        // Vulnerable: silent overflow possible
        value += _amount;
    }

    function subtract(uint8 _amount) public {
        // Vulnerable: silent underflow possible
        value -= _amount;
    }
}
```

---

## Safe Code (>=0.8.0)

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract SafeArithmetic {
    uint8 public value;

    function add(uint8 _amount) public {
        value += _amount; // reverts on overflow
    }

    function subtract(uint8 _amount) public {
        value -= _amount; // reverts on underflow
    }
}
```

---

## Security Impact

* Incorrect balances or counters.
* Ability for attackers to bypass logic.
* Potential infinite minting or balance inflation.

---

##  Recommendations

* Always use **Solidity >=0.8.0**.
* For legacy contracts, use **SafeMath**.
* Review any `unchecked { ... }` usage carefully.

---

##  Key Notes

* Overflow = “Too high → wraps to low.”
* Underflow = “Too low → wraps to high.”
* Modern Solidity handles checks automatically, but auditors must still confirm.

---
