// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title GovernanceToken
 * @dev Implementation of the DeFiHub protocol's governance token
 *
 * This token enables protocol governance and includes user status management
 * to protect the protocol from malicious actors. It follows the ERC20 standard
 * with additional security features.
 */
contract GovernanceToken is ERC20, Ownable {
    // User status tracking for protocol security
    mapping(address => bool) public blacklisted;

    // Events for better tracking
    event UserStatusUpdated(address indexed account, bool status);
    event TokensMinted(address indexed to, uint256 amount);

    /**
     * @dev Initializes the governance token with an initial supply
     * The initial supply is allocated to the deployer for distribution
     */
    constructor() ERC20("DeFiHub Governance", "DFHG") Ownable(msg.sender) {
        _mint(msg.sender, 1000000 * 10 ** decimals());
    }

    /**
     * @dev Mints new governance tokens to the specified address
     * Only callable by the contract owner to maintain token supply control
     * @param to The address that will receive the minted tokens
     * @param amount The amount of tokens to mint
     */
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
        emit TokensMinted(to, amount);
    }

    /**
     * @dev Updates the status of a user account (blacklisted or not)
     * This is a security feature to protect the protocol from malicious actors
     * @param account The address to update status for
     * @param status The new status (true = blacklisted, false = not blacklisted)
     */
    function updateUserStatus(address account, bool status) external onlyOwner {
        blacklisted[account] = status;
        emit UserStatusUpdated(account, status);
    }

    /**
     * @dev Overrides the standard transfer function to include status checks
     * Prevents blacklisted users from transferring tokens
     * @param recipient The address to transfer tokens to
     * @param amount The amount of tokens to transfer
     * @return A boolean indicating whether the transfer was successful
     */
    function transfer(address recipient, uint256 amount)
        public
        override
        returns (bool)
    {
        require(!blacklisted[msg.sender], "Sender is blacklisted");
        require(!blacklisted[recipient], "Recipient is blacklisted");
        return super.transfer(recipient, amount);
    }

    /**
     * @dev Overrides the standard transferFrom function to include status checks
     * Prevents transfers involving blacklisted users
     * @param sender The address to transfer tokens from
     * @param recipient The address to transfer tokens to
     * @param amount The amount of tokens to transfer
     * @return A boolean indicating whether the transfer was successful
     */
    function transferFrom(address sender, address recipient, uint256 amount)
        public
        override
        returns (bool)
    {
        require(!blacklisted[sender], "Sender is blacklisted");
        require(!blacklisted[recipient], "Recipient is blacklisted");
        return super.transferFrom(sender, recipient, amount);
    }
}

/**
 * @title GroupStaking
 * @dev Implements collective staking functionality for governance tokens
 *
 * This contract allows multiple users to stake together as a group,
 * with rewards distributed according to predefined weights. This reduces
 * individual gas costs and enables collaborative governance participation.
 */
