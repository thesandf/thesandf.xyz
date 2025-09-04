// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract IronManSuitFixed {
    mapping(address => uint256) public energy;

    constructor() {
        energy[msg.sender] = 1000;
    }

    function drainEnergy(uint256 _drainAmount) public {
        require(energy[msg.sender] >= _drainAmount, "Not enough energy");
        energy[msg.sender] -= _drainAmount;
    }
}
