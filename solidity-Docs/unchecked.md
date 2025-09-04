---
title: "Unchecked Blocks in Solidity (Gas Optimization & Security Risks)"
published: 2024-09-04
description: "Learn about Solidity's unchecked blocks, their purpose for gas optimization, security trade-offs, and best practices with code examples."
tags: [Solidity, Unchecked, Gas Optimization, Arithmetic, Security]
category: Solidity Docs
draft: false
---

<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "TechArticle",
  "headline": "Unchecked Blocks in Solidity (Gas Optimization & Security Risks)",
  "description": "Learn about Solidity's unchecked blocks, their purpose for gas optimization, security trade-offs, and best practices with code examples.",
  "author": { "@type": "Person", "name": "The Sandf" },
  "datePublished": "2024-09-04",
  "mainEntityOfPage": {
    "@type": "WebPage",
    "@id": "https://multiv-rekt.vercel.app/posts/solidity-docs/unchecked/"
  }
}
</script>


# `unchecked` in Solidity

## 📖 Definition

* The `unchecked { ... }` block disables automatic overflow and underflow checks introduced in **Solidity 0.8.0+**.
* Inside this block, arithmetic behaves like older Solidity versions:  
  * **Overflow** wraps back to zero.  
  * **Underflow** wraps back to the maximum value.  

---

##  Purpose

* **Gas Optimization**: Saves gas by skipping safety checks.  
* **Intentional Wraparound**: Useful when cyclic behavior is desired (e.g., circular buffers, modulo arithmetic).  

---

##  Example: With and Without `unchecked`

### Default (checked by Solidity ≥0.8.0)
```solidity
pragma solidity ^0.8.20;

contract SafeExample {
    uint8 public value = 255;

    function increment() public {
        value += 1; 
        //  Reverts: overflow detected
    }
}
````

### Using `unchecked`

```solidity
pragma solidity ^0.8.20;

contract UncheckedExample {
    uint8 public value = 255;

    function increment() public {
        unchecked {
            value += 1; 
            //  Overflow wraps to 0
        }
    }
}
```

---

##  Security Considerations

* Using `unchecked` **removes protections** - errors won’t revert.
* Attackers could exploit wraparound to manipulate balances, counters, or logic.
* Should only be used when:

  * **Gas savings are critical** and
  * **Logic guarantees safety** (e.g., loops bounded by conditions).

---

##  Gas Optimization Example

```solidity
pragma solidity ^0.8.20;

contract LoopExample {
    function sum(uint256 n) public pure returns (uint256 total) {
        for (uint256 i = 0; i < n; ) {
            total += i;
            unchecked { i++; } // gas optimized increment
        }
    }
}
```

* Without `unchecked`, Solidity inserts overflow checks in every `i++`.
* With `unchecked`, checks are skipped, saving gas.

---

##  Best Practices

* **Default to safe arithmetic** - use `unchecked` only when necessary.
* Add **comments** explaining why `unchecked` is safe.
* Never use it in user balance updates or sensitive math unless wraparound is intentional.

---

## Notes

* `unchecked` = manual override of safety.
* Great for gas optimization, **dangerous if misused**.
* Always justify its usage in audits and documentation.

---