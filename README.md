# 🧠 MIMHO — Official Core Repository

> **MIMHO – the Meme Coin of the Future**  
> *This repository is the official technical + institutional reference for the MIMHO Ecosystem.*  
> *Este repositório é a referência técnica + institucional oficial do Ecossistema MIMHO.*

---

## ✅ What This Repo Is (EN)

- **Official reference** for MIMHO on-chain architecture and module behavior  
- **Specs-first** documentation for each contract (human-readable)  
- **Transparency-first**: everything is verifiable and auditable  
- **Governance-ready**: designed for safe DAO transition  
- **No financial promises**: only technical and operational behavior

---

## ✅ O Que Este Repositório É (PT-BR)

- **Referência oficial** da arquitetura on-chain e comportamento dos módulos MIMHO  
- **Documentação por Specs** (legível por humanos) para cada contrato  
- **Transparência por padrão**: tudo verificável e auditável  
- **Pronto para governança**: preparado para transição segura para DAO  
- **Sem promessas financeiras**: apenas comportamento técnico e operacional

---

## 🔗 Official Links / Links Oficiais

- **Website:** https://mimho.io  
- **GitHub Organization:** https://github.com/MIMHO-Ecosystem  

---

## 📄 Official Documents (Immutable / IPFS)

*All documents below are published as immutable files on IPFS (via Pinata) to guarantee integrity and public verifiability.*  
*Todos os documentos abaixo são publicados como arquivos imutáveis no IPFS (via Pinata) para garantir integridade e verificabilidade pública.*

- **Whitepaper (PDF / IPFS):**  
  https://emerald-high-grasshopper-50.mypinata.cloud/ipfs/bafkreie2kmjlu755hfwbiwlif53e4bybput3mlh47wgijznhuydcn3uqza  

- **Roadmap (PDF / IPFS):**  
  https://emerald-high-grasshopper-50.mypinata.cloud/ipfs/bafkreic64nzssnz3lefygdiq7ss6uiossgvtwkbke4y7jd3nymajfjjil4  

- **Manifesto (PDF / IPFS):**  
  https://emerald-high-grasshopper-50.mypinata.cloud/ipfs/bafkreibxorcfdjntylynzfd62yj7vj5dbyvjpytr6suishxncoo3rrsibi

- **Trust & Token Rules:**  
  [Trust_and_Token_Rules.md](Trust_and_Token_Rules.md)

---

## 🚀 Start Here (Recommended Reading Order)

### 👤 For Everyone (EN/PT)

1. **Manifesto:** [docs/MANIFESTO.md](docs/MANIFESTO.md)  
2. **Distribution & Flow:** [docs/DISTRIBUTION_AND_FLOW.md](docs/DISTRIBUTION_AND_FLOW.md)  
3. **Registry Map:** [docs/REGISTRY_MAP.md](docs/REGISTRY_MAP.md)  
4. **Technical Ecosystem:** [docs/TECHNICAL_ECOSYSTEM.md](docs/TECHNICAL_ECOSYSTEM.md)  
5. **Security Model:** [docs/seguranca/SECURITY_MODEL.md](docs/seguranca/SECURITY_MODEL.md)

---

### 👨‍💻 For Developers

1. **Specs:** [contracts/specs/](contracts/specs/)  
2. **Solidity Source:** [contracts/solidity/](contracts/solidity/)  
3. **Registry Keys & Addressing Rules:** [docs/REGISTRY_MAP.md](docs/REGISTRY_MAP.md)  
4. **Event Standard (Events Hub):** [contracts/specs/02_EventsHub.md](contracts/specs/02_EventsHub.md)

---

## 🧩 Core Modules — Technical Specifications

Human-readable specifications for every official MIMHO smart contract.  
Especificações legíveis por humanos para todos os contratos oficiais do ecossistema MIMHO.

---

## 🧠 Core Infrastructure

- **Registry**  
  [01_Registry.md](contracts/specs/01_Registry.md)

- **Events Hub**  
  [02_EventsHub.md](contracts/specs/02_EventsHub.md)

---

## 💸 Token & Economics

- **MIMHO Token (BEP-20)**  
  [03_Token.md](contracts/specs/03_Token.md)

- **Pre-Sale Contract**  
  [04_Presale.md](contracts/specs/04_Presale.md)

- **Vesting Contract**  
  [05_Vesting.md](contracts/specs/05_Vesting.md)

- **Liquidity Bootstrapper**  
  [06_LiquidityBootstrapper.md](contracts/specs/06_LiquidityBootstrapper.md)

- **Inject Liquidity**  
  [07_InjectLiquidity.md](contracts/specs/07_InjectLiquidity.md)

- **Staking**  
  [08_Staking.md](contracts/specs/08_Staking.md)

- **Holder Distribution**  
  [09_HolderDistribution.md](contracts/specs/09_HolderDistribution.md)

- **Burn Module**  
  [10_Burn.md](contracts/specs/10_Burn.md)

---

## 🏛️ Governance & Control

- **DAO Core**  
  [11_DAO.md](contracts/specs/11_DAO.md)

- **Voting Controller**  
  [12_VotingController.md](contracts/specs/12_VotingController.md)

- **Trading Activity Tracker**  
  [13_TradingActivity.md](contracts/specs/13_TradingActivity.md)

---

## 🎮 Utility & Engagement

- **Airdrop**  
  [14_Airdrop.md](contracts/specs/14_Airdrop.md)

- **Quiz Academy**  
  [18_QuizAcademy.md](contracts/specs/18_QuizAcademy.md)

---

## 🛒 Ecosystem Services

- **Locker**  
  [15_Locker.md](contracts/specs/15_Locker.md)

- **Marketplace**  
  [16_Marketplace.md](contracts/specs/16_Marketplace.md)

- **MIMHO Mart**  
  [17_MIMHOMart.md](contracts/specs/17_MIMHOMart.md)

- **Strategy Hub**  
  [19_StrategyHub.md](contracts/specs/19_StrategyHub.md)

---

## 🧩 Repository Structure

- [`contracts/solidity/`](contracts/solidity/) — Solidity smart contracts  
  Source code published **only after official deployment and on-chain verification**.

- [`contracts/solidity/README.md`](contracts/solidity/README.md) — Solidity publication policy  
  Explains why contracts are published post-deploy to prevent spoofing and fake clones.

- [`contracts/specs/`](contracts/specs/) — Human-readable contract specifications  
  Canonical technical and institutional description of each MIMHO module.

- [`docs/`](docs/) — Ecosystem documentation  
  Architecture, governance model, security assumptions, and design rationale.

- [`addresses/`](addresses/) — Official on-chain addresses  
  Chain mappings, registry references, and verified deployments.

---

## 🧪 Testing & Tooling

- **MIMHO Labs (Foundry Tests & Audits):**  
  https://github.com/MIMHO-Ecosystem/mimho-labs

---

## 🧾 Governance & Transparency Standard

### Registry-First

- All modules resolve dependencies via the Registry  
- No module should hardcode critical addresses

### Events Hub (HUD-Ready)

- All modules emit standardized events to the Events Hub  
- Event emission is **best-effort** (must not revert core logic)

### DAO Transition Model

- Founder controls before DAO activation  
- DAO controls after activation  
- No silent changes  
- No hidden authority

---

## ⚠️ Disclaimer

- *MIMHO documentation is provided for transparency and education.*  
- *Nothing in this repository is financial advice.*  
- *Modules and timelines may evolve based on security reviews and governance decisions.*

---

## 🧾 License

- **MIT License** (see [LICENSE](LICENSE))
