---
title: "Arithmetic Overflow & Underflow in Solidity (With Examples & Fixes)."
published: 2024-09-04
description: "Learn Solidity arithmetic overflow and underflow with code examples, version differences, and security fixes. Includes vulnerable <0.8.0 contracts and safe >=0.8.0 implementations."
tags: [Solidity, Overflow, Underflow, SafeMath, Unchecked]
category: Solidity Docs
draft: false
---

<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "TechArticle",
  "headline": "Arithmetic Overflow & Underflow in Solidity (With Examples & Fixes)",
  "description": "Learn Solidity arithmetic overflow and underflow with code examples, version differences, and security fixes. Includes vulnerable <0.8.0 contracts and safe >=0.8.0 implementations.",
  "author": { "@type": "Person", "name": "The Sandf" },
  "datePublished": "2024-09-04",
  "mainEntityOfPage": {
    "@type": "WebPage",
    "@id": "https://multiv-rekt.vercel.app/posts/solidity-docs/arithmetic-overflow-underflow-docs/"
  }
}
</script>


# Arithmetic Overflow & Underflow In Solidity

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
