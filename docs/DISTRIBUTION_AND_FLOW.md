#📘 MIMHO — Institutional Documentation
Initial Distribution & On-Chain Flow

This document describes the complete initial distribution of the MIMHO token, including contract flows, responsibilities, and on-chain guarantees, with all allocations executed before the presale.
All tokens are minted only once and allocated immediately after deployment, with real on-chain transfers, public events, and verifiable transaction hashes.

##🔹 Total Supply
Item
Amount (MIMHO)
Founder
50,000,000,000
Presale
100,000,000,000
Initial Liquidity (LP)
300,000,000,000
CEX Tier 1 Reserve
150,000,000,000
DAO Treasury
200,000,000,000
Ecosystem / Future Incentives
200,000,000,000
Total Supply
1,000,000,000,000

#🔐 Core Principles
The entire supply is minted only once
No critical tokens remain under direct founder custody
All transfers occur before the presale
All contracts emit public events
The entire architecture is DAO-ready
Nothing relies on future promises

##1️⃣ Founder — 50,000,000,000 MIMHO
Destination: MIMHO Vesting Contract
Rules:
3-month cliff
Monthly release of 5B MIMHO
Tokens are non-transferable before vesting
No manual withdrawal function
Events emitted:
VestingCreated
TokensReleased

**Transaction Hash** 

##2️⃣ Presale — 100,000,000,000 MIMHO
Destination: MIMHO Presale Contract
Flow:
Tokens sold to buyers
20% released immediately
80% sent to buyer vesting
Unsold tokens are permanently burned
Guarantees:
Tokens never return to the founder
Irreversible on-chain burn
Events emitted:
TokensPurchased
PresaleFinalized
TokensBurned

**Transaction Hash**

##3️⃣ Initial Liquidity (LP) — 300,000,000,000 MIMHO
Destination: MIMHO Liquidity Bootstrapper
Exclusive contract responsibilities:
Receive BNB raised during the presale
Use 90% of BNB for liquidity
Calculate launch price (presale price + 10%)
Automatically create the MIMHO/BNB pool
Burn all generated LP tokens
Send excess tokens to the Locker
Guarantees:
No token selling
No BNB withdrawals
Single execution (one-shot)
Events emitted:
LiquidityBootstrapped
LPBurned
LiquidityExcessLocked

**Transaction Hash**

##4️⃣ Future Listings Reserve (CEX Tier 1) — 150,000,000,000 MIMHO
Destination: MIMHO Locker Contract
Release rules:
Exclusively for centralized exchange listings
Released via:
DAO governance (when active), or
Quadratic community voting (DAO not yet active)
Guarantees:
Tokens cannot be moved manually
Restricted and auditable usage
Events emitted:
TokensLocked
LockerReleaseApproved

**Transaction Hash**

##5️⃣ DAO Treasury — 200,000,000,000 MIMHO
Destination: MIMHO Locker
Rules:
Tokens remain locked until DAO activation
After activation, only on-chain governance can release them
Founder has no special privileges
Events emitted:
DAOTreasuryLocked
DAOReleaseExecuted

**Transaction Hash**

##6️⃣ Ecosystem / Future Incentives — 200,000,000,000 MIMHO
Destination: Vesting Contract
Release model:
Base monthly release
Conditional bonuses tied to milestones (holders / market cap)
Public and verifiable metrics
Guarantees:
No automatic selling
Predictable releases
Full transparency
Events emitted:
EcosystemRelease
MilestoneReached

**Transaction Hash**

#📢 MIMHO Events Hub
All ecosystem contracts:
Emit standardized events to the MIMHO Events Hub
The Events Hub is highlighted on the website homepage
Acts as the logical ledger of the MIMHO ecosystem
Enables:
Social auditing
Public dashboards
Independent verification
Future cross-chain integrations

#✅ Project Status Before Presale
Before any public announcement:
Contracts deployed
Total supply fully minted
Tokens allocated according to documentation
Real on-chain transfers
Events emitted
Verifiable transaction hashes available

#🏁 Conclusion
MIMHO begins its presale with all critical infrastructure already executed on-chain, allowing any investor to independently verify where each token is and how it can be used.




#📘 MIMHO — Documentação Institucional
Distribuição Inicial & Fluxo On-Chain

Esta documentação descreve a distribuição inicial completa do token MIMHO, incluindo fluxo de contratos, responsabilidades e garantias on-chain, com todas as alocações executadas antes da pré-venda.
Todos os tokens são mintados uma única vez e alocados imediatamente após o deploy, com transferências reais, eventos públicos e hashes verificáveis.

