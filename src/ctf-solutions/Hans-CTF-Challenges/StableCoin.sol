// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title StableCoin
 * @dev Implementation of the DeFiHub protocol's native stablecoin
 *
 * This stablecoin uses a simplified decimal structure (1 decimal place)
 * to optimize for gas efficiency and reduce computational complexity.
 * The design choice provides significant gas savings for frequent transactions
 * within the DeFiHub ecosystem.
 */
contract StableCoin is ERC20 {
    // Events for comprehensive transaction tracking
    event TokensMinted(address indexed to, uint256 amount);

    /**
     * @dev Initializes the stablecoin with an initial supply
     * The initial supply is allocated to the deployer for distribution
     */
    constructor() ERC20("USD Stable", "USDS") {
        _mint(msg.sender, 1000000 * 10 ** decimals());
    }

    /**
     * @dev Override the standard decimals function to use 1 decimal place
     * This design choice optimizes for gas efficiency and simplifies calculations
     * @return The number of decimals used by the token
     */
    function decimals() public view virtual override returns (uint8) {
        return 1; // Using 1 decimal place for gas optimization
    }

    /**
     * @dev Mints new tokens to the specified address
     * Allows flexible token supply management for protocol operations
     * @param to The address that will receive the minted tokens
     * @param amount The amount of tokens to mint
     */
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
        emit TokensMinted(to, amount);
    }
}

/**
 * @title TokenStreamer
 * @dev Implements a multi-stream token distribution mechanism for gradual token release
 *
 * This contract enables continuous, time-based distribution of tokens with support
 * for multiple streams per user, custom durations, and proper accounting for
 * additional deposits to existing streams.
 */
