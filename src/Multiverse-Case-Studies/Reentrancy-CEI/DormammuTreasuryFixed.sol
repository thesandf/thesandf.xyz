// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/*
  Minimal, self-contained fix:
   - Update state (effect) before external call (interaction)
   - Add a simple nonReentrant guard to be extra-safe
   - use -: OpenZeppelin’s ReentrancyGuard.
*/

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title SimpleReentrancyGuard
/// @notice A simple reentrancy guard implementation
//abstract contract SimpleReentrancyGuard {
//    uint256 private _locked = 1;
//    modifier nonReentrant() {
//       require(_locked == 1, "reentrant");
//        _locked = 2;
//         _;
//         _locked = 1;
//     }
// }

contract DormammuTreasuryFixed is ReentrancyGuard {
    mapping(address => uint256) public balanceOf;

    function deposit() external payable {
        require(msg.value > 0, "zero deposit");
        balanceOf[msg.sender] += msg.value;
    }

    function withdraw() external nonReentrant {
        uint256 amount = balanceOf[msg.sender];
        require(amount > 0, "no balance");

        //  Effects first
        balanceOf[msg.sender] = 0;

        //  Then interaction
        (bool sent,) = payable(msg.sender).call{value: amount}("");
        require(sent, "send failed");
    }

    function treasuryBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
