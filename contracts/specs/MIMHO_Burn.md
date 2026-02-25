> ⚠️ Contract addresses will be published only after official deployment and verification on BNB Chain.
>
> # 🎁 MIMHO Airdrop — Controlled Distribution Module

> **MIMHO – the Meme Coin of the Future**  
> This document describes technical and operational behavior — not financial promises.  
> Este documento descreve comportamento técnico e operacional — não promessas financeiras.

---

## 👥 For Non-Technical Readers (Plain Explanation)

The MIMHO Airdrop is a **controlled distribution mechanism** used to deliver tokens to users
based on predefined rules.

It is **not** a free-for-all system.

Every airdrop distribution follows strict, public, and verifiable logic enforced by smart contracts.

The airdrop exists to:

- Distribute tokens fairly
- Prevent abuse and bots
- Guarantee transparency
- Ensure no manual intervention

If a token is distributed, it is **provably recorded on-chain**.

---

## 🎯 What the Airdrop Is (and Is Not)

The MIMHO Airdrop:

- Distributes tokens based on predefined eligibility
- Uses deterministic rules
- Is fully on-chain and auditable

The MIMHO Airdrop:

- Does **not** mint new tokens
- Does **not** allow arbitrary manual transfers
- Does **not** depend on trust in the team

No wallet receives tokens outside the rules.

---

## 🔍 Distribution Rules (High Level)

- Airdrop tokens are **pre-allocated** to the contract
- The contract can only distribute what it already holds
- Each claim is validated before execution
- Double-claims are impossible by design

If the contract runs out of tokens, distribution **stops automatically**.

---

## 👨‍💻 For Developers (Technical Summary)

The Airdrop module follows a **single-responsibility design**.

Its only purpose is to:

- Validate eligibility
- Transfer tokens
- Emit events

It does **not**:

- Hold governance power
- Modify protocol rules
- Interact with liquidity or pricing

---

## 🔐 Security Model

- No mint function
- No arbitrary transfer function
- Optional Merkle-proof based eligibility
- One-claim-per-wallet enforced on-chain
- Reentrancy protection applied

All state updates happen **before** token transfers.

---

## 🧭 Architecture (Registry-First)

- The MIMHO token address is resolved via the Registry
- No hardcoded token addresses are allowed
- This prevents misrouting and fake-token risks

The Airdrop is an isolated module, fully observable via Events Hub.

---

## 🏛️ Governance Model

- Before DAO activation: controlled by the Founder
- After DAO activation: parameters controlled by the DAO
- Claims remain permissionless for users

No hidden admin claims.  
No silent rule changes.

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

## 📌 Disclaimer

MIMHO documents describe technical intentions and on-chain behavior.

Timelines and parameters may evolve based on security reviews and governance decisions.
