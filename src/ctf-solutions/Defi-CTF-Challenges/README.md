# Hans CTF Challenges – DeFiHub Protocol

Welcome to **Hans CTF Challenges**, where Web3 security meets hands-on learning! 🦸‍♂️
This repository provides **vulnerable smart contracts** from the DeFiHub protocol for auditing, testing, and skill-building. Created By [Hans Friese](https://x.com/hansfriese).

*Full credit to [Hans Friese](https://x.com/hansfriese), co-founder of [Cyfrin](https://cyfrin.com).*

---

## About DeFiHub

**DeFiHub** is a decentralized finance protocol combining **governance, liquidity provision, and token streaming** into a unified ecosystem. The protocol delivers essential financial services with **simplicity, efficiency, and security**.

### Core Components

#### 1. GovernanceToken & GroupStaking

**File:** `src/GovernanceToken.sol`

* ERC20-compliant governance token (DFHG) with controlled minting
* User status management and transfer restrictions for security
* Collective staking pools for optimized gas and proportional rewards

#### 2. LiquidityPool & PoolShare

**File:** `src/LiquidityPool.sol`

* ETH deposits tracked via share-based system (LPS tokens)
* Time-locked withdrawals prevent flash loan attacks
* Signature-based reward claiming with proxy deposit support
* Fee collection (10%) supports protocol development

#### 3. StableCoin & TokenStreamer

**File:** `src/StableCoin.sol`

* Gas-optimized ERC20 stablecoin (USDS) with flexible minting
* Token streaming for linear vesting and rewards
* Multi-stream support per user; tokens released predictably over time

---

## User Flows

### Governance Participation

1. Acquire DFHG tokens
2. Create or join staking groups
3. Stake collectively to optimize rewards
4. Receive proportional rewards
5. Participate in governance voting

### Liquidity Provision

1. Deposit ETH into the LiquidityPool
2. Receive LPS tokens representing pool shares
3. Accrue rewards automatically
4. Claim rewards securely with signatures
5. Withdraw after time-lock

### Token Streaming

1. Approve USDS allowance for TokenStreamer
2. Create streams with `createStream()`
3. Add tokens via `addToStream()`
4. Withdraw available tokens with `withdrawFromStream()`
5. Monitor streams using `getStreamInfo()` and `getUserStreams()`

---

## Smart Contract Architecture

```
DeFiHub Protocol
├── GovernanceToken.sol
│   ├── GovernanceToken (ERC20)
│   └── GroupStaking
├── LiquidityPool.sol
│   ├── PoolShare (ERC20Burnable)
│   └── LiquidityPool
└── StableCoin.sol
    ├── StableCoin (ERC20)
    └── TokenStreamer
```

---

## Known Issues for CTF Practice

* **StableCoin.sol – `mint` function:** unrestricted minting allows anyone to create tokens.

```solidity
function mint(address to, uint256 amount) external {
    _mint(to, amount);
    emit TokensMinted(to, amount);
}
```

*Impact:* Critical – unlimited minting can compromise protocol integrity.

These issues are intentional for **learning and auditing practice**.

---

## Security Features

* **Access Control:** Owner-based governance, token minting, blacklisting
* **Economic Security:** Time-locked withdrawals, proportional reward distribution, protocol fees
* **Technical Security:** Signature-based reward claiming, overflow protection (Solidity 0.8+), detailed event logging

**Note:** Trusted administrators control key functions; verify ownership before interaction.

---

## How to Participate

### 1. Set Up Environment

```bash
git clone https://github.com/thesandf/thesandf.xyz.git
cd thesandf.xyz
forge test -vvv
```

### 2. Audit Contracts

* Identify vulnerabilities: reentrancy, overflows, unprotected functions
* Write Foundry tests (`.t.sol`) demonstrating exploits
* Propose secure fixes using best practices

### 3. Report Your Findings

Use this Markdown template:

```markdown
### [S-#] TITLE

**Description:** 

**Impact:** 

**Proof of Concept:** 

**Recommended Mitigation:** 
```

### 4. Submit Your Report

* **GitHub Issues:** Use the audit template
* **GitHub Discussions:** Post in “Hans CTF Challenges” category
* **X (@THE_SANDF):** Share PoC snippets

**Rules:** Conduct blind audits; do **not reference solved external issues**.

---

## Development and Testing

```bash
# Run complete test suite
forge test

# Run contract-specific tests
forge test --match-contract GovernanceTokenTest
forge test --match-contract LiquidityPoolTest
forge test --match-contract StableCoinTest

# Verbose output
forge test -vvv
```

---

## Rewards & Recognition

* **Recognition:** Featured on **thesandf.xyz “Hall of Heroes”**
* **Community Perks:** Early access to case studies, badges, beta audit program invites
* **Portfolio Value:** Strong reports boost your Web3 career prospects

---

## Ready to Battle Bugs?

Audit **Hans CTF Challenges**, submit reports via GitHub, or tag **@THE_SANDF** on X.
Secure the Web3 multiverse! 🌐

🏗️ [Start the Challenge](https://github.com/thesandf/thesandf.xyz/tree/main/src/ctf-solutions/Defi-CTF-Challenges) | 💬 [Discuss](https://github.com/thesandf/thesandf.xyz/discussions) | Follow [@THE_SANDF](https://x.com/THE_SANDF)

---
