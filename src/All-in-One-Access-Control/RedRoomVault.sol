// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {MockERC20} from "../../src/All-in-One-Access-Control/MockERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract RedRoomVault is MockERC20 {
    address public ADMIN_ROLE;
    address public MANAGER_ROLE;

    mapping(address => bool) public admins;
    mapping(address => bool) public managers;

    address private treasury;
    bool private initialized = false;

    // A dummy ERC20 for the vault
    constructor(string memory name, string memory symbol, address initialTreasury) MockERC20(name, symbol) {
        treasury = initialTreasury;
    }

    /// @notice Unprotected initialization function (can be called once only)
    /// @dev Can be called by anyone, which is a critical vulnerability.
    function init(address _admin, address _manager) external {
        if (!initialized) {
            ADMIN_ROLE = _admin;
            MANAGER_ROLE = _manager;
            admins[_admin] = true;
            managers[_manager] = true;
            initialized = true;
        }
    }

    /// @notice Vulnerable, public admin assignment
    /// @dev Anyone can call this to become admin.
    function setAdmin(address _newAdmin) external {
        admins[_newAdmin] = true;
    }

    /// @notice Correctly restricted, but attacker can grant self this role
    /// @dev Only admins can call this function.
    function setManager(address _newManager) external {
        require(admins[msg.sender], "Not an admin");
        managers[_newManager] = true;
    }

    /// @notice Function with a missing access control check
    /// @dev Anyone can call this to drain the vault.
    function emergencyWithdraw(address token, uint256 amount) external {
        require(IERC20(token).transfer(treasury, amount), "Withdrawal failed");
    }

    /// @notice A seemingly protected function, but still exploitable
    /// @dev Only managers can call this function.
    function deposit(uint256 amount) external {
        require(managers[msg.sender], "Not a manager");
        this.mint(msg.sender, amount); // external call to MockERC20.mint 
    }
}