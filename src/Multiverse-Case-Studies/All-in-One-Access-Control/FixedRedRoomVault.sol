// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract FixedRedRoomVault is ERC20, AccessControl, Initializable {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    address private treasury;

    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    /// @dev Initialization function using OpenZeppelin's `Initializable` pattern.
    function initialize(address defaultAdmin, address initialManager, address initialTreasury) public initializer {
        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(ADMIN_ROLE, defaultAdmin);
        _grantRole(MANAGER_ROLE, initialManager);
        treasury = initialTreasury;
    }

    /// @notice Restricts admin assignment to only existing admins
    function setAdmin(address _newAdmin) external onlyRole(ADMIN_ROLE) {
        _grantRole(ADMIN_ROLE, _newAdmin);
    }

    /// @notice Restricts manager assignment to only existing admins
    function setManager(address _newManager) external onlyRole(ADMIN_ROLE) {
        _grantRole(MANAGER_ROLE, _newManager);
    }

    /// @notice A properly protected emergency withdrawal function.
    function emergencyWithdraw(address token, uint256 amount) external onlyRole(MANAGER_ROLE) {
        require(ERC20(token).transfer(treasury, amount), "Withdrawal failed");
    }

    /// @notice A properly protected deposit function.
    function deposit(uint256 amount) external onlyRole(MANAGER_ROLE) {
        _mint(msg.sender, amount);
    }
}
