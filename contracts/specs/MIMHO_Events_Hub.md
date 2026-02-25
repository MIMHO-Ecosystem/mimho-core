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
