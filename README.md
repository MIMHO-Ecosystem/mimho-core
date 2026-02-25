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

---

## 🚀 Start Here (Recommended Reading Order)

### 👤 For Everyone (EN/PT)
1. **Manifesto:** `docs/MANIFESTO.md`  
2. **Distribution & Flow:** `docs/DISTRIBUTION_AND_FLOW.md`  
3. **Registry Map:** `docs/REGISTRY_MAP.md`  
4. **Technical Ecosystem:** `docs/TECHNICAL_ECOSYSTEM.md`  
5. **Security Model:** `docs/seguranca/SECURITY_MODEL.md`

### 👨‍💻 For Developers
1. **Specs:** `contracts/specs/`  
2. **Solidity Source:** `contracts/solidity/`  
3. **Registry Keys & Addressing Rules:** `docs/REGISTRY_MAP.md`  
4. **Event Standard (Events Hub):** `contracts/specs/MIMHOEventsHub.md`

---

## 🧩 Repository Structure

- `contracts/solidity/` — Smart contracts (`.sol`)  
- `contracts/specs/` — Human-readable specs (`.md`)  
- `docs/` — Architecture, governance, security, and ecosystem docs  
- `addresses/` — Chain addresses and official mappings  

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
- No silent changes, no hidden authority

---

## ⚠️ Disclaimer

- *MIMHO documentation is provided for transparency and education.*  
- *Nothing in this repository is financial advice.*  
- *Modules and timelines may evolve based on security reviews and governance decisions.*

---

## 🧾 License

- **MIT License** (see `LICENSE`)
