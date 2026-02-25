# 📣 MIMHO Events Hub — Spec (MIMHO Ecosystem)

> MIMHO – the Meme Coin of the Future  
> Este documento descreve regras técnicas e operacionais (não promessas financeiras).  
> This document describes technical and operational rules (not financial promises).

---

## ✅ Quick Summary (EN) — for everyone
• The Events Hub is the public loudspeaker of the MIMHO ecosystem (HUD-ready).  
• It records standardized on-chain events emitted by official modules (best-effort).  
• It does NOT hold user funds and it does NOT change protocol state — it only logs.

## ✅ Resumo Rápido (PT-BR) — para leigos
• O Events Hub é o alto-falante público do ecossistema MIMHO (pronto para HUD).  
• Ele registra eventos padronizados emitidos pelos módulos oficiais (best-effort).  
• Ele NÃO guarda fundos e NÃO altera regras do protocolo — ele apenas registra.

---

## 🧠 Developer Summary (EN)

### Purpose
• Single responsibility: provide a unified, standardized event stream for dashboards, auditing, and transparency.

### Canonical Interface (used by all modules)
All ecosystem contracts MUST emit via this interface:
```solidity
interface IMIMHOEventsHub {
  function emitEvent(
    bytes32 module,
    bytes32 action,
    address caller,
    uint256 value,
    bytes calldata data
  ) external;
}
Security Model (Best-effort)
• All MIMHO modules MUST call the hub using try/catch so hub failures never revert user/admin actions.
• The Hub is observability infrastructure — never a dependency that can block execution.
Standard Event Fields
• module: the calling module identifier (e.g., contractType()).
• action: action identifier (BUY, SELL, STAKE, CLAIM, VOTE, BURN, etc).
• caller: original caller (msg.sender at the module).
• value: primary numeric value (amount, bnb, tokens, etc).
• data: ABI-encoded contextual payload (optional).
Governance / Permissions
• The Hub may restrict who can emit (only ecosystem contracts / registry-approved), depending on implementation.
• Governance follows the MIMHO standard: Founder controls before DAO activation; DAO controls after activation.
Integrations (Registry-first)
• All modules resolve the Hub address via Registry:
hubAddr = registry.getContract(registry.KEY_MIMHO_EVENTS_HUB()) • Emission helper (pattern):
_emitHubEvent(action, caller, value, data)
internally calls eventsHub.emitEvent(contractType(), action, caller, value, data) inside try/catch.
🧠 Resumo para Devs (PT-BR)
Propósito
• Responsabilidade única: fornecer um stream padronizado de eventos para HUD, auditoria e transparência.
Interface Canônica (usada por todos os módulos)
Todos os contratos do ecossistema DEVEM emitir via:
Solidity
Copiar código
interface IMIMHOEventsHub {
  function emitEvent(
    bytes32 module,
    bytes32 action,
    address caller,
    uint256 value,
    bytes calldata data
  ) external;
}
Segurança (Best-effort obrigatório)
• Todos os módulos DEVEM chamar o Hub via try/catch para que falhas do Hub NUNCA revertam transações.
• O Hub é “observabilidade”, não pode virar gargalo do protocolo.
Campos padrão do evento
• module: identificador do módulo emissor (ex.: contractType()).
• action: identificador da ação (BUY, SELL, STAKE, CLAIM, VOTE, BURN, etc).
• caller: o chamador original (msg.sender no módulo).
• value: valor numérico principal (quantidade, bnb, tokens, etc).
• data: payload contextual ABI-encoded (opcional).
Governança / Permissões
• O Hub pode restringir emissores (somente contratos do ecossistema / aprovados no Registry), dependendo da implementação.
• Governança segue o padrão MIMHO: fundador antes da DAO; DAO depois de ativada.
Integrações (Registry-first)
• Todos os módulos resolvem o endereço do Hub via Registry:
hubAddr = registry.getContract(registry.KEY_MIMHO_EVENTS_HUB()) • Helper de emissão (padrão):
_emitHubEvent(action, caller, value, data)
chama eventsHub.emitEvent(contractType(), action, caller, value, data) dentro de try/catch.
🔗 Official Links / Links Oficiais
• Website: https://mimho.io⁠�
• Whitepaper (PDF / IPFS): https://emerald-high-grasshopper-50.mypinata.cloud/ipfs/bafkreie2kmjlu755hfwbiwlif53e4bybput3mlh47wgijznhuydcn3uqza⁠�
• Roadmap (PDF / IPFS): https://emerald-high-grasshopper-50.mypinata.cloud/ipfs/bafkreic64nzssnz3lefygdiq7ss6uiossgvtwkbke4y7jd3nymajfjjil4⁠�
• Manifesto (PDF / IPFS): https://emerald-high-grasshopper-50.mypinata.cloud/ipfs/bafkreibxorcfdjntylynzfd62yj7vj5dbyvjpytr6suishxncoo3rrsibi⁠�
📌 Disclaimer
MIMHO documents describe technical intentions and on-chain behavior.
Timelines and modules may evolve based on security reviews and governance decisions.
