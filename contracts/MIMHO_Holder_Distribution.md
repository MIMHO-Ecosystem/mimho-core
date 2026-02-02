> ⚠️ Contract addresses will be published only after official deployment and verification on BNB Chain.


📘 MIMHO Holder Distribution 

Version: v1.0.0
Status: Production-ready
License: MIT


**🔍 Overview**
The MIMHO Holder Distribution Vault is a non-custodial, on-chain distribution contract designed to fairly and transparently distribute MIMHO tokens to eligible holders, without promises, without yield guarantees, and without administrative custody.
This contract is part of the MIMHO Trust & Transparency Infrastructure, reinforcing the project’s philosophy of:
Clear rules, immutable code, and visible actions — not promises.

---

##🎯 Purpose
The contract exists to:
Receive MIMHO tokens voluntarily deposited by the founder or DAO
Distribute 100% of deposited tokens to eligible holders
Prevent favoritism, abuse, or double claims
Allow holders to claim autonomously (pull-based)
Emit standardized on-chain events for full transparency (HUD-ready)

---

##🧠 Design Philosophy

1️⃣ Non-Custodial by Design
❌ No withdraw()
❌ No emergencyWithdraw()
❌ No admin rescue functions
Tokens sent to this contract cannot be reclaimed by the founder or DAO.

2️⃣ Pull-Based Distribution
Holders claim manually using claim()
Each wallet pays its own gas
Eliminates mass-send risks and gas explosions
Prevents selective or manual payouts

3️⃣ Founder Neutrality
Founder is permanently excluded
Ecosystem contracts are excluded
No admin can claim tokens
No wallet can claim twice per round

4️⃣ Transparency First
Every critical action:
emits on-chain events
is visible on explorers
is forwarded to the MIMHO Events Hub (best-effort)

---

##🧱 Contract Architecture
Core Components
Component
Description
Registry
Resolves Events Hub and ecosystem contracts
Events Hub
Emits standardized HUD events
Merkle Tree
Defines eligible wallets and amounts
Rounds
Discrete distribution cycles
Claim Guard
Prevents double claims

---

##🔁 Distribution Model
Distribution Rounds
Each distribution happens inside a round.
A round contains:
Merkle root (eligibility snapshot)
Total token amount allocated
Claimed amount tracker
Start time
Optional end time
Active flag
Only one active round is allowed at a time.
Distribution Flow
Tokens are deposited into the vault
Founder or DAO opens a round
Merkle root defines (wallet, amount, roundId)
Eligible holders call claim()
Tokens are transferred directly to holders
Round may be closed manually
Unclaimed tokens remain in the vault for future rounds.

**✅ Eligibility Rules**
A wallet can claim if all conditions are met:
Included in the Merkle tree
Not excluded
Not an ecosystem contract
Has not claimed in the current round
Calls within the round’s active window (if any)
Eligibility is immutable per round.

**🚫 Exclusion System**
The contract maintains a permanent exclusion list.
Automatically Excluded
Founder wallet (on deployment)
Ecosystem contracts (via Registry)
Manually Excluded
Bots
Abuse wallets
Technical addresses
**📌 Exclusion is one-way and cannot be reverted.**

##🔐 Security Model
Implemented Protections
ReentrancyGuard
Double-claim prevention
Merkle proof validation
Round-specific proofs
No external swaps
No upgrade hooks
Accepted Constraints
Tokens sent by mistake are locked
Snapshot logic relies on off-chain Merkle generation
These are intentional design decisions to preserve trustlessness.

---

##🧾 Events Emitted
Event
Description
TokensDeposited
Tokens deposited into vault
RoundOpened
New distribution round
Claimed
Successful holder claim
RoundClosed
Round closed
AddressExcluded
Address permanently excluded
DAOSet
DAO address set
DAOActivated
DAO control activated
All events are also forwarded to the MIMHO Events Hub using a best-effort try/catch pattern.

---

##🔑 Access Control
Founder / DAO Permissions
Deposit tokens
Open distribution rounds
Close rounds
Exclude addresses
Pause / unpause contract
Set and activate DAO
Explicitly Forbidden
Withdraw tokens
Modify claims
Change eligibility mid-round
Override distribution math

---

##🧩 DAO Transition
Initially controlled by the founder
DAO can be activated later
Control transfer does not affect:
past rounds
claims
exclusion history
non-custodial guarantees

---

##🔢 Versioning
The contract exposes:
Copiar código
Solidity
string public constant version = "v1.0.0";
Future upgrades require new contracts, not replacements.

##🧠 Key Guarantees
✔ 100% on-chain
✔ No promises
✔ No yield claims
✔ No admin custody
✔ No hidden mechanics
✔ Fully auditable

---

##📌 Summary

The MIMHO Holder Distribution Vault is a trust-first utility contract, built to reward holders only when the ecosystem chooses to act, never by obligation.
It is intentionally simple, rigid, and transparent — exactly what long-term holders expect.
