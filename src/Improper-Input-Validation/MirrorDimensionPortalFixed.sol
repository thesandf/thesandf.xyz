// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MirrorDimensionPortalFixed {
    mapping(address => uint256) public balances;

    function deposit() external payable {
        require(msg.value > 0, "zero deposit");
        balances[msg.sender] += msg.value;
    }

    function exitPortal(uint256 amount) external {
        require(amount > 0, "invalid amount");
        require(balances[msg.sender] >= amount, "insufficient balance");

        balances[msg.sender] -= amount;
        (bool sent,) = payable(msg.sender).call{value: amount}("");
        require(sent, "send failed");
    }
}

/////////////////////////////////////////////////////////////////////////////////////
// This demo uses `.call` for clarity and to show a realistic transfer.           //
// For production, prefer the pull-payment pattern and use `nonReentrant` + CEI.///
// See `MirrorPortalPullPayment.sol` for a production-ready pattern.            //
/////////////////////////////////////////////////////////////////////////////////
