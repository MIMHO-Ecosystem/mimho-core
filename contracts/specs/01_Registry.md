> ⚠️ Contract addresses will be published only after official deployment and verification on BNB Chain.

# 🧠 MIMHO Registry — Ecosystem Source of Truth

> **MIMHO – the Meme Coin of the Future**  
> This document describes technical and operational behavior — not financial promises.  
> Este documento descreve comportamento técnico e operacional — não promessas financeiras.

---

## 👥 For Non-Technical Readers (Plain Explanation)

The MIMHO Registry is the **single on-chain source of truth** for the entire MIMHO ecosystem.

Instead of contracts, frontends, or users guessing which address is correct,  
**every official contract address is registered and resolved through the Registry**.

If a contract is not registered here, **it is not official**.

The Registry exists to eliminate:
- Address confusion
- Fake contracts
- Hardcoded dependencies
- Off-chain trust

The Registry:
- Does **not** hold funds
- Does **not** execute business logic
- Does **not** move tokens

Its only responsibility is to **map official module identifiers to official contract addresses**.

---

## 🔑 What the Registry Stores

The Registry stores mappings between:
- Module identifiers (`bytes32 keys`)
- Official contract addresses

Examples of registered modules:
- Token
- DAO
- Vesting
- Staking
- Presale
- Liquidity Bootstrapper
- Inject Liquidity
- Events Hub
- Marketplace
- Mart
- Burn
- Airdrop
- Locker
- Strategy Hub

Every critical dependency in the ecosystem is resolved through this contract.

---

## 🤔 Why This Matters

In many crypto projects:
- Contracts hardcode addresses
- Updates break integrations
- Frontend points to outdated contracts
- Users must trust announcements

In MIMHO:
- There is **one official registry**
- All modules ask the Registry who is official
- Updates are explicit and observable
- No silent changes are possible

If an address changes, the change is:
- On-chain
- Governed
- Auditable
- Transparent

---

## 👨‍💻 For Developers (Technical Summary)

The Registry follows a **registry-first architecture pattern**.

No ecosystem contract is allowed to:
- Hardcode addresses of other modules
- Assume external contract locations

Instead, contracts must:
- Resolve dependencies dynamically via the Registry
- Use canonical registry keys

---

## 🧭 Dependency Resolution Model

All modules must resolve dependencies using this flow:

- Query the Registry using a predefined key
- Retrieve the official contract address
- Interact only with that resolved address

This guarantees:
- Safe upgrades
- Modular architecture
- Reduced integration risk
- Clean audit surface

---

## 🔐 Governance Model

The Registry follows the MIMHO governance transition standard:

- Before DAO activation:
  - Controlled by the Founder
- After DAO activation:
  - Controlled exclusively by the DAO

There is **no permanent centralized control**.

All updates:
- Are explicit
- Are on-chain
- Are traceable

---

## 🔒 Security Guarantees

The Registry enforces:
- Explicit address setting
- Zero silent overrides
- No delegatecall
- No proxy logic
- No fund custody

If the Registry is paused or locked:
- No funds are at risk
- No state is corrupted

---

## 🧩 Role in the Ecosystem

The Registry acts as:
- The **map** of the ecosystem
- The **anchor** for integrations
- The **coordination layer** between contracts
- The foundation for Events Hub observability

Without the Registry:
- The ecosystem cannot safely evolve

---

## 🔗 Official Links

- Website: https://mimho.io  
- Whitepaper (PDF / IPFS):  
  https://emerald-high-grasshopper-50.mypinata.cloud/ipfs/bafkreie2kmjlu755hfwbiwlif53e4bybput3mlh47wgijznhuydcn3uqza  
- Roadmap (PDF / IPFS):  
  https://emerald-high-grasshopper-50.mypinata.cloud/ipfs/bafkreic64nzssnz3lefygdiq7ss6uiossgvtwkbke4y7jd3nymajfjjil4  
- Manifesto (PDF / IPFS):  
  https://emerald-high-grasshopper-50.mypinata.cloud/ipfs/bafkreibxorcfdjntylynzfd62yj7vj5dbyvjpytr6suishxncoo3rrsibi  

---

## ⚠️ Disclaimer

MIMHO documentation describes technical intentions and on-chain behavior.

Nothing in this document constitutes financial advice.  
Module behavior may evolve through governance and security reviews.
