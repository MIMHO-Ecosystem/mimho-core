> ⚠️ Contract addresses will be published only after official deployment and verification on BNB Chain.

# 🎁 MIMHO Holder Distribution — On-Chain Reward Engine

MIMHO – the Meme Coin of the Future  
This document describes technical and operational behavior — not financial promises.  
Este documento descreve comportamento técnico e operacional — não promessas financeiras.

## 👥 Visão Geral (Para Leigos)

O **Holder Distribution** é o mecanismo que permite distribuir tokens de forma **justa, auditável e automática** para participantes do ecossistema MIMHO.

Não é:
- Airdrop aleatório
- Promessa de rendimento
- Distribuição manual
- Sistema dependente de confiança

É um **módulo on-chain**, governado por regras claras, que recompensa participação real no ecossistema.

Quem participa, pode ser incluído.  
Quem não participa, fica de fora.  
Sem exceções.

## 🎯 O Problema que Resolve

Em muitos projetos:
- Recompensas são opacas
- Distribuições favorecem poucos
- Critérios mudam sem aviso
- Não há como auditar quem recebeu

No MIMHO:
- Critérios são públicos
- Elegibilidade é objetiva
- Distribuição é rastreável
- Tudo é verificável on-chain

Distribuir valor não é marketing.  
É **engenharia de incentivos**.

## ⚙️ Como Funciona o Holder Distribution

O módulo opera em ciclos independentes.

Cada ciclo possui:
- Um período de análise (ex: últimas 24h, semana, bloco X → Y)
- Um conjunto de regras de elegibilidade
- Um montante definido para distribuição
- Uma execução on-chain verificável

Fluxo geral:
1. Período é analisado
2. Participantes elegíveis são identificados
3. Distribuição é executada
4. Eventos são emitidos no Events Hub

Nada é retroativo.  
Nada é secreto.

## 🧮 Critérios de Elegibilidade

Os critérios podem incluir, por exemplo:
- Ter comprado ou vendido no período
- Ter participado de staking
- Ter interagido com contratos específicos
- Excluir bots, micro-transações ou wash trading
- Excluir compras e vendas no mesmo bloco

Os critérios:
- São definidos previamente
- Podem evoluir via governança
- Nunca são alterados após o snapshot

Participação real > volume artificial.

## 📸 Snapshot-Based Distribution

O sistema utiliza **snapshots**:

- O estado do ecossistema é congelado em um ponto específico
- Endereços elegíveis são definidos
- Valores são calculados
- A execução acontece após o snapshot

Isso garante:
- Justiça
- Previsibilidade
- Impossibilidade de manipulação tardia

Se você não estava no snapshot, não participa do ciclo.

## 🏦 Origem dos Fundos

O Holder Distribution pode receber tokens de:
- Taxas do protocolo
- Reservas designadas
- Aportes externos (ex: fundador)
- Decisões da DAO

Importante:
- O contrato **não cria tokens**
- Ele apenas distribui tokens já existentes
- Nenhuma função de saque arbitrário existe

O módulo distribui.  
Não acumula poder.

## 🏛️ Governança e Controle

Antes da ativação da DAO:
- Parâmetros iniciais podem ser definidos pelo fundador

Após ativação da DAO:
- Apenas a DAO pode:
  - Ajustar regras
  - Definir novos ciclos
  - Autorizar distribuições

A execução, porém, continua sendo **automática e on-chain**.

Governança decide **o que**.  
Código executa **como**.

## 📡 Transparência Total

Toda distribuição:
- Emite eventos no Events Hub
- Pode ser acompanhada no HUD
- Fica registrada permanentemente
- Pode ser auditada por qualquer pessoa

Se não houve evento:
- A distribuição não aconteceu

Sem prints.  
Sem anúncios vazios.

## 🧭 Integração com o Ecossistema

O Holder Distribution:
- Resolve dependências via MIMHO Registry
- Interage apenas com módulos oficiais
- Não depende de backend
- Pode ser acionado por bots, DAO ou regras automáticas

É um módulo neutro, reutilizável e auditável.

## 🧩 Benefícios do Modelo

Para holders:
- Recompensa justa
- Critérios claros
- Confiança no processo

Para o ecossistema:
- Incentivo à participação real
- Redução de especulação vazia
- Alinhamento de longo prazo

Para desenvolvedores:
- Arquitetura modular
- Fácil integração
- Baixo risco operacional

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