contract GroupStaking is Ownable {
    // Reference to the governance token
    GovernanceToken public immutable token;

    // Structure to represent a staking group
    struct StakingGroup {
        uint256 id;
        uint256 totalAmount;
        address[] members;
        uint256[] weights;
        bool exists;
        address groupOwner;
    }

    // Mapping from group ID to group data
    mapping(uint256 => StakingGroup) public stakingGroups;
    uint256 public nextGroupId = 1;

    // Events for tracking group activities
    event GroupCreated(uint256 indexed groupId, address[] members, uint256[] weights);
    event StakeAdded(uint256 indexed groupId, address indexed staker, uint256 amount);
    event RewardsDistributed(uint256 indexed groupId, uint256 amount);

    // Errors
    error InvalidTokenAddress();
    error InvalidWeight();
    error InvalidMember();
    error BlacklistedMember();
    error DuplicateMember();

    /**
     * @dev Initializes the group staking contract with a governance token
     * @param _token The address of the governance token contract
     */
    constructor(address _token) Ownable(msg.sender) {
        if (_token == address(0)) {
            revert InvalidTokenAddress();
        }
        token = GovernanceToken(_token);
    }

    /**
     * @dev Creates a new staking group with specified members and weights
     * @param _members Array of member addresses
     * @param _weights Array of weights corresponding to each member (must sum to 100)
     * @return The ID of the newly created group
     */
    function createStakingGroup(
        address[] calldata _members,
        uint256[] calldata _weights
    ) external returns (uint256) {
        require(_members.length > 0, "Empty members list");
        require(
            _members.length == _weights.length, "Members and weights length mismatch"
        );

        // Validate weights
        uint256 totalWeight = 0;
        for (uint256 i = 0; i < _weights.length; i++) {
            if (_weights[i] == 0) {
                revert InvalidWeight();
            }
            totalWeight += _weights[i];
        }
        require(totalWeight == 100, "Weights must sum to 100");

        // Validate members
        for (uint256 i = 0; i < _members.length; i++) {
            if (_members[i] == address(0)) {
                revert InvalidMember();
            }
            if (token.blacklisted(_members[i])) {
                revert BlacklistedMember();
            }
            // Check if the member is duplicated
            for (uint256 j = i + 1; j < _members.length; j++) {
                if (_members[i] == _members[j]) {
                    revert DuplicateMember();
                }
            }
        }

        // Create the new group
        uint256 groupId = nextGroupId;
        stakingGroups[groupId] = StakingGroup({
            id: groupId,
            totalAmount: 0,
            members: _members,
            weights: _weights,
            exists: true,
            groupOwner: msg.sender
        });

        nextGroupId++;
        emit GroupCreated(groupId, _members, _weights);
        return groupId;
    }

    /**
     * @dev Adds stake to an existing group
     * @param _groupId The ID of the group to stake to
     * @param _amount The amount of tokens to stake
     */
    function stakeToGroup(uint256 _groupId, uint256 _amount) external {
        require(_amount > 0, "Amount must be greater than 0");
        require(!token.blacklisted(msg.sender), "Sender is blacklisted");
        require(stakingGroups[_groupId].exists, "Group does not exist");
        require(
            token.transferFrom(msg.sender, address(this), _amount), "Transfer failed"
        );

        stakingGroups[_groupId].totalAmount += _amount;
        emit StakeAdded(_groupId, msg.sender, _amount);
    }

    /**
     * @dev Withdraws tokens from a group and distributes them to members
     * @param _groupId The ID of the group to withdraw from
     * @param _amount The amount of tokens to withdraw and distribute
     */
    function withdrawFromGroup(uint256 _groupId, uint256 _amount) external {
        StakingGroup storage group = stakingGroups[_groupId];
        require(group.exists, "Group does not exist");
        require(group.totalAmount >= _amount, "Insufficient group balance");
        require(group.groupOwner == msg.sender, "Not the group owner");

        // Update group balance
        group.totalAmount -= _amount;

        // Distribute tokens according to weights
        for (uint256 i = 0; i < group.members.length; i++) {
            uint256 memberShare = (_amount * group.weights[i]) / 100;
            if (memberShare > 0) {
                token.transfer(group.members[i], memberShare);
            }
        }

        emit RewardsDistributed(_groupId, _amount);
    }

    /**
     * @dev Retrieves information about a specific staking group
     * @param _groupId The ID of the group to get information for
     * @return id The group ID
     * @return totalAmount The total amount staked in the group
     * @return members Array of member addresses
     * @return weights Array of weights corresponding to each member
     */
    function getGroupInfo(uint256 _groupId)
        external
        view
        returns (
            uint256 id,
            uint256 totalAmount,
            address[] memory members,
            uint256[] memory weights
        )
    {
        StakingGroup storage group = stakingGroups[_groupId];
        require(group.exists, "Group does not exist");

        return (group.id, group.totalAmount, group.members, group.weights);
    }

    /**
     * @dev Checks if an address is a member of a specific group
     * @param _groupId The ID of the group to check
     * @param _member The address to check membership for
     * @return A boolean indicating whether the address is a member
     */
    function isMemberOfGroup(uint256 _groupId, address _member)
        external
        view
        returns (bool)
    {
        StakingGroup storage group = stakingGroups[_groupId];
        if (!group.exists) return false;

        for (uint256 i = 0; i < group.members.length; i++) {
            if (group.members[i] == _member) {
                return true;
            }
        }

        return false;
    }
}
