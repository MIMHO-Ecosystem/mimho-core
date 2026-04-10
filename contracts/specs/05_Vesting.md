> 0x0f9D839E9564bc02a79297f24e6792fb8FEeAc6F

# 🧾 MIMHO Vesting — Controlled Token Release Engine

MIMHO – the Meme Coin of the Future  
This document describes technical and operational behavior — not financial promises.  
Este documento descreve comportamento técnico e operacional — não promessas financeiras.

## 👥 Visão Geral (Para Leigos)

O **MIMHO Vesting** é o contrato responsável por **controlar a liberação de tokens ao longo do tempo**.

Ele existe para evitar:
- Dump imediato
- Pressão de venda precoce
- Uso indevido de tokens reservados
- Decisões humanas arbitrárias

Aqui, **ninguém escolhe quando sacar**.  
O código decide.

## 🎯 Objetivo do Módulo

O Vesting foi criado para:

- Proteger o mercado no lançamento
- Alinhar incentivos de longo prazo
- Garantir previsibilidade total
- Eliminar confiança no fundador ou na DAO
- Automatizar liberações de forma imutável

Sem botões mágicos.  
Sem saques manuais.  
Sem exceções.

## 🧱 Quem Usa o Vesting

O MIMHO Vesting é utilizado por múltiplas frentes do ecossistema:

- Pré-venda (80% dos tokens)
- Fundador
- DAO Treasury
- Operações do ecossistema
- Tokens reservados para CEX
- Outros módulos estratégicos

Cada categoria possui **regras próprias**, registradas on-chain.

## ⏳ Regras da Pré-Venda

Para participantes da pré-venda:

- 20% dos tokens são liberados imediatamente (TGE)
- 80% são enviados ao Vesting
- Liberação semanal de 5%
- Claim manual pelo usuário
- Sem permissões especiais
- Sem possibilidade de antecipação

Token não vendido na pré-venda:
- É queimado permanentemente
- Nunca entra em vesting
- Nunca reaparece

## 🔒 Regras do Fundador

Os tokens do fundador:

- Não ficam em carteira
- São enviados diretamente ao Vesting
- Possuem cliff inicial de 3 meses
- Após o cliff:
  - Liberação mensal fixa
  - Até completar o total reservado

Isso elimina pressão inicial e alinha o fundador ao longo prazo.

## 🏛️ Regras da DAO

Tokens da DAO:

- Permanecem em vesting
- Liberação gradual e previsível
- Quantidade pensada para absorção saudável pelo mercado
- Nenhuma liberação manual
- Nenhum saque emergencial

A DAO **não controla o tempo**.  
Ela apenas recebe conforme o código define.

## 🏦 Tokens para CEX

Tokens reservados para exchanges centralizadas:

- Ficam bloqueados no Vesting
- Não circulam antes da listagem
- Só são liberados:
  - Diretamente para a carteira da exchange
  - No momento da listagem
- Transparência total sobre supply circulante

## 🔁 Funcionamento Técnico

O Vesting:

- Armazena posições individuais por beneficiário
- Controla:
  - Total alocado
  - Total já liberado
  - Próxima data de claim
- Não envia tokens automaticamente
- O beneficiário chama `claim()`
- Tudo é verificável on-chain

## 🔐 Segurança e Imutabilidade

O módulo:

- Não permite alteração de regras após criação
- Não possui funções administrativas ocultas
- Não aceita “ajustes emergenciais”
- Não permite saques fora do cronograma
- Não depende de backend

Uma vez criado, **o vesting é soberano**.

## 🔁 Integração com o Ecossistema

O Vesting:

- Resolve dependências via **MIMHO Registry**
- Emite eventos no **Events Hub**
- Fornece dados para:
  - HUD
  - Auditoria pública
  - Análise de supply
  - Governança informada

## 🧠 Filosofia do Vesting

Este módulo existe porque:

- Tempo importa
- Disciplina importa
- Confiança deve ser substituída por código
- Crescimento sustentável exige controle de oferta

Aqui, **o futuro não é prometido**.  
Ele é programado.

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
