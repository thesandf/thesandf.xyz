// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// Interface for mintable token
interface IMintableToken {
    function mint(address to, uint256 amount) external;
}
