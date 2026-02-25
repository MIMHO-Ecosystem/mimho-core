# 🧠 MIMHO Registry — Ecosystem Source of Truth

## 📘 For Non-Technical Readers (Plain Explanation)

The **MIMHO Registry** is the central map of the entire MIMHO ecosystem.

Instead of contracts hardcoding addresses (which is risky and confusing),
every important module asks the Registry a simple question:

> “What is the official address of this contract right now?”

This guarantees:
- No fake contracts
- No outdated addresses
- No frontend confusion
- One single source of truth on-chain

The Registry **does not move funds**, **does not execute business logic** and **does not make decisions**.

Its only job is to **say who is who** in the ecosystem.

---

## 🔁 How It Works (High-Level Flow)

1. Each core contract is registered under an official key
2. Other contracts resolve addresses dynamically via the Registry
3. Frontends also read from the Registry
4. If a module is upgraded, only the Registry changes — nothing breaks

---

## 👨‍💻 For Developers (Technical Summary)

- Single on-chain address registry
- Registry-first architecture (no hardcoded dependencies)
- Keys resolved via `IMIMHORegistry.getContract(KEY)`
- Governance-controlled updates (Founder → DAO)
- No fund custody
- No delegatecall
- No upgrade proxy

> ⚠️ Contract addresses will be published only after official deployment and verification on BNB Chain.


📘 DOCUMENTAÇÃO TÉCNICA — MIMHO REGISTRY

🧭 1. VISÃO GERAL

O MIMHO Registry é o contrato base do ecossistema MIMHO, responsável por manter o registro oficial, on-chain e auditável de todos os contratos do projeto e dos serviços oferecidos pela MIMHO Labs.
Ele funciona como um cartório descentralizado do ecossistema, garantindo que qualquer contrato, auditor ou usuário consiga identificar com clareza quais endereços fazem parte da infraestrutura oficial.

🎯 2. OBJETIVOS DO CONTRATO

Centralizar os endereços oficiais do ecossistema
Eliminar dependência de endereços hardcoded
Facilitar auditorias e inspeções on-chain
Permitir crescimento modular e seguro
Servir como base de integração para contratos internos e parceiros externos

🧱 3. PAPEL NO ECOSSISTEMA

O MIMHO Registry:
Não movimenta tokens
Não executa lógica financeira
Não interfere na lógica interna de outros contratos
Não depende de nenhum outro contrato
Ele existe exclusivamente para registro, consulta e transparência.

🔐 4. AUTORIDADES RECONHECIDAS

O contrato reconhece duas entidades institucionais:
🧑‍🚀 Founder Safe
🏛️ DAO Safe
Ambos os endereços são definidos no deploy inicial.

🧩 5. MODELO DE GOVERNANÇA

🕐 Antes da DAO estar ativa
O Founder Safe pode:
Registrar novos contratos
Atualizar endereços de contratos existentes
A DAO ainda não exerce controle administrativo

🗳️ Após a DAO estar ativa

Somente a DAO Safe pode:
Registrar novos contratos
Atualizar contratos existentes
O Founder perde todas as permissões administrativas
Essa transição é irreversível e totalmente on-chain.

🚫 6. AÇÕES PROIBIDAS (EM QUALQUER FASE)

Remover contratos do registry
Apagar ou sobrescrever histórico
Renunciar o controle do contrato
Alterar registros sem emissão de eventos
O Registry é projetado para não permitir ocultação de rastros.

🧠 7. FILOSOFIA DE DESIGN

O MIMHO Registry segue princípios rígidos de engenharia:
❌ Sem auto-discovery
❌ Sem loops
❌ Sem arrays dinâmicos
❌ Sem lógica condicional complexa
❌ Sem risco de esgotamento de gás
Todos os contratos são registrados por SET DIRETO, garantindo previsibilidade e evitando falhas observadas em cadastros genéricos.

🗂️ 8. MODELO DE REGISTRO

Cada contrato é registrado por meio de:
Uma chave fixa (string curta e padronizada)
Um endereço único
Um evento público emitido no momento do registro ou atualização
Exemplos de chaves utilizadas:
TOKEN
DAO
REGISTRY
EVENTS_HUB
VERITAS
STAKING
As consultas são feitas em tempo constante (O(1)).

🧬 9. CONTRATOS DO ECOSSISTEMA SUPORTADOS

O Registry foi projetado para suportar todos os contratos planejados do ecossistema MIMHO, incluindo:

⚙️ Núcleo

MIMHO Token
MIMHO DAO
MIMHO Registry
MIMHO Events Hub
MIMHO Veritas

💰 Financeiro e Utilitário

MIMHO Staking
MIMHO Vault
MIMHO Locker
MIMHO Inject Liquidity
MIMHO Trading Activity
MIMHO Loans
MIMHO Bet

🎮 Gamificação

MIMHO Quiz
MIMHO Raffle
MIMHO Auctioner
MIMHO GaSaver

🖼️ NFTs e Marketplace

MIMHO MART (montador oficial de NFTs do ecossistema)

🧾 Identidade, Auditoria e Monitoramento

MIMHO Score
MIMHO Persona
MIMHO Certify
MIMHO Observer

O sistema é extensível e preparado para novos módulos futuros.

⏳ 10. REGISTRO COM PRAZO (SERVIÇOS E PARCEIROS)

O Registry suporta contratos com prazo de validade definido no momento do cadastro.
Funcionamento:
O contrato é registrado com:
Endereço
Timestamp de expiração
O próprio Registry valida se o acesso está ativo
Após o vencimento, o contrato é automaticamente considerado inativo
Nenhum registro é apagado
Esse modelo permite:
Planos mensais
Contratos de 30, 60, 90 dias
Renovação transparente e auditável

👁️ 11. FUNÇÕES DE VISUALIZAÇÃO

O contrato expõe funções públicas para consulta de:
Endereços registrados
Status de contratos
Datas de expiração
Autoridade que realizou a última alteração
Essas funções são pensadas para dashboards, bots e auditorias públicas.

📢 12. EVENTOS E TRANSPARÊNCIA

Toda ação relevante emite eventos públicos, incluindo:
Registro de contrato
Atualização de endereço
Ativação da DAO
Renovação de acesso
Esses eventos permitem:
Auditoria social
Indexação por explorers
Monitoramento em tempo real

🛡️ 13. SEGURANÇA

O MIMHO Registry foi projetado para:
Minimizar superfície de ataque
Evitar dependências externas
Impedir ações administrativas silenciosas
Garantir rastreabilidade total
Nenhuma função crítica é executada sem registro público.

🧾 14. POSICIONAMENTO INSTITUCIONAL

O MIMHO Registry estabelece um novo padrão de organização on-chain:
Facilita auditorias
Aumenta confiança de parceiros
Simplifica integração entre contratos
Reforça a visão modular do ecossistema

✅ CONCLUSÃO

O MIMHO Registry é:
O cartório oficial do ecossistema MIMHO
A base da modularidade e transparência
Um contrato simples, sólido e duradouro
Preparado para crescimento, parcerias e auditorias
Ele garante que o ecossistema MIMHO seja compreensível, verificável e confiável, tanto hoje quanto no futuro.
