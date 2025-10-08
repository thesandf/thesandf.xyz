// SPDX-License-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Source Bridge (e.g., Ethereum)
contract SourceBridge {
    address public bridgedToken;
    uint256 public totalLocked = 0;
    mapping(address => uint256) public userLockedFunds;

    event FundsLocked(address indexed user, uint256 amount, uint256 nonce, bytes32 txHash);

    constructor(address _token) {
        bridgedToken = _token;
    }

    function lockFunds(uint256 amount, uint256 nonce) external {
        IERC20(bridgedToken).transferFrom(msg.sender, address(this), amount);
        userLockedFunds[msg.sender] += amount;
        totalLocked += amount;
        bytes32 txHash = keccak256(abi.encode(blockhash(block.number - 1), msg.sender, amount, nonce));
        emit FundsLocked(msg.sender, amount, nonce, txHash);
    }
}
