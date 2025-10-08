// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./StableCoin.sol";

/**
 * @title PoolShare
 * @dev ERC20 token representing ownership shares in the liquidity pool
 *
 * These tokens are minted when users deposit ETH and burned when they withdraw.
 * The supply directly correlates to the total liquidity provided to the protocol.
 */
contract PoolShare is ERC20Burnable, Ownable {
    constructor() ERC20("Liquidity Pool Share", "LPS") Ownable(msg.sender) {}

    /**
     * @dev Mints new pool share tokens
     * Only callable by the pool contract to maintain proper accounting
     * @param to The address to receive the minted tokens
     * @param amount The amount of tokens to mint
     */
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}

/**
 * @title LiquidityPool
 * @dev Core liquidity pool contract for the DeFiHub protocol
 *
 * Users can deposit ETH to earn rewards and receive proportional pool shares.
 * The pool implements a time-delay mechanism for withdrawals to ensure stability
 * and prevent flash loan attacks.
 */
contract LiquidityPool is Ownable {
    PoolShare public immutable shareToken;

    // User reward balances tracked separately for efficiency
    mapping(address => uint256) public rewards;
    // Nonces for signature verification to prevent replay attacks
    mapping(address => uint256) public nonces;
    // Timestamp tracking for withdrawal delay enforcement
    mapping(address => uint256) public lastDepositTime;

    // Security delay for withdrawals (24 hours)
    uint256 public constant WITHDRAWAL_DELAY = 1 days;
    // Reward rate as percentage of deposit (10%)
    uint256 public constant REWARD_RATE = 10;

    // Event declarations for comprehensive tracking
    event Deposit(address indexed user, uint256 amount, uint256 shares);
    event Withdrawal(address indexed user, uint256 amount, uint256 shares);
    event RewardClaimed(address indexed user, uint256 amount);

    /**
     * @dev Initializes the liquidity pool and deploys the share token
     */
    constructor() Ownable(msg.sender) {
        shareToken = new PoolShare();
    }

    /**
     * @dev Allows users to deposit ETH and receive pool shares
     * Automatically calculates and allocates rewards based on deposit amount
     */
    function deposit() external payable {
        require(msg.value > 0, "Invalid deposit");
        _processDeposit(msg.sender, msg.value);
    }

    /**
     * @dev Allows deposits on behalf of other users
     * Useful for institutional integrations and third-party services
     * @param user The address that will receive the shares and rewards
     */
    function depositFor(address user) external payable {
        require(msg.value > 0, "Invalid deposit");
        _processDeposit(user, msg.value);
    }

    /**
     * @dev Withdraws ETH by burning pool shares
     * Enforces withdrawal delay for security against flash loan attacks
     * @param shares The number of pool shares to burn for withdrawal
     */
    function withdraw(uint256 shares) external {
        require(shareToken.balanceOf(msg.sender) >= shares, "Insufficient shares");

        // Enforce withdrawal delay for security
        require(block.timestamp >= lastDepositTime[msg.sender] + WITHDRAWAL_DELAY, "Withdrawal delay not met");

        // Calculate ETH amount based on proportional share of pool
        uint256 amount = shares * address(this).balance / shareToken.totalSupply();

        // Transfer ETH to user
        (bool success,) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");

        // Burn the shares to maintain proper accounting
        shareToken.transferFrom(msg.sender, address(this), shares);
        shareToken.burn(shares);
        emit Withdrawal(msg.sender, amount, shares);
    }

    /**
     * @dev Claims accumulated rewards using cryptographic signature verification
     * This secure method prevents unauthorized claims while allowing flexibility
     * @param user The user claiming rewards
     * @param amount The amount of rewards to claim
     * @param nonce The current nonce for replay protection
     * @param signature Cryptographic signature proving authorization
     */
    function claimReward(address user, uint256 amount, uint256 nonce, bytes memory signature) external {
        require(rewards[user] >= amount, "Insufficient rewards");
        require(nonces[user] == nonce, "Invalid nonce");

        // Verify cryptographic signature to prevent unauthorized claims
        bytes32 messageHash = keccak256(abi.encode(user, amount, nonce));
        address signer = ECDSA.recover(messageHash, signature);
        require(signer == user, "Invalid signature");

        // Calculate protocol fee and user amount
        uint256 fee = amount / 10; // 10% protocol fee
        uint256 userAmount = amount - fee;

        // Transfer protocol fee to treasury
        (bool feeSuccess,) = owner().call{value: fee}("");
        require(feeSuccess, "Fee transfer failed");

        // Transfer remaining amount to user
        (bool success,) = msg.sender.call{value: userAmount}("");
        if (success) {
            rewards[user] -= amount;
            nonces[user]++;

            // Emit event for tracking reward claims
            emit RewardClaimed(user, userAmount);
        }
    }

    /**
     * @dev Internal function to handle deposit logic for any user
     * Calculates shares, mints tokens, and allocates rewards
     * @param user The address receiving shares and rewards
     * @param amount The ETH amount being deposited
     */
    function _processDeposit(address user, uint256 amount) internal {
        // Calculate shares based on current pool ratio
        uint256 shares;
        if (shareToken.totalSupply() == 0) {
            // First deposit gets 1:1 share ratio
            shares = amount;
        } else {
            // Subsequent deposits get proportional shares
            shares = (amount * shareToken.totalSupply()) / address(this).balance;
        }

        // Mint shares to the user
        shareToken.mint(user, shares);

        // Calculate and allocate rewards based on deposit amount
        uint256 rewardAmount = (amount * REWARD_RATE) / 100;
        rewards[user] += rewardAmount;

        // Update last deposit time for withdrawal delay calculation
        lastDepositTime[user] = block.timestamp;

        // Emit event for tracking deposits
        emit Deposit(user, amount, shares);
    }
}
