# MIMHO Core Contracts

This directory contains the official smart contract architecture of the MIMHO Ecosystem.

⚠️ **Important Notice**
- Solidity source code will be published **only after official deployment and on-chain verification**.
- This repository acts as a **public registry and architectural reference**, not a pre-deploy code leak.

---

## 📁 Directory Structure

### `specs/`
Technical specifications for each core contract.
- Acts as the **design and audit reference**
- Immutable by intent (changes must be justified and logged)

### `solidity/`
Placeholder directory for verified Solidity contracts.
- Contracts will appear here **after deployment**
- Each contract must match its corresponding spec

---

## 🧠 Design Principles
- Modular architecture
- Registry-based dependency resolution
- Event-driven transparency (Events Hub)
- DAO-first governance model
- Cross-chain ready by design

---

## 🔐 Deployment Policy
- No contract is considered official until:
  1. Deployed on mainnet
  2. Verified on-chain
  3. Address published in `/addresses`
  4. Linked from its spec file

---

## 🧾 Source of Truth
- Wallets & addresses: `/addresses`
- Technical design: `/contracts/specs`
- Live activity: MIMHO Events Hub (on-chain) / mimho.io

---

**MIMHO – a Meme Coin do Futuro**
