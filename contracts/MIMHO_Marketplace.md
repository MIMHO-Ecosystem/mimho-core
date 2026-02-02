🛒 MIMHO Marketplace — Technical Documentation

Module: NFT Marketplace / Trustless Settlement Engine
Status: Final Specification (Immutable Rules)
Version: 1.0.0
Language: English


---

🌍 1. Overview

The MIMHO Marketplace is a fully on-chain, trustless NFT marketplace designed to handle the listing, sale, and settlement of NFTs for both the MIMHO Ecosystem and external users.

It acts as a neutral settlement protocol, ensuring that:

Sellers do not need to trust buyers

Buyers do not need to trust sellers

NFTs are escrowed on-chain

Payments and distributions are executed atomically


The Marketplace does not implement yield, staking, strategy, bonuses, or incentives. Its sole responsibility is secure NFT liquidation.


---

🧠 2. Core Design Principles

Trustless by Design — NFTs are held in escrow until sale or cancellation

Immutable Economics — Fees and splits are hardcoded and cannot be changed

DAO-First Revenue — The DAO is always the primary beneficiary

Neutrality — No curation, whitelisting, or subjective logic

Auditability — Minimal logic, explicit flows, on-chain events

Ecosystem Integration — Registry + Events Hub as backbone



---

🧩 3. NFT Classification (MIMHO vs External)

NFT classification is objective and deterministic:

MIMHO NFT: An NFT minted exclusively by the MIMHO Mart contract

External NFT: Any NFT not minted by the MIMHO Mart


The Marketplace does not maintain allowlists or local setters.

Classification rule:

> If nftContract == MIMHO_MART (resolved via MIMHORegistry) → MIMHO NFT



This guarantees:

Zero ambiguity

Zero configuration risk

Full audit transparency



---

📦 4. Supported Standards

ERC-721 (full support)

ERC-1155 (1/1 tokens supported in v1)

ERC-2981 (royalty standard)


All transfers use safeTransferFrom.


---

🔄 5. Marketplace Lifecycle

📝 5.1 Listing

1. Seller calls listNFT()


2. Ownership and approval are verified


3. NFT is transferred to Marketplace escrow


4. Listing is stored on-chain


5. Event is emitted to the Events Hub



💰 5.2 Purchase

1. Buyer calls buyNFT() with exact payment


2. Listing is validated


3. Royalties (ERC-2981) are paid if applicable


4. Marketplace fees are calculated


5. Fees are distributed


6. Seller or ecosystem receives proceeds


7. NFT is transferred to buyer


8. Events are emitted



❌ 5.3 Cancellation

Only the seller may cancel

NFT is returned immediately

No fees are charged



---

💸 6. Fees (Immutable)

🌐 6.1 External NFTs

Marketplace Fee: 1.00%

Distribution of the fee:

10% Founder

10% Marketing

10% Liquidity Injection (or Staking if paused)

70% DAO


🚀 6.2 MIMHO NFTs

Marketplace Fee: 0.50%

Distribution of the fee:

20% Founder

10% Liquidity Injection (or Staking if paused)

70% DAO


🏛️ 6.3 Ecosystem-Owned Sales

For NFTs sold directly by ecosystem contracts:

100% of the net sale value (after royalties) belongs to the ecosystem

Distribution:

20% Founder

10% Liquidity Injection (or Staking if paused)

70% DAO



There is no external seller in this mode.


---

🔐 7. Founder Fee Guarantee

The Founder SAFE address is hardcoded and immutable in the contract

It does not rely on the Registry or post-deployment configuration

Founder fees are always paid automatically on every applicable sale


This guarantees:

No configuration risk

No operational dependency

Permanent audit certainty



---

🎨 8. Royalties

Royalties are defined at mint time by the NFT contract (MIMHO Mart)

The Marketplace respects ERC-2981 when present

Royalties are paid before marketplace fee distribution

The Marketplace never alters or overrides royalty logic


This ensures full compatibility with external marketplaces.


---

🛡️ 9. Security Model

On-chain escrow (NFT custody)

Reentrancy protection

Strict ownership and approval checks

Fixed price (no price changes after listing)

Duplicate listing protection (one active listing per NFT)

Emergency pause (DAO / Owner)


Pausing disables new listings and purchases but does not cancel existing listings.


---

🧯 10. Fail-Safe Payout System

If any native token transfer fails:

The sale is not reverted

Funds are recorded as pending inside the contract

The recipient can claim later via claimPending()


This prevents:

Cascading failures

Denial-of-service by revert



---

📊 11. Transparency & Metrics

The Marketplace tracks on-chain counters:

Total volume (MIMHO NFTs)

Total volume (External NFTs)

Total fees distributed

Total royalties paid


All critical actions emit standardized Events Hub events:

NFT_LISTED

NFT_SOLD

LISTING_CANCELED

FEES_DISTRIBUTED

PAYOUT_PENDING


Each event includes a flag identifying MIMHO vs External NFTs.


---

🚫 12. Explicitly Out of Scope

The Marketplace deliberately does not include:

Auctions

Bidding systems

Dynamic pricing

Bonuses or rewards

Staking or strategy logic

Upgradeability

Fee setters or governance tuning


These exclusions are intentional to reduce attack surface.


---

🔗 13. Ecosystem Integration

The Marketplace integrates via MIMHORegistry for:

MIMHO Mart (NFT identity)

DAO address

Events Hub

Liquidity Injection module

Staking module


The Registry is the single source of truth for ecosystem addresses, except for the Founder SAFE which is hardcoded.


---

🏁 14. Conclusion

The MIMHO Marketplace is a production-grade, DAO-first NFT settlement protocol designed for long-term stability, external adoption, and maximum transparency.

Its immutable rules, minimal logic, and trustless escrow model make it suitable for both ecosystem-native NFTs and third-party creators without compromising security or governance.


---

MIMHO – the Meme Coin of the Future 🚀
