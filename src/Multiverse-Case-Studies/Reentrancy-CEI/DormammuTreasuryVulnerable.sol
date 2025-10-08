// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/*
  Dormammu (the treasury) holds Ether for citizens and pays a reward on withdraw.
  Bug: withdraw() sends Ether before updating the user's balance (CEI violation).
  An attacker (Doctor Strange) can reenter withdraw() in their fallback and drain the contract.
*/

contract DormammuTreasuryVulnerable {
    mapping(address => uint256) public balanceOf;

    /// @notice Alien Citizens deposit to the Dormammu Treasury
    function deposit() external payable {
        require(msg.value > 0, "zero deposit");
        balanceOf[msg.sender] += msg.value;
    }

    /// @notice Withdraw available balance (vulnerable)
    function withdraw() external {
        uint256 amount = balanceOf[msg.sender];
        require(amount > 0, "no balance");

        // 🛑 Vulnerable: external call happens BEFORE state update
        (bool sent,) = payable(msg.sender).call{value: amount}("");
        require(sent, "send failed");

        // state update happens after the external call - attacker can reenter here
        balanceOf[msg.sender] = 0;
    }

    /// @notice Current treasury balance
    function treasuryBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
