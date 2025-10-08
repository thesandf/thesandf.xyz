// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "./IMintableToken.sol";

// Destination Bridge (e.g., Polygon) - Fixed for OpenZeppelin v5
contract DestinationBridge {
    using ECDSA for bytes32; // Still valid for ECDSA operations like recover
    using MessageHashUtils for bytes32; // Add this for message hashing

    address public validator;
    address public bridgedToken;
    // mapping(bytes32 => bool) public processedMessages;

    constructor(address _validator, address _token) {
        validator = _validator;
        bridgedToken = _token;
    }

    function withdraw(address to, uint256 amount, uint256 nonce, bytes32 sourceTxHash, bytes memory signature)
        external
    {
        bytes32 messageHash = keccak256(abi.encodePacked(to, amount, nonce, sourceTxHash));
        bytes32 ethSignedMessageHash = messageHash.toEthSignedMessageHash(); // Use MessageHashUtils
        address signer = ethSignedMessageHash.recover(signature); // ECDSA.recover
        require(signer == validator, "Invalid signature");

        // Removed processedMessages check to allow replays
        // require(!processedMessages[messageHash], "Message already processed");
        // processedMessages[messageHash] = true;

        IMintableToken(bridgedToken).mint(to, amount);
    }
}
