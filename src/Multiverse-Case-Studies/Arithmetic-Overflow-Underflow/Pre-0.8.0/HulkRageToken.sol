// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

contract HulkRageToken {
    mapping(address => uint8) public rage;

    function getAngry(uint8 _increaseAmount) public {
        // Vulnerable: Silent overflow in <0.8.0.
        rage[msg.sender] += _increaseAmount;
    }
}
