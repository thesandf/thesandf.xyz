// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./MockERC20.sol";

/// @notice Flash loan provider for one-block liquidity (used for exploit demonstration)
contract QuantumRealmBank {
    MockERC20 public token;

    constructor(address _token) {
        token = MockERC20(_token);
    }

    /// @notice Execute a flash loan (must be repaid in same tx)
    /// @dev Used to simulate one-transaction attacks in tests
    function flashLoan(uint256 amount, address borrower, bytes calldata data) external {
        uint256 balanceBefore = token.balanceOf(address(this));
        require(balanceBefore >= amount, "not enough liquidity");

        // Send loan to borrower
        require(token.transfer(borrower, amount), "transfer failed");

        // Call borrower contract (attack logic runs here)
        (bool success,) = borrower.call(data);
        require(success, "borrower call failed");

        // Require loan repayment
        uint256 balanceAfter = token.balanceOf(address(this));
        require(balanceAfter >= balanceBefore, "loan not repaid");
    }
}
