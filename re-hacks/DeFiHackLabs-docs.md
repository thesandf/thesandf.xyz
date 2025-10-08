# Hands-on with DeFiHackLabs - Practice Real DeFi Exploits Safely

Welcome, defenders of the multiverse! 🕵️‍♂️

At **TheSandF.xyz**, we don’t just read stories about DeFi hacks - we **practice them safely**, learn the mechanics, and understand how to defend against them. This post invites you to dive into **DeFiHackLabs**, a Foundry-based collection of reproduced DeFi exploits, and turn theory into hands-on skills.

> ⚠️ **Safety first:** All exercises are **local only**. Never deploy vulnerable contracts to mainnet. Use ephemeral environments like Foundry/Anvil.

---

##  Why practice?

Each case study on TheSandF.xyz (e.g., *Black Widow - Red Room Vault*) tells a story of a hack. Now you can:

* Move from **story → PoC → run locally → inspect → patch**
* Explore the mechanics of real-world exploits: Access Control, Reentrancy, Oracle manipulation, and more
* Build confidence in auditing and reproducing vulnerabilities safely
* Contribute back to the community with insights, fixes, or improved tests

Hands-on practice is the fastest way to **master Web3 security**.

---

##  Get started

From your local clone of **thesandf.xyz**:

```bash
# initialize submodule (if not already)
git submodule update --init re-hacks/DeFiHackLabs

# enter the practice folder
cd re-hacks/DeFiHackLabs

# install Foundry if needed:
# https://book.getfoundry.sh/getting-started/installation

# run all PoCs / tests
forge test
```

To try a single PoC (example):

```bash
forge test --match-test testExploitBlackWidow
```

---

## 🏁 Recommended workflow

1. Pick a case study from TheSandF.xyz (e.g., *Black Widow*).
2. Scroll to the `vuln` block - note `source_local`, `test_name`, and `source_permalink`.
3. If you just want to **read the PoC**, open `source_permalink`.
4. To **run it locally**, clone the repo with submodules and run the corresponding test:

   ```bash
   cd re-hacks/DeFiHackLabs
   forge test --match-test <test_name>
   ```
5. Inspect the code, experiment with assertions, or try a minimal patch to see how mitigation works.
6. Share your learning - open a PR, submit a discussion, or add notes to the case study.

---

## 🎓 What you’ll learn

By practicing, you’ll understand:

* How exploits are encoded as reproducible PoC tests
* Attacker flows for different vulnerability classes (Access Control, Reentrancy, Oracle issues, etc.)
* How to verify fixes using tests
* How to safely experiment with mitigations

Hands-on experience bridges the gap between reading about hacks and defending real-world protocols.

---

## Ethics & safety

* **Local practice only** - never deploy vulnerable contracts to live networks.
* Use ephemeral test environments (Anvil / Foundry).
* Discover a live vulnerability? Follow responsible disclosure. Do **not** exploit.

---

## Resources

* DeFiHackLabs (upstream repo): [https://github.com/SunWeb3Sec/DeFiHackLabs](https://github.com/SunWeb3Sec/DeFiHackLabs)
* Foundry: [https://book.getfoundry.sh](https://book.getfoundry.sh)

---

Ready to become a hands-on Web3 defender?  Dive in, run the PoCs, and start mastering the vulnerabilities that matter.

> The multiverse needs you - practice safely, learn deeply, and contribute boldly. 

## Credits

Full credit goes to the maintainers and contributors of DeFiHackLabs for building and maintaining the excellent PoC collection that powers our hands‑on practice.
If you find these exercises useful, please star and contribute to the upstream project:

**DeFiHackLabs (SunWeb3Sec & contributors)** [https://github.com/SunWeb3Sec/DeFiHackLabs](https://github.com/SunWeb3Sec/DeFiHackLabs)

---
