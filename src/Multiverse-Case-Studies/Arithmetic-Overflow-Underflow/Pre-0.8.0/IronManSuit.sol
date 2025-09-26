// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

contract IronManSuit {
    mapping(address => uint256) public energy;

    constructor() {
        energy[msg.sender] = 1000;
    }

    function drainEnergy(uint256 _drainAmount) public {
        //  Vulnerable: Silent underflow in <0.8.0.
        energy[msg.sender] -= _drainAmount;
    }
}
