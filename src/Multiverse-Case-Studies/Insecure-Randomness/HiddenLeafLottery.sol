// SPDX-License-License: MIT
pragma solidity ^0.8.30;

// Vulnerable lottery contract
contract HiddenLeafLottery {
    // --- Vulnerabilities ---
    // 1. Insecure Randomness: block.timestamp is predictable and miner-influenced.
    // 2. No Reentrancy Protection: Risks multiple withdrawals.
    // 3. Unchecked ETH Transfer: Risks failure if winner is a contract.
    // 4. No State Validation: Allows draw manipulation.

    address public hokage;
    uint256 public entryFee = 1 ether;
    uint256 public pool = 0;
    address[] public ninjas;
    bool public drawCompleted = false;

    constructor() {
        hokage = msg.sender;
    }

    function enter() external payable {
        require(msg.value == entryFee, "Incorrect entry fee");
        ninjas.push(msg.sender);
        pool += msg.value;
    }

    function drawWinner() external {
        require(msg.sender == hokage, "Only hokage");
        require(!drawCompleted, "Draw already completed");
        require(ninjas.length > 0, "No ninjas");

        // Vulnerable: Uses block.timestamp for randomness
        uint256 random = uint256(keccak256(abi.encodePacked(block.timestamp, ninjas.length)));
        uint256 winnerIndex = random % ninjas.length;
        address winner = ninjas[winnerIndex];

        drawCompleted = true;
        (bool success,) = winner.call{value: pool}("");
        require(success, "Transfer failed");
        pool = 0;
    }

    function getPoolBalance() external view returns (uint256) {
        return pool;
    }
}
