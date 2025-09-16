// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Safe Bifrost with resilient withdrawals
contract BifrostBridgeFixed {
    mapping(address => uint256) public vaultOfAsgard;

    /// @notice Deposit Ether to Bifrost
    function enterBifrost() external payable {
        require(msg.value > 0, "Bifrost requires Ether toll");
        vaultOfAsgard[msg.sender] += msg.value;
    }

    /// @notice Withdraw Ether safely, preserving vault on failure
    function crossBifrostSafe() external {
        uint256 tribute = vaultOfAsgard[msg.sender];
        require(tribute > 0, "No tribute to cross");

        vaultOfAsgard[msg.sender] = 0;

        (bool sent,) = payable(msg.sender).call{value: tribute}("");
        if (!sent) {
            // Restore balance so user can retry
            vaultOfAsgard[msg.sender] = tribute;
        }
    }
}