##🔹 Supply Total
Item

Quantidade (MIMHO)
Fundador
50.000.000.000
Pré-venda
100.000.000.000
Liquidez Inicial (LP)
300.000.000.000
Reserva para CEX Tier 1
150.000.000.000
Tesouro da DAO
200.000.000.000
Ecossistema / Incentivos Futuros
200.000.000.000
Total Supply
1.000.000.000.000

##🔐 Princípios Fundamentais
Todo o supply é mintado uma única vez
Nenhum token crítico fica sob custódia direta do fundador
Todas as transferências ocorrem antes da pré-venda
Todos os contratos emitem eventos públicos
Toda a arquitetura é DAO-ready
Nada depende de promessa futura

##1️⃣ Fundador — 50.000.000.000 MIMHO
Destino: MIMHO Vesting Contract 
Regras:
Cliff de 3 meses
Liberação mensal de 5B MIMHO
Tokens não transferíveis antes do vesting
Nenhuma função de retirada manual
Eventos emitidos:
VestingCreated
TokensReleased

**Hash da transação** 

##2️⃣ Pré-venda — 100.000.000.000 MIMHO
Destino: MIMHO Presale Contract
Fluxo:
Tokens vendidos aos compradores
20% liberados imediatamente
80% enviados para vesting do comprador
Tokens não vendidos são queimados permanentemente
Garantias:
Tokens não retornam ao fundador
Queima irreversível on-chain
Eventos emitidos:
TokensPurchased
PresaleFinalized
TokensBurned

**Hash da Transação** 

##3️⃣ Liquidez Inicial (LP) — 300.000.000.000 MIMHO
Destino: MIMHO Liquidity Bootstrapper
Responsabilidade exclusiva do contrato:
Receber BNB arrecadado da pré-venda
Usar 90% do BNB para liquidez
Calcular o preço de lançamento (pré-venda + 10%)
Criar a pool MIMHO/BNB automaticamente
Queimar todos os LP tokens gerados
Enviar tokens excedentes para o Locker
Garantias:
Nenhuma venda de tokens
Nenhuma retirada de BNB
Execução única (one-shot)
Eventos emitidos:
LiquidityBootstrapped
LPBurned
LiquidityExcessLocked

**Hash da Transação**

##4️⃣ Reserva para Listagens Futuras (CEX Tier 1) — 150.000.000.000 MIMHO
Destino: MIMHO  Locker Contract
Regras de liberação:
Apenas para listagens em exchanges centralizadas
Liberação via:
DAO (quando ativa), ou
Votação comunitária quadrática (DAO ainda inativa)
Garantias:
Tokens não podem ser movimentados manualmente
Uso restrito e auditável
Eventos emitidos:
TokensLocked
LockerReleaseApproved

**Hash da Transação**

##5️⃣ Tesouro da DAO — 200.000.000.000 MIMHO
Destino: MIMHO Locker
Regras:
Tokens permanecem bloqueados até ativação da DAO
Após ativação, somente governança on-chain pode liberar
Fundador não possui privilégios especiais
Eventos emitidos:
DAOTreasuryLocked
DAOReleaseExecuted

**Hash da Transação**

##6️⃣ Ecossistema / Incentivos Futuros — 200.000.000.000 MIMHO
Destino: Vesting Contract
Modelo de liberação:
Liberação base mensal
Bônus condicionais por milestones (holders / market cap)
Métricas públicas e verificáveis
Garantias:
Nenhuma venda automática
Liberação previsível
Total transparência
Eventos emitidos:
EcosystemRelease
MilestoneReached

#📢 MIMHO Events Hub
Todos os contratos do ecossistema:
Emitirão eventos padronizados no MIMHO Events Hub
O Events Hub se encontra  na página inicial do site e funciona como o ledger lógico do ecossistema MIMHO
Permite:
Auditoria social
Dashboards públicos
Verificação independente
Integração cross-chain futura

#✅ Estado do Projeto Antes da Pré-venda
Antes de qualquer anúncio público:
Contratos deployados
Supply totalmente mintado
Tokens alocados conforme documentação
Transferências reais on-chain
Eventos emitidos
Hashes verificáveis disponíveis

#🏁 Conclusão
O MIMHO inicia sua pré-venda com toda a estrutura crítica já executada on-chain,
permitindo que qualquer investidor verifique, de forma independente,
onde cada token está e como pode ser utilizado.
