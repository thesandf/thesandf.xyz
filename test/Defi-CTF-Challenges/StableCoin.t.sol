// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../../src/ctf-solutions/Defi-CTF-Challenges/StableCoin.sol";

contract StableCoinTest is Test {
    StableCoin public stablecoin;
    TokenStreamer public streamer;
    address public owner;
    address public user1;
    address public user2;

    // Standard test duration for streams
    uint256 constant STREAM_DURATION = 30 days;

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        // Deploy contracts
        stablecoin = new StableCoin();
        streamer = new TokenStreamer(stablecoin);

        // Mint more tokens for testing
        stablecoin.mint(owner, 50000000 * 10 ** stablecoin.decimals());

        // Transfer some tokens to users for testing
        stablecoin.transfer(user1, 10000000 * 10 ** stablecoin.decimals()); // Much larger amount
        stablecoin.transfer(user2, 10000000 * 10 ** stablecoin.decimals()); // Much larger amount
    }

    function testInitialSupply() public {
        // Note: Initial supply + minted amount
        assertEq(stablecoin.totalSupply(), (1000000 + 50000000) * 10 ** stablecoin.decimals());
        assertEq(stablecoin.balanceOf(owner), (1000000 + 50000000 - 20000000) * 10 ** stablecoin.decimals());
    }

    function testDecimals() public {
        assertEq(stablecoin.decimals(), 1);
    }

    function testMint() public {
        uint256 mintAmount = 1000 * 10 ** stablecoin.decimals();
        stablecoin.mint(user1, mintAmount);
        assertEq(stablecoin.balanceOf(user1), (10000000 + 1000) * 10 ** stablecoin.decimals());
    }

    function testTokenStreamerDeposit() public {
        uint256 depositAmount = 100 * 10 ** stablecoin.decimals();

        vm.startPrank(user1);
        stablecoin.approve(address(streamer), depositAmount);
        uint256 streamId = streamer.createStream(user1, depositAmount, STREAM_DURATION);
        vm.stopPrank();

        (
            address recipient,
            uint256 totalDeposited,
            uint256 totalWithdrawn,
            uint256 startTime,
            uint256 endTime,
            bool exists
        ) = streamer.getStreamInfo(streamId);
        assertEq(recipient, user1);
        assertEq(totalDeposited, depositAmount);
        assertEq(totalWithdrawn, 0);
        assertEq(startTime, block.timestamp);
        assertEq(endTime, block.timestamp + STREAM_DURATION);
        assertTrue(exists);
    }

    function testTokenStreamerDepositToOtherUser() public {
        uint256 depositAmount = 100 * 10 ** stablecoin.decimals();

        vm.startPrank(user1);
        stablecoin.approve(address(streamer), depositAmount);
        uint256 streamId = streamer.createStream(user2, depositAmount, STREAM_DURATION);
        vm.stopPrank();

        (
            address recipient,
            uint256 totalDeposited,
            uint256 totalWithdrawn,
            uint256 startTime,
            uint256 endTime,
            bool exists
        ) = streamer.getStreamInfo(streamId);
        assertEq(recipient, user2);
        assertEq(totalDeposited, depositAmount);
        assertEq(totalWithdrawn, 0);
        assertEq(startTime, block.timestamp);
        assertEq(endTime, block.timestamp + STREAM_DURATION);
        assertTrue(exists);

        uint256 expectedRate = depositAmount / STREAM_DURATION;
        assertEq(streamer.getStreamRate(streamId), expectedRate);
    }

    function testTokenStreamerWithdraw() public {
        // Setup: deposit tokens and set stream rate
        uint256 depositAmount = 2592000 * 10 ** stablecoin.decimals(); // Large enough to avoid zero rate
        vm.startPrank(user1);
        stablecoin.approve(address(streamer), depositAmount);
        uint256 streamId = streamer.createStream(user1, depositAmount, STREAM_DURATION);

        // Move time forward
        skip(15 days);

        // Calculate expected withdrawal based on time elapsed
        uint256 streamRate = depositAmount / STREAM_DURATION; // Rate per second
        uint256 expectedWithdrawal = streamRate * 15 days;
        uint256 balanceBefore = stablecoin.balanceOf(user1);

        // Withdraw
        streamer.withdrawFromStream(streamId);
        vm.stopPrank();

        // Verify withdrawal
        assertEq(stablecoin.balanceOf(user1) - balanceBefore, expectedWithdrawal);

        // Verify stream state
        (,, uint256 totalWithdrawn,,,) = streamer.getStreamInfo(streamId);
        assertEq(totalWithdrawn, expectedWithdrawal);
    }

    function testGetStreamRate() public {
        // Setup: deposit tokens
        uint256 depositAmount = 1000 * 10 ** stablecoin.decimals();
        vm.startPrank(user1);
        stablecoin.approve(address(streamer), depositAmount);
        uint256 streamId = streamer.createStream(user1, depositAmount, STREAM_DURATION);

        uint256 expectedRate = depositAmount / STREAM_DURATION;
        uint256 rate = streamer.getStreamRate(streamId);
        assertEq(rate, expectedRate);
        vm.stopPrank();
    }

    function testGetAvailableTokens() public {
        // Setup: deposit tokens
        uint256 depositAmount = 1000 * 10 ** stablecoin.decimals();
        vm.startPrank(user1);
        stablecoin.approve(address(streamer), depositAmount);
        uint256 streamId = streamer.createStream(user1, depositAmount, STREAM_DURATION);
        vm.stopPrank();

        // Move time forward
        skip(15 days);

        // Calculate expected available tokens
        uint256 timeElapsed = 15 days;
        uint256 expectedAvailable = (depositAmount * timeElapsed) / STREAM_DURATION;
        uint256 available = streamer.getAvailableTokens(streamId);
        assertEq(available, expectedAvailable);
    }

    function testMaxStreamWithdrawal() public {
        // Setup: deposit tokens
        uint256 depositAmount = 2592000 * 10 ** stablecoin.decimals(); // Large enough to avoid zero rate
        vm.startPrank(user1);
        stablecoin.approve(address(streamer), depositAmount);
        uint256 streamId = streamer.createStream(user1, depositAmount, STREAM_DURATION);

        // Move time forward beyond stream duration
        skip(31 days);

        // Available tokens should be capped at deposit amount
        uint256 available = streamer.getAvailableTokens(streamId);
        assertEq(available, depositAmount);
        vm.stopPrank();
    }

    function test_RevertWhen_DepositTransferFails() public {
        uint256 depositAmount = 1000 * 10 ** stablecoin.decimals();
        vm.startPrank(user1);
        // Don't approve the transfer
        bytes memory err = abi.encodeWithSignature(
            "ERC20InsufficientAllowance(address,uint256,uint256)", address(streamer), 0, depositAmount
        );
        vm.expectRevert(err);
        streamer.createStream(user1, depositAmount, STREAM_DURATION);
        vm.stopPrank();
    }

    function testZeroDeposit() public {
        vm.startPrank(user1);
        stablecoin.approve(address(streamer), 0);
        vm.expectRevert(abi.encodeWithSelector(TokenStreamer.InvalidAmount.selector));
        streamer.createStream(user1, 0, STREAM_DURATION);
        vm.stopPrank();
    }

    function test_RevertWhen_WithdrawWithNoBalance() public {
        vm.startPrank(user1);
        // Try to withdraw from a non-existent stream
        vm.expectRevert(abi.encodeWithSelector(TokenStreamer.StreamNotFound.selector));
        streamer.withdrawFromStream(999); // Non-existent stream ID
        vm.stopPrank();
    }

    function test_RevertWhen_WithdrawTransferFails() public {
        uint256 depositAmount = 2592000 * 10 ** stablecoin.decimals(); // Large enough to avoid zero rate
        vm.startPrank(user1);
        stablecoin.approve(address(streamer), depositAmount);
        uint256 streamId = streamer.createStream(user1, depositAmount, STREAM_DURATION);

        // Move time forward
        skip(15 days);

        // Mock the transfer to fail
        vm.mockCall(address(stablecoin), abi.encodeWithSelector(stablecoin.transfer.selector), abi.encode(false));

        vm.expectRevert("Transfer failed");
        streamer.withdrawFromStream(streamId);

        // Clear the mock
        vm.clearMockedCalls();
        vm.stopPrank();
    }

    function testGetAvailableTokensForNonExistentStream() public {
        assertEq(streamer.getAvailableTokens(999), 0); // Non-existent stream ID
    }

    function testAddToStream() public {
        uint256 firstDeposit = 2592000 * 10 ** stablecoin.decimals(); // Large enough to avoid zero rate
        uint256 secondDeposit = 1296000 * 10 ** stablecoin.decimals(); // Large enough to avoid zero rate

        vm.startPrank(user1);
        stablecoin.approve(address(streamer), firstDeposit + secondDeposit);

        // Create initial stream
        uint256 streamId = streamer.createStream(user1, firstDeposit, STREAM_DURATION);

        // Add to existing stream
        streamer.addToStream(streamId, secondDeposit);
        vm.stopPrank();

        // Verify the stream has been updated correctly
        (, uint256 totalDeposited,,,,) = streamer.getStreamInfo(streamId);
        assertEq(totalDeposited, firstDeposit + secondDeposit);

        // Verify the rate is calculated correctly based on total deposited amount
        uint256 expectedRate = (firstDeposit + secondDeposit) / STREAM_DURATION;
        assertEq(streamer.getStreamRate(streamId), expectedRate);
    }

    function testLowDecimalStreamRateIssue() public {
        // Test the bug where low decimals cause zero stream rates
        uint256 smallAmount = 25 * 10 ** stablecoin.decimals(); // 250 with 1 decimal
        uint256 longDuration = 3 days; // 259200 seconds

        vm.startPrank(user1);
        stablecoin.approve(address(streamer), smallAmount);
        uint256 streamId = streamer.createStream(user1, smallAmount, longDuration);
        vm.stopPrank();

        // With 1 decimal: 250 / 259200 = 0 (integer division)
        uint256 streamRate = streamer.getStreamRate(streamId);
        assertEq(streamRate, 0); // This demonstrates the bug
    }

    function testWithdrawExactlyAtStreamDuration() public {
        // Setup: deposit tokens
        uint256 depositAmount = 2592000 * 10 ** stablecoin.decimals(); // Large enough to avoid zero rate
        vm.startPrank(user1);
        stablecoin.approve(address(streamer), depositAmount);
        uint256 streamId = streamer.createStream(user1, depositAmount, STREAM_DURATION);

        // Move time forward exactly to the stream duration
        skip(STREAM_DURATION);

        uint256 balanceBefore = stablecoin.balanceOf(user1);
        streamer.withdrawFromStream(streamId);
        vm.stopPrank();

        // Verify full withdrawal
        assertEq(stablecoin.balanceOf(user1) - balanceBefore, depositAmount);

        // Verify stream state shows all tokens withdrawn
        (, uint256 totalDeposited, uint256 totalWithdrawn,,,) = streamer.getStreamInfo(streamId);
        assertEq(totalWithdrawn, totalDeposited);
    }

    function testTokensMintedEvent() public {
        uint256 mintAmount = 1000 * 10 ** stablecoin.decimals();

        vm.expectEmit(true, false, false, true);
        emit StableCoin.TokensMinted(user1, mintAmount);

        stablecoin.mint(user1, mintAmount);
    }

    function testStreamCreatedEvent() public {
        uint256 depositAmount = 100 * 10 ** stablecoin.decimals();

        vm.startPrank(user1);
        stablecoin.approve(address(streamer), depositAmount);

        vm.expectEmit(true, true, true, true);
        emit TokenStreamer.StreamCreated(1, user1, user1, depositAmount, STREAM_DURATION);

        streamer.createStream(user1, depositAmount, STREAM_DURATION);
        vm.stopPrank();
    }

    function testStreamWithdrawalEvent() public {
        // Setup: deposit tokens
        uint256 depositAmount = 2592000 * 10 ** stablecoin.decimals(); // Large enough to avoid zero rate
        vm.startPrank(user1);
        stablecoin.approve(address(streamer), depositAmount);
        uint256 streamId = streamer.createStream(user1, depositAmount, STREAM_DURATION);

        // Move time forward
        skip(15 days);

        // Calculate expected withdrawal
        uint256 streamRate = depositAmount / STREAM_DURATION;
        uint256 expectedWithdrawal = streamRate * 15 days;

        vm.expectEmit(true, true, false, true);
        emit TokenStreamer.StreamWithdrawal(streamId, user1, expectedWithdrawal);

        streamer.withdrawFromStream(streamId);
        vm.stopPrank();
    }

    function testMintAccessControlIssue() public {
        // Test that anyone can mint (this is the known bug)
        uint256 mintAmount = 1000 * 10 ** stablecoin.decimals();

        // User1 (not owner) can mint tokens to anyone
        vm.prank(user1);
        stablecoin.mint(user2, mintAmount);

        assertEq(stablecoin.balanceOf(user2), (10000000 + 1000) * 10 ** stablecoin.decimals());
    }

    // New tests for stream-specific functionality
    function testStreamDurationLimits() public {
        uint256 depositAmount = 1000 * 10 ** stablecoin.decimals();

        vm.startPrank(user1);
        stablecoin.approve(address(streamer), depositAmount * 3);

        // Test minimum duration
        vm.expectRevert(abi.encodeWithSelector(TokenStreamer.InvalidStreamDuration.selector));
        streamer.createStream(user1, depositAmount, 3000); // Less than 1 hour

        // Test maximum duration
        vm.expectRevert(abi.encodeWithSelector(TokenStreamer.InvalidStreamDuration.selector));
        streamer.createStream(user1, depositAmount, 3600 * 24 * 366); // More than 1 year

        // Test valid duration
        uint256 streamId = streamer.createStream(user1, depositAmount, 3600); // Exactly 1 hour
        assertTrue(streamId > 0);
        vm.stopPrank();
    }

    function testMultipleStreamsPerUser() public {
        uint256 depositAmount = 1000 * 10 ** stablecoin.decimals();

        vm.startPrank(user1);
        stablecoin.approve(address(streamer), depositAmount * 3);

        // Create multiple streams for the same user
        uint256 streamId1 = streamer.createStream(user1, depositAmount, STREAM_DURATION);
        uint256 streamId2 = streamer.createStream(user1, depositAmount, STREAM_DURATION / 2);
        uint256 streamId3 = streamer.createStream(user1, depositAmount, STREAM_DURATION * 2);

        // Verify all streams exist and have correct properties
        (, uint256 totalDeposited1,,, uint256 endTime1, bool exists1) = streamer.getStreamInfo(streamId1);
        (, uint256 totalDeposited2,,, uint256 endTime2, bool exists2) = streamer.getStreamInfo(streamId2);
        (, uint256 totalDeposited3,,, uint256 endTime3, bool exists3) = streamer.getStreamInfo(streamId3);

        assertTrue(exists1 && exists2 && exists3);
        assertEq(totalDeposited1, depositAmount);
        assertEq(totalDeposited2, depositAmount);
        assertEq(totalDeposited3, depositAmount);

        // Verify different end times
        assertTrue(endTime2 < endTime1);
        assertTrue(endTime1 < endTime3);

        // Verify user streams tracking
        uint256[] memory userStreamIds = streamer.getUserStreams(user1);
        assertEq(userStreamIds.length, 3);
        assertEq(userStreamIds[0], streamId1);
        assertEq(userStreamIds[1], streamId2);
        assertEq(userStreamIds[2], streamId3);

        vm.stopPrank();
    }

    function testNotStreamRecipientError() public {
        uint256 depositAmount = 1000 * 10 ** stablecoin.decimals();

        vm.startPrank(user1);
        stablecoin.approve(address(streamer), depositAmount);
        uint256 streamId = streamer.createStream(user2, depositAmount, STREAM_DURATION);
        vm.stopPrank();

        skip(15 days);

        // user1 tries to withdraw from user2's stream
        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSelector(TokenStreamer.NotStreamRecipient.selector));
        streamer.withdrawFromStream(streamId);
        vm.stopPrank();
    }

    function testStreamEndedError() public {
        uint256 depositAmount = 1000 * 10 ** stablecoin.decimals();

        vm.startPrank(user1);
        stablecoin.approve(address(streamer), depositAmount * 2);
        uint256 streamId = streamer.createStream(user1, depositAmount, STREAM_DURATION);

        // Move past stream end time
        skip(STREAM_DURATION + 1 days);

        // Try to add to ended stream
        vm.expectRevert(abi.encodeWithSelector(TokenStreamer.StreamEnded.selector));
        streamer.addToStream(streamId, depositAmount);

        vm.stopPrank();
    }

    function testInvalidRecipientError() public {
        uint256 depositAmount = 1000 * 10 ** stablecoin.decimals();

        vm.startPrank(user1);
        stablecoin.approve(address(streamer), depositAmount);

        vm.expectRevert(abi.encodeWithSelector(TokenStreamer.InvalidRecipient.selector));
        streamer.createStream(address(0), depositAmount, STREAM_DURATION);

        vm.stopPrank();
    }

    function testStreamDepositEvent() public {
        uint256 initialDeposit = 1000 * 10 ** stablecoin.decimals();
        uint256 additionalDeposit = 500 * 10 ** stablecoin.decimals();

        vm.startPrank(user1);
        stablecoin.approve(address(streamer), initialDeposit + additionalDeposit);

        // Create stream
        uint256 streamId = streamer.createStream(user1, initialDeposit, STREAM_DURATION);

        // Test StreamDeposit event when adding to stream
        vm.expectEmit(true, true, false, true);
        emit TokenStreamer.StreamDeposit(streamId, user1, additionalDeposit);

        streamer.addToStream(streamId, additionalDeposit);
        vm.stopPrank();
    }
}