contract TokenStreamer {
    // Core state variables
    StableCoin public immutable token;

    // Constants
    uint256 public constant STREAM_MIN_DURATION = 3600; // 1 hour
    uint256 public constant STREAM_MAX_DURATION = 3600 * 24 * 365; // 1 year

    // Stream data structure
    struct Stream {
        address recipient;
        uint256 totalDeposited;
        uint256 totalWithdrawn;
        uint256 startTime;
        uint256 endTime;
        uint256 lastUpdateTime;
        bool exists;
    }

    // Storage mappings
    mapping(uint256 => Stream) public streams;
    mapping(address => uint256[]) public userStreams; // Track stream IDs per user
    uint256 public nextStreamId = 1;

    // Events for tracking stream activities
    event StreamCreated(
        uint256 indexed streamId,
        address indexed depositor,
        address indexed recipient,
        uint256 amount,
        uint256 duration
    );
    event StreamDeposit(
        uint256 indexed streamId, address indexed depositor, uint256 amount
    );
    event StreamWithdrawal(
        uint256 indexed streamId, address indexed user, uint256 amount
    );

    // Errors
    error InvalidTokenAddress();
    error InvalidStreamDuration();
    error StreamNotFound();
    error StreamEnded();
    error NotStreamRecipient();
    error InvalidRecipient();
    error InvalidAmount();

    /**
     * @dev Initializes the token streamer with a stablecoin
     * @param _token The stablecoin to be streamed
     */
    constructor(StableCoin _token) {
        if (address(_token) == address(0)) {
            revert InvalidTokenAddress();
        }
        token = _token;
    }

    /**
     * @dev Creates a new token stream with specified duration
     * @param to The address that will receive the streamed tokens
     * @param amount The amount of tokens to deposit for streaming
     * @param duration The duration over which tokens will be streamed
     * @return streamId The ID of the newly created stream
     */
    function createStream(address to, uint256 amount, uint256 duration)
        external
        returns (uint256 streamId)
    {
        if (to == address(0)) revert InvalidRecipient();
        if (amount == 0) revert InvalidAmount();
        if (duration < STREAM_MIN_DURATION || duration > STREAM_MAX_DURATION) {
            revert InvalidStreamDuration();
        }

        require(
            token.transferFrom(msg.sender, address(this), amount), "Transfer failed"
        );

        streamId = nextStreamId++;
        streams[streamId] = Stream({
            recipient: to,
            totalDeposited: amount,
            totalWithdrawn: 0,
            startTime: block.timestamp,
            endTime: block.timestamp + duration,
            lastUpdateTime: block.timestamp,
            exists: true
        });

        userStreams[to].push(streamId);
        emit StreamCreated(streamId, msg.sender, to, amount, duration);
    }

    /**
     * @dev Adds tokens to an existing stream, maintaining the original end time
     * @param streamId The ID of the stream to add tokens to
     * @param amount The amount of tokens to add
     */
    function addToStream(uint256 streamId, uint256 amount) external {
        Stream storage stream = streams[streamId];
        if (!stream.exists) revert StreamNotFound();
        if (amount == 0) revert InvalidAmount();
        if (block.timestamp >= stream.endTime) revert StreamEnded();

        require(
            token.transferFrom(msg.sender, address(this), amount), "Transfer failed"
        );

        stream.totalDeposited += amount;
        stream.lastUpdateTime = block.timestamp;
        // Note: endTime stays the same, maintaining original timeline

        emit StreamDeposit(streamId, msg.sender, amount);
    }

    /**
     * @dev Withdraws available tokens from a specific stream
     * @param streamId The ID of the stream to withdraw from
     */
    function withdrawFromStream(uint256 streamId) external {
        Stream storage stream = streams[streamId];
        if (!stream.exists) revert StreamNotFound();
        if (msg.sender != stream.recipient) revert NotStreamRecipient();

        uint256 available = getAvailableTokens(streamId);
        if (available == 0) revert InvalidAmount();

        stream.totalWithdrawn += available;
        stream.lastUpdateTime = block.timestamp;

        require(token.transfer(msg.sender, available), "Transfer failed");
        emit StreamWithdrawal(streamId, msg.sender, available);
    }

    /**
     * @dev Calculates the amount of tokens available for withdrawal from a stream
     * @param streamId The ID of the stream to check
     * @return available The amount of tokens available for withdrawal
     */
    function getAvailableTokens(uint256 streamId)
        public
        view
        returns (uint256 available)
    {
        Stream memory stream = streams[streamId];
        if (!stream.exists) return 0;

        uint256 elapsedTime = block.timestamp - stream.startTime;
        uint256 totalDuration = stream.endTime - stream.startTime;

        if (block.timestamp >= stream.endTime) {
            // Stream completed, all deposited tokens available
            return stream.totalDeposited - stream.totalWithdrawn;
        }

        // Calculate proportional amount based on time elapsed
        uint256 totalAvailable = (stream.totalDeposited * elapsedTime) / totalDuration;

        // Return amount not yet withdrawn
        if (totalAvailable > stream.totalWithdrawn) {
            return totalAvailable - stream.totalWithdrawn;
        }
        return 0;
    }

    /**
     * @dev Returns information about a specific stream
     * @param streamId The ID of the stream to query
     * @return recipient The address that receives tokens from this stream
     * @return totalDeposited Total amount of tokens deposited to this stream
     * @return totalWithdrawn Total amount of tokens withdrawn from this stream
     * @return startTime When the stream started
     * @return endTime When the stream will end
     * @return exists Whether the stream exists
     */
    function getStreamInfo(uint256 streamId)
        external
        view
        returns (
            address recipient,
            uint256 totalDeposited,
            uint256 totalWithdrawn,
            uint256 startTime,
            uint256 endTime,
            bool exists
        )
    {
        Stream memory stream = streams[streamId];
        return (
            stream.recipient,
            stream.totalDeposited,
            stream.totalWithdrawn,
            stream.startTime,
            stream.endTime,
            stream.exists
        );
    }

    /**
     * @dev Returns all stream IDs for a specific user
     * @param user The address to query streams for
     * @return streamIds Array of stream IDs belonging to the user
     */
    function getUserStreams(address user)
        external
        view
        returns (uint256[] memory streamIds)
    {
        return userStreams[user];
    }

    /**
     * @dev Returns the current streaming rate for a specific stream in tokens per second
     * @param streamId The ID of the stream to query
     * @return rate The number of tokens released per second
     */
    function getStreamRate(uint256 streamId) external view returns (uint256 rate) {
        Stream memory stream = streams[streamId];
        if (!stream.exists || block.timestamp >= stream.endTime) return 0;

        uint256 totalDuration = stream.endTime - stream.startTime;
        return stream.totalDeposited / totalDuration;
    }
}
