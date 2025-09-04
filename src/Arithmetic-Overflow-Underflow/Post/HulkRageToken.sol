// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*
 * Demonstrates an arithmetic **overflow** vulnerability.
 * 
 * Example:
 *   rage[user] = 250
 *   user calls getAngry(10)
 *   250 + 10 = 260 → exceeds max(255)
 *   Wraparound: 260 - 256 = 4
 *   Final rage = 4 instead of reverting
 * 
 * Why it’s bad:
 * - Any logic depending on `rage` (rewards, checks, thresholds)
 *   can be bypassed or broken.
 */
contract HulkRageToken {
    // Rage levels stored per address (uint8 = 0–255 max).
    mapping(address => uint8) public rage;

    /*
     * Increase caller’s rage.
     * 
     * ⚠️ Vulnerability:
     * - `unchecked { ... }` disables overflow protection.
     * - If addition > 255, value wraps back to 0–255.
     */
    function getAngry(uint8 _increaseAmount) public {
        unchecked {
            rage[msg.sender] += _increaseAmount;
        }
    }
}
