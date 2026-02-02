#🧿 MIMHO Mart — Official NFT Minting & Marketplace Protocol

The MIMHO Mart is the canonical NFT issuance and secondary trading protocol of the MIMHO Ecosystem.
It operates as a core on-chain infrastructure layer, responsible for enforcing protocol-level rules around NFT creation, distribution, royalties, and transparency, while remaining fully governed by DAO principles.
This repository and its documentation serve as the public, verifiable reference for how NFTs are minted and traded within the MIMHO Ecosystem.

---

##🎯 Purpose of the MIMHO Mart
The MIMHO Mart exists to guarantee that all NFTs within the ecosystem are created and traded under a single, auditable, and immutable rule set.
Its primary goals are:
Establish a single source of truth for NFT issuance
Eliminate fragmented or hidden minting logic
Enforce protocol-level permissions and mint rules
Provide transparent, on-chain royalty distribution
Enable DAO-governed evolution without redeploying dependent contracts
No NFT may be minted or recognized as official within the MIMHO Ecosystem unless it originates from the MIMHO Mart.

---

##🏗️ Architectural Role in the Ecosystem
The MIMHO Mart occupies a foundational position in the ecosystem architecture.
It interacts with — but remains logically isolated from — other modules:
MIMHO Registry: Dependency resolution and ecosystem contract validation
MIMHO Events Hub (HUD): Public event broadcasting
MIMHO Strategy Hub: NFT utility and bonus evaluation
DAO / Governance: Permissioning and protocol control
Each module has a single responsibility, ensuring long-term maintainability and audit clarity.

---

##🔐 Canonical NFT Minting
Single Issuance Point
All NFTs within the MIMHO Ecosystem are minted exclusively by the MIMHO Mart.
This guarantees:
No parallel mint contracts
No duplicated ERC-721 issuers
No hidden or privileged mint paths
The Mart acts as a gatekeeper, not a decision-maker:
ecosystem contracts decide when to mint, the Mart enforces how.

---

##🧩 Minting Permissions & Security Model
Contract-Level Authorization
An NFT mint operation is permitted only if the caller is:
A contract registered in the MIMHO Registry
OR the active DAO
OR the Owner (prior to DAO activation)
Direct user calls or unregistered contracts are strictly rejected.
Mint-Type Whitelisting
In addition to validating who is calling, the Mart validates what can be minted.
NFTs are classified by mint type, for example:
BADGE — Governance and DAO recognition
BOOST — Staking-related utilities
COLLECTIBLE — Store or campaign NFTs
ACHIEVEMENT — Games and quizzes
CERTIFICATE — Veritas / Certify modules
Each ecosystem contract is authorized to mint only specific types, preventing logical misuse or cross-module abuse.

---

##🔁 Minting Lifecycle
An ecosystem contract determines an NFT should be issued
The contract resolves the MIMHO Mart via the Registry
A mint request is submitted with recipient, type, and metadata
The Mart validates permissions and mint rules
The NFT is minted
All actions are recorded on-chain and broadcast to the HUD
Failures revert deterministically and are never silent.

---

##🖼️ Metadata & URI Management
The MIMHO Mart supports:
Base URI configuration
Per-token URI overrides
DAO-controlled metadata updates
This enables compatibility with IPFS, Pinata, Arweave, and future decentralized storage systems.

---

##🛒 Secondary Marketplace (On-Chain)
The MIMHO Mart includes an optional built-in marketplace for secondary NFT trading.
Key properties:
User-to-user fixed-price listings
ERC20-based payments (resolved via Registry)
Fully on-chain execution
No off-chain order books
The marketplace exists to reinforce transparency and protocol enforcement, not to replace external markets.

---

##💰 Protocol Royalties
Royalty Policy
All secondary sales executed through the MIMHO Mart are subject to a fixed 5% protocol royalty.
This rule is immutable by design.
Royalty Distribution
The 5% royalty is split as follows:
20% → Founder
10% → Staking
70% → DAO
Example (sale price = 100):
Royalty total: 5
Founder: 1
Staking: 0.5
DAO: 3.5
Percentages are defined as constants and cannot be altered post-deployment.

---

##🔄 Royalty Execution Guarantees
Royalties are calculated and distributed atomically
Transfers occur before NFT ownership changes
Fallback logic ensures no funds are trapped
Every split is publicly emitted as an event
This ensures economic transparency and auditability.

---

##📡 Events, HUD & Transparency
Every meaningful action emits:
A local on-chain event
A mirrored event to the MIMHO Events Hub (HUD) using best-effort execution
This guarantees:
Real-time dashboards
Public traceability
Zero dependency on private backends
Event emission failures never break user transactions.

---

##🚨 Emergency Controls
The MIMHO Mart includes protocol-standard emergency controls:
pauseEmergencial()
unpause()
When paused:
Minting is disabled
Marketplace operations are disabled
Other ecosystem modules continue uninterrupted
This provides systemic safety without cascading failures.

---

##🏛️ Governance & Ownership Model
Governed via onlyDAOorOwner pattern
Safe transition from Owner to DAO
No irreversible ownership renunciation
DAO authority activated explicitly
This ensures governance continuity and prevents accidental loss of control.

---

##🧠 Strategy Hub Compatibility
The MIMHO Mart deliberately does not calculate or apply bonuses.
NFT utility is evaluated independently by the MIMHO Strategy Hub, allowing:
Instant bonus updates on NFT transfers
No coupling between minting and utility logic
Clean separation between issuance and strategy

---

##⛽ Gas Efficiency & Safety
No unbounded loops
No global dynamic lists
Constant-time permission checks
Predictable gas usage
Designed for long-term scalability, not short-term convenience.

---

##🔐 Security & Audit Posture
No ETH custody
No privileged withdrawals
No mutable royalty rules
No circular dependencies
Fully deterministic execution
The MIMHO Mart is designed to be boring to audit — by intention.

---

##🏁 Conclusion
The MIMHO Mart is not a feature contract.
It is a protocol primitive.
It defines how value, identity, and ownership are created and exchanged inside the MIMHO Ecosystem — transparently, verifiably, and under DAO governance.
Transparency is not an option. It is the protocol.
