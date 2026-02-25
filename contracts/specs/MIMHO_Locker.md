> ⚠️ Contract addresses will be published only after official deployment and verification on BNB Chain.

# 🔒 MIMHO Locker — Trustless Token & LP Locking Module

MIMHO – the Meme Coin of the Future  
This document describes technical and operational behavior — not financial promises.  
Este documento descreve comportamento técnico e operacional — não promessas financeiras.

## 👥 Visão Geral (Para Leigos)

O **MIMHO Locker** é o contrato responsável por **travar tokens ou LP tokens** por um período definido, de forma **totalmente on-chain, automática e verificável**.

Ele pode ser usado de duas formas:
- Internamente pelo ecossistema MIMHO
- Externamente por projetos terceiros (via MIMHO Labs)

Uma vez travado:
- O ativo **não pode ser movimentado**
- O tempo **não pode ser reduzido**
- O desbloqueio só acontece quando as regras forem cumpridas

Sem confiança.  
Sem intervenção humana.  
Apenas código.

## 🚨 O Problema que Resolve

Em muitos projetos:
- Locks são off-chain ou manuais
- Datas podem ser alteradas
- Não há prova real de bloqueio
- Usuários precisam “confiar” no time

No MIMHO Locker:
- O bloqueio é imutável
- O tempo é verificável on-chain
- A liberação é automática
- Nenhuma pessoa pode antecipar o unlock

Lock não é promessa.  
É **estado gravado na blockchain**.

## ⚙️ Como o MIMHO Locker Funciona

Ao criar um lock:
- O usuário ou projeto envia tokens ou LP tokens ao contrato
- Define:
  - Quantidade
  - Tipo do ativo
  - Timestamp de liberação
- O contrato registra o lock publicamente

Durante o período:
- Os tokens ficam **inacessíveis**
- Não existe função de saque
- Não existe função de edição

Após o tempo definido:
- O contrato permite a liberação
- Apenas o beneficiário pode resgatar

## 🧾 Tipos de Lock Suportados

O MIMHO Locker pode travar:
- Tokens BEP-20
- LP Tokens (DEXs compatíveis)
- Ativos internos do ecossistema MIMHO

Cada lock possui:
- ID único
- Timestamp de criação
- Timestamp de liberação
- Dono do lock
- Quantidade travada

Tudo público.  
Tudo auditável.

## 🔁 Uso Interno no Ecossistema MIMHO

Internamente, o Locker pode ser usado para:
- Travar tokens de recompensas
- Travar tokens de marketing
- Travar tokens de liquidez futura
- Garantir cronogramas públicos

Isso reforça:
- Previsibilidade
- Disciplina econômica
- Confiança estrutural

## 🧱 Uso Externo (MIMHO Labs)

Projetos terceiros podem usar o MIMHO Locker como serviço:
- Criar locks públicos
- Demonstrar compromisso com holders
- Pagar taxas em MIMHO ou stablecoins

Todos os locks externos:
- São públicos
- São verificáveis
- Aparecem no HUD / Explorer

O Locker atua como **cartório on-chain**.

## 🧭 Integração com o Ecossistema

O MIMHO Locker:
- Resolve dependências via **MIMHO Registry**
- Emite eventos no **Events Hub**
- Pode ser monitorado pelo **Observer / Audit**
- Não depende de backend

Cada lock gera eventos claros:
- Lock criado
- Lock liberado
- Lock expirado

## 🏛️ Governança e Segurança

- Antes da DAO: controle administrativo do fundador
- Após DAO: controle exclusivamente da DAO
- Nenhuma autoridade pode:
  - Quebrar um lock
  - Reduzir tempo
  - Resgatar ativos de terceiros

Regras são absolutas.

## 🧩 Benefícios do Modelo

Para holders:
- Prova real de comprometimento
- Menos risco de dump
- Confiança no cronograma

Para projetos:
- Ferramenta simples e confiável
- Credibilidade imediata
- Transparência automática

Para o ecossistema:
- Utilidade real
- Receita via Labs
- Reforço da imagem institucional

## 🔗 Links Oficiais

- Website: https://mimho.io
- Whitepaper (PDF / IPFS):  
  https://emerald-high-grasshopper-50.mypinata.cloud/ipfs/bafkreie2kmjlu755hfwbiwlif53e4bybput3mlh47wgijznhuydcn3uqza
- Roadmap (PDF / IPFS):  
  https://emerald-high-grasshopper-50.mypinata.cloud/ipfs/bafkreic64nzssnz3lefygdiq7ss6uiossgvtwkbke4y7jd3nymajfjjil4
- Manifesto (PDF / IPFS):  
  https://emerald-high-grasshopper-50.mypinata.cloud/ipfs/bafkreibxorcfdjntylynzfd62yj7vj5dbyvjpytr6suishxncoo3rrsibi

## 📌 Disclaimer

MIMHO documents describe technical intentions and on-chain behavior.  
Timelines and modules may evolve based on security reviews and governance decisions.
