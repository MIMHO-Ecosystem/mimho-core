# 📚 MIMHO Contracts — Specifications Index

> **MIMHO – the Meme Coin of the Future**  
> This repository section documents the technical and operational behavior of the MIMHO ecosystem.  
> Este repositório documenta o comportamento técnico e operacional do ecossistema MIMHO.  
>  
> **Not financial promises. Not investment advice. Only on-chain logic and rules.**

---

## 👥 For Non-Technical Readers (Plain Explanation)

This folder contains **plain-language explanations** and **technical summaries** of every core contract in the MIMHO ecosystem.

Each document explains:
- What the contract does
- What it is allowed to do
- What it is **not** allowed to do
- How it fits into the ecosystem flow

You do **not** need to read Solidity code to understand these files.

If something is not described here, **it is not part of the protocol behavior**.

---

## 🧠 Para Leigos (Explicação Simples)

Esta pasta contém explicações claras e verificáveis sobre **cada contrato do ecossistema MIMHO**.

Aqui você encontra:
- Para que serve cada contrato
- Quais regras ele segue
- O que ele **não pode fazer**
- Como ele se conecta aos outros módulos

Tudo é baseado em **regras on-chain**, não em promessas.

---

## 👨‍💻 For Developers (Technical Overview)

All specifications follow these principles:

- Registry-first architecture
- No hardcoded dependencies
- No hidden permissions
- No silent fund custody
- No upgrade proxies
- No delegatecall
- Events emitted via Events Hub (best-effort)

Each spec complements the Solidity implementation and exists to make audits, reviews, and integrations easier.

---

## 🧭 Reading Order (Canonical)

The documents below are **numbered intentionally** and should be read in order:

1. **Registry** — single source of truth for all contract addresses  
2. **Events Hub** — on-chain observability and transparency layer  
3. **Token** — immutable supply and transfer rules  
4. **Presale** — initial distribution logic  
5. **Vesting** — time-based token releases  
6. **Liquidity Bootstrapper** — one-shot liquidity creation  
7. **Inject Liquidity** — controlled liquidity reinforcement  
8. **Staking** — long-term participation incentives  
9. **Holder Distribution** — ecosystem distribution rules  
10. **Burn** — supply reduction mechanics  
11. **DAO** — decentralized governance  
12. **Voting Controller** — proposal and voting logic  
13. **Trading Activity** — activity tracking and incentives  
14. **Airdrop** — distribution without fund custody  
15. **Locker** — time-locked assets  
16. **Marketplace** — NFT and asset trading  
17. **Mart** — ecosystem minting hub  
18. **Quiz Academy** — educational on-chain incentives  
19. **Strategy Hub** — high-level coordination logic

---

## 🔗 Official Documentation

- Website: https://mimho.io  
- Whitepaper (PDF / IPFS):  
  https://emerald-high-grasshopper-50.mypinata.cloud/ipfs/bafkreie2kmjlu755hfwbiwlif53e4bybput3mlh47wgijznhuydcn3uqza  
- Roadmap (PDF / IPFS):  
  https://emerald-high-grasshopper-50.mypinata.cloud/ipfs/bafkreic64nzssnz3lefygdiq7ss6uiossgvtwkbke4y7jd3nymajfjjil4  
- Manifesto (PDF / IPFS):  
  https://emerald-high-grasshopper-50.mypinata.cloud/ipfs/bafkreibxorcfdjntylynzfd62yj7vj5dbyvjpytr6suishxncoo3rrsibi  

---

## 📌 Disclaimer

These documents describe **intended technical behavior** and **on-chain rules**.

Timelines, integrations, and modules may evolve through:
- Security reviews
- DAO governance decisions
- Formal audits

No off-chain promise overrides on-chain code.
