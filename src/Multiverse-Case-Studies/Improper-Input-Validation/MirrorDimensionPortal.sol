// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract MirrorDimensionPortal {
    mapping(address => uint256) public balances;

    function deposit() external payable {
        require(msg.value > 0, "zero deposit");
        balances[msg.sender] += msg.value;
    }

    /// @notice Vulnerable exit function
    function exitPortal(address validator, uint256 amount) external {
        // Missing: require(msg.sender == validator)
        // Missing: consensus proof / signature verification
        require(amount > 0 && balances[validator] >= amount, "insufficient balance");

        balances[validator] -= amount;
        payable(msg.sender).transfer(amount);
    }
}
