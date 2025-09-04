// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*
 * Demonstrates an arithmetic **underflow** vulnerability.
 *
 * Example:
 *   energy[user] = 0
 *   user calls drainEnergy(100)
 *   0 - 100 = -100 (invalid for uint256)
 *   Wraparound: uint256 max (2^256 - 1) - 99
 *   Final energy = 115792089237316195423570985008687907853269984665640564039457584007913129639935
 *
 * Why it’s bad:
 * - Attacker can convert a zero balance into an **enormous value**.
 * - Breaks tokenomics, supply constraints, or game mechanics.
 */
contract IronManSuit {
    // Each address has an energy balance (uint256 can hold huge numbers).
    mapping(address => uint256) public energy;

    constructor() {
        // Deployer starts with some energy.
        energy[msg.sender] = 1000;
    }

    /*
     * Drain caller’s energy.
     * 
     * ⚠️ Vulnerability:
     * - No check if user has enough energy.
     * - Underflow causes wraparound to a massive value.
     */
    function drainEnergy(uint256 _drainAmount) public {
        unchecked {
            energy[msg.sender] -= _drainAmount;
        }
    }
}
