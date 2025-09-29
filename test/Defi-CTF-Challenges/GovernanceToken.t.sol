// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../../src/ctf-solutions/Defi-CTF-Challenges/GovernanceToken.sol";

contract GovernanceTokenTest is Test {
    GovernanceToken public token;
    GroupStaking public staking;
    address public owner;
    address public user1;
    address public user2;
    address public user3;

    function setUp() public {
        owner = address(this);
        user1 = address(0x1);
        user2 = address(0x2);
        user3 = address(0x3);

        // Deploy token and staking contracts
        token = new GovernanceToken();
        staking = new GroupStaking(address(token));

        // Give some tokens to users for testing
        token.transfer(user1, 1000 * 10 ** 18);
        token.transfer(user2, 1000 * 10 ** 18);
        token.transfer(user3, 1000 * 10 ** 18);
    }

    // GovernanceToken Tests
    function testInitialSupply() public {
        assertEq(token.totalSupply(), 1000000 * 10 ** 18);
        assertEq(token.balanceOf(owner), 997000 * 10 ** 18);
        assertEq(token.balanceOf(user1), 1000 * 10 ** 18);
    }

    function testMinting() public {
        uint256 initialSupply = token.totalSupply();
        uint256 mintAmount = 500 * 10 ** 18;

        token.mint(user2, mintAmount);

        assertEq(token.totalSupply(), initialSupply + mintAmount);
        assertEq(token.balanceOf(user2), 1000 * 10 ** 18 + mintAmount);
    }

    function testBlacklisting() public {
        // Initially not blacklisted
        assertFalse(token.blacklisted(user1));

        // Blacklist user1
        token.updateUserStatus(user1, true);
        assertTrue(token.blacklisted(user1));

        // Unblacklist user1
        token.updateUserStatus(user1, false);
        assertFalse(token.blacklisted(user1));
    }

    function testTransferWithBlacklist() public {
        // Test transfer from non-blacklisted user
        vm.prank(user1);
        token.transfer(user2, 100 * 10 ** 18);
        assertEq(token.balanceOf(user2), 1100 * 10 ** 18);

        // Blacklist user1
        token.updateUserStatus(user1, true);

        // Test transfer from blacklisted user should fail
        vm.prank(user1);
        vm.expectRevert("Sender is blacklisted");
        token.transfer(user2, 100 * 10 ** 18);

        // Test transfer to blacklisted user should fail
        token.updateUserStatus(user1, false);
        token.updateUserStatus(user2, true);

        vm.prank(user1);
        vm.expectRevert("Recipient is blacklisted");
        token.transfer(user2, 100 * 10 ** 18);
    }

    function testTransferToZeroAddress() public {
        vm.expectRevert(
            abi.encodeWithSignature("ERC20InvalidReceiver(address)", address(0))
        );
        token.transfer(address(0), 100 * 10 ** 18);
    }

    function testApproveToZeroAddress() public {
        vm.expectRevert(
            abi.encodeWithSignature("ERC20InvalidSpender(address)", address(0))
        );
        token.approve(address(0), 100 * 10 ** 18);
    }

    function testTransferFromZeroAddress() public {
        vm.prank(address(0));
        vm.expectRevert(
            abi.encodeWithSignature("ERC20InvalidSender(address)", address(0))
        );
        token.transfer(address(1), 100 * 10 ** 18);
    }

    function testTransferFromToZeroAddress() public {
        vm.prank(user1);
        token.approve(user2, 1000 * 10 ** 18);

        vm.prank(user2);
        vm.expectRevert(
            abi.encodeWithSignature("ERC20InvalidReceiver(address)", address(0))
        );
        token.transferFrom(user1, address(0), 100 * 10 ** 18);
    }

    function testTransferInsufficientBalance() public {
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSignature(
                "ERC20InsufficientBalance(address,uint256,uint256)",
                user1,
                1000 * 10 ** 18,
                2000 * 10 ** 18
            )
        );
        token.transfer(user2, 2000 * 10 ** 18);
    }

    function testTransferFromInsufficientBalance() public {
        vm.prank(user1);
        token.approve(user2, 2000 * 10 ** 18);

        vm.prank(user2);
        vm.expectRevert(
            abi.encodeWithSignature(
                "ERC20InsufficientBalance(address,uint256,uint256)",
                user1,
                1000 * 10 ** 18,
                2000 * 10 ** 18
            )
        );
        token.transferFrom(user1, address(0x3), 2000 * 10 ** 18);
    }

    function testTransferFromInsufficientAllowance() public {
        vm.prank(user1);
        token.approve(user2, 50 * 10 ** 18);

        vm.prank(user2);
        vm.expectRevert(
            abi.encodeWithSignature(
                "ERC20InsufficientAllowance(address,uint256,uint256)",
                user2,
                50 * 10 ** 18,
                100 * 10 ** 18
            )
        );
        token.transferFrom(user1, address(0x3), 100 * 10 ** 18);
    }

    function testTransferFromWithBlacklist() public {
        // Approve user2 to spend user1's tokens
        vm.prank(user1);
        token.approve(user2, 1000 * 10 ** 18);

        // Test transferFrom with non-blacklisted users
        vm.prank(user2);
        token.transferFrom(user1, address(0x4), 100 * 10 ** 18); // Use address(0x4) instead
        assertEq(token.balanceOf(address(0x4)), 100 * 10 ** 18);
        assertEq(token.balanceOf(user1), 900 * 10 ** 18); // user1 should have 900 left

        // Blacklist sender
        token.updateUserStatus(user1, true);

        // Test transferFrom with blacklisted sender should fail
        vm.prank(user2);
        vm.expectRevert("Sender is blacklisted");
        token.transferFrom(user1, address(0x3), 100 * 10 ** 18);

        // Test transferFrom to blacklisted recipient should fail
        token.updateUserStatus(user1, false);
        token.updateUserStatus(address(0x5), true);

        vm.prank(user2);
        vm.expectRevert("Recipient is blacklisted");
        token.transferFrom(user1, address(0x5), 100 * 10 ** 18);
    }

    // GroupStaking Tests
    function testCreateStakingGroup() public {
        address[] memory members = new address[](3);
        members[0] = user1;
        members[1] = user2;
        members[2] = user3;

        uint256[] memory weights = new uint256[](3);
        weights[0] = 40;
        weights[1] = 35;
        weights[2] = 25;

        uint256 groupId = staking.createStakingGroup(members, weights);
        assertEq(groupId, 1);

        (
            uint256 id,
            uint256 totalAmount,
            address[] memory groupMembers,
            uint256[] memory groupWeights
        ) = staking.getGroupInfo(groupId);

        assertEq(id, groupId);
        assertEq(totalAmount, 0);
        assertEq(groupMembers.length, 3);
        assertEq(groupWeights.length, 3);
        assertEq(groupMembers[0], user1);
        assertEq(groupWeights[0], 40);
    }

    function testStakeToGroup() public {
        // Create group first
        address[] memory members = new address[](2);
        members[0] = user1;
        members[1] = user2;

        uint256[] memory weights = new uint256[](2);
        weights[0] = 60;
        weights[1] = 40;

        uint256 groupId = staking.createStakingGroup(members, weights);

        // Approve and stake tokens
        uint256 stakeAmount = 100 * 10 ** 18;
        vm.startPrank(user1);
        token.approve(address(staking), stakeAmount);
        staking.stakeToGroup(groupId, stakeAmount);
        vm.stopPrank();

        (, uint256 totalAmount,,) = staking.getGroupInfo(groupId);
        assertEq(totalAmount, stakeAmount);
        assertEq(token.balanceOf(address(staking)), stakeAmount);
    }

    function testWithdrawFromGroup() public {
        // Create group and stake tokens
        address[] memory members = new address[](2);
        members[0] = user1;
        members[1] = user2;

        uint256[] memory weights = new uint256[](2);
        weights[0] = 60;
        weights[1] = 40;

        uint256 groupId = staking.createStakingGroup(members, weights);

        uint256 stakeAmount = 100 * 10 ** 18;
        vm.startPrank(user1);
        token.approve(address(staking), stakeAmount);
        staking.stakeToGroup(groupId, stakeAmount);
        vm.stopPrank();

        // Record balances before withdrawal
        uint256 member1BalanceBefore = token.balanceOf(user1);
        uint256 member2BalanceBefore = token.balanceOf(user2);

        // Withdraw half the staked amount - must be done by group owner (this contract)
        uint256 withdrawAmount = 50 * 10 ** 18;
        staking.withdrawFromGroup(groupId, withdrawAmount);

        // Check balances after withdrawal
        assertEq(
            token.balanceOf(user1), member1BalanceBefore + (withdrawAmount * 60 / 100)
        );
        assertEq(
            token.balanceOf(user2), member2BalanceBefore + (withdrawAmount * 40 / 100)
        );

        // Check remaining group balance
        (, uint256 totalAmount,,) = staking.getGroupInfo(groupId);
        assertEq(totalAmount, stakeAmount - withdrawAmount);
    }

    function testWithdrawFromGroupWithBlacklistedMember() public {
        // Test the bug where blacklisted member blocks all distributions
        address[] memory members = new address[](2);
        members[0] = user1;
        members[1] = user2;

        uint256[] memory weights = new uint256[](2);
        weights[0] = 60;
        weights[1] = 40;

        uint256 groupId = staking.createStakingGroup(members, weights);

        uint256 stakeAmount = 100 * 10 ** 18;
        vm.startPrank(user1);
        token.approve(address(staking), stakeAmount);
        staking.stakeToGroup(groupId, stakeAmount);
        vm.stopPrank();

        // Blacklist user2
        token.updateUserStatus(user2, true);

        // Try to withdraw as the group owner - should fail because user2 is blacklisted
        uint256 withdrawAmount = 50 * 10 ** 18;
        vm.expectRevert("Recipient is blacklisted");
        staking.withdrawFromGroup(groupId, withdrawAmount);
    }

    function testGroupMembership() public {
        address[] memory members = new address[](2);
        members[0] = user1;
        members[1] = user2;

        uint256[] memory weights = new uint256[](2);
        weights[0] = 50;
        weights[1] = 50;

        uint256 groupId = staking.createStakingGroup(members, weights);

        assertTrue(staking.isMemberOfGroup(groupId, user1));
        assertTrue(staking.isMemberOfGroup(groupId, user2));
        assertFalse(staking.isMemberOfGroup(groupId, user3));
    }

    function testInvalidGroupCreation() public {
        address[] memory members = new address[](2);
        members[0] = user1;
        members[1] = user2;

        uint256[] memory weights = new uint256[](2);
        weights[0] = 60;
        weights[1] = 30; // Sum is 90, should be 100

        vm.expectRevert("Weights must sum to 100");
        staking.createStakingGroup(members, weights);
    }

    function testEmptyMembersList() public {
        address[] memory members = new address[](0);
        uint256[] memory weights = new uint256[](0);

        vm.expectRevert("Empty members list");
        staking.createStakingGroup(members, weights);
    }

    function testMembersWeightsLengthMismatch() public {
        address[] memory members = new address[](2);
        members[0] = user1;
        members[1] = user2;

        uint256[] memory weights = new uint256[](1);
        weights[0] = 100;

        vm.expectRevert("Members and weights length mismatch");
        staking.createStakingGroup(members, weights);
    }

    function testNonExistentGroupStake() public {
        uint256 nonExistentGroupId = 999;
        uint256 stakeAmount = 100 * 10 ** 18;

        vm.startPrank(user1);
        token.approve(address(staking), stakeAmount);
        vm.expectRevert("Group does not exist");
        staking.stakeToGroup(nonExistentGroupId, stakeAmount);
        vm.stopPrank();
    }

    function testInsufficientGroupBalance() public {
        // Create group and stake tokens
        address[] memory members = new address[](2);
        members[0] = user1;
        members[1] = user2;

        uint256[] memory weights = new uint256[](2);
        weights[0] = 60;
        weights[1] = 40;

        uint256 groupId = staking.createStakingGroup(members, weights);

        uint256 stakeAmount = 100 * 10 ** 18;
        vm.startPrank(user1);
        token.approve(address(staking), stakeAmount);
        staking.stakeToGroup(groupId, stakeAmount);
        vm.stopPrank();

        // Try to withdraw more than staked
        uint256 withdrawAmount = 200 * 10 ** 18;
        vm.prank(user1);
        vm.expectRevert("Insufficient group balance");
        staking.withdrawFromGroup(groupId, withdrawAmount);
    }

    function testNonExistentGroupInfo() public {
        uint256 nonExistentGroupId = 999;
        vm.expectRevert("Group does not exist");
        staking.getGroupInfo(nonExistentGroupId);
    }

    function testNonMemberWithdraw() public {
        // Create group and stake tokens
        address[] memory members = new address[](2);
        members[0] = user1;
        members[1] = user2;

        uint256[] memory weights = new uint256[](2);
        weights[0] = 60;
        weights[1] = 40;

        uint256 groupId = staking.createStakingGroup(members, weights);

        uint256 stakeAmount = 100 * 10 ** 18;
        vm.startPrank(user1);
        token.approve(address(staking), stakeAmount);
        staking.stakeToGroup(groupId, stakeAmount);
        vm.stopPrank();

        // Try to withdraw as non-member (user3 is not the group owner)
        vm.prank(user3);
        vm.expectRevert("Not the group owner");
        staking.withdrawFromGroup(groupId, 50 * 10 ** 18);
    }
}
