// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract StarkSwap {
    mapping(address => uint256) public balances;
    uint256 public reserveETH = 1000 ether;
    uint256 public reserveToken = 10000 ether;

    function buy(uint256 minTokens) public payable {
        // 1. Calculate token output (AMM: x*y = k)
        uint256 tokensOut = (msg.value * reserveToken) / (reserveETH + msg.value);
        require(tokensOut >= minTokens, "Slippage too high");

        // 2. Update reserves and balances
        reserveETH += msg.value;
        reserveToken -= tokensOut;
        balances[msg.sender] += tokensOut;

        // 🛑 vulnerability: msg.value is known in the mempool, allowing for
        // precise price manipulation via a sandwich attack.
    }

    function sell(uint256 tokenAmount, uint256 minEth) public returns (uint256 ethOut) {
        ethOut = (tokenAmount * reserveETH) / (reserveToken + tokenAmount);
        require(ethOut >= minEth, "Slippage too high");
        require(balances[msg.sender] >= tokenAmount, "Not enough tokens");
        balances[msg.sender] -= tokenAmount;
        reserveToken += tokenAmount;
        reserveETH -= ethOut;
        payable(msg.sender).transfer(ethOut);
        return ethOut;
    }
}
