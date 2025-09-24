// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract HulkRageTokenFixed {
    mapping(address => uint8) public rage;

    function getAngry(uint8 _increaseAmount) public {
        rage[msg.sender] += _increaseAmount; // ✅ Checked by default
    }
}
