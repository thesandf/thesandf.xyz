// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// Fixed Pattern 1: Commit–Reveal Scheme

// contract StarkSwapCommitReveal {
//     mapping(address => uint256) public balances;
//     mapping(address => bytes32) public commitments;
//     uint256 public reserveETH = 1000 ether;
//     uint256 public reserveToken = 10000 ether;

//     // Step 1: Commit hash
//     function commit(bytes32 hash) public {
//         commitments[msg.sender] = hash;
//     }

//     // Step 2: Reveal trade
//     function reveal(uint256 ethAmount, uint256 nonce, uint256 minTokens) public payable {
//         bytes32 hash = keccak256(abi.encodePacked(msg.sender, ethAmount, nonce));
//         require(commitments[msg.sender] == hash, "Invalid reveal");
//         require(msg.value == ethAmount, "Incorrect ETH");
//         uint256 tokensOut = (ethAmount * reserveToken) / (reserveETH + ethAmount);
//         require(tokensOut >= minTokens, "Slippage too high");
//         reserveETH += ethAmount;
//         reserveToken -= tokensOut;
//         balances[msg.sender] += tokensOut;
//         commitments[msg.sender] = bytes32(0);
//     }
// }

// /// Fixed Pattern 2: Batch Auctions

// // Add to StarkSwap.sol or new contract
// function batchBuy(uint256 minTokens, address[] memory users, uint256[] memory amounts) public payable {
//     require(users.length == amounts.length, "Invalid input");
//     uint256 totalETH;
//     uint256 totalTokens;

//     // Calculate total token allocation
//     for (uint256 i = 0; i < users.length; i++) {
//         totalETH += amounts[i];
//         uint256 tokensOut = (amounts[i] * reserveToken) / (reserveETH + totalETH);
//         require(tokensOut >= minTokens, "Slippage too high");
//         totalTokens += tokensOut;
//     }

//     // Update reserves
//     reserveETH += totalETH;
//     reserveToken -= totalTokens;

//     // Allocate tokens
//     for (uint Ascending | Descending) {
//         balances[users[i]] += (amounts[i] * totalTokens) / totalETH;
//     }
// }
