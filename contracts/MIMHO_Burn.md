> ⚠️ Contract addresses will be published only after official deployment and verification on BNB Chain.


📘 DOCUMENTAÇÃO TÉCNICA — MIMHO BURN

(MIMHO Burn Governance Vault)

🔹 Nome do Contrato

MIMHO Burn Governance Vault

🔹 Função Principal

Contrato responsável por centralizar, governar e executar queimas de tokens MIMHO, de forma transparente, sustentável e orientada à comunidade, sem adicionar complexidade ao token principal.

🧱 1. VISÃO GERAL

O MIMHO Burn é um contrato modular que atua como o motor oficial de queima do ecossistema MIMHO.
Ele foi projetado para:
Centralizar tokens destinados à queima
Evitar queimas impulsivas ou não sustentáveis
Permitir participação da comunidade em decisões críticas
Garantir previsibilidade econômica
Criar histórico on-chain verificável das queimas
O contrato não cria tokens, não altera supply diretamente e não possui dependência circular com o token MIMHO.

🔐 2. PRINCÍPIOS DE DESIGN

Modularidade total
Token principal simples, lógica complexa em contratos auxiliares
Nenhuma dependência de backend
Nenhuma iteração sobre listas de holders
Modelo pull (usuário chama, não recebe automaticamente)
Transparência absoluta via eventos públicos
Falha segura: na dúvida, queima

🔥 3. FONTES DE TOKENS PARA QUEIMA

O contrato pode receber tokens MIMHO provenientes de:
Taxas de venda do token
Buyback (BNB → MIMHO)
Staking (penalidades ou fees)
Vesting (tokens não reclamados)
Jogos, apostas e NFTs
Serviços do MIMHO Labs
Queima voluntária de holders
Todos os depósitos são feitos via função padronizada, com identificação da origem.

📦 4. ACÚMULO E GATILHO DE CICLO

O contrato não queima tokens imediatamente
Tokens são acumulados internamente
Sempre que o saldo acumulado atingir 500.000.000 MIMHO, um novo ciclo de decisão é iniciado automaticamente
Esse modelo evita micro-queimas e cria eventos econômicos claros e rastreáveis.

🗳️ 5. GOVERNANÇA DO BURN (CICLO DE DECISÃO)

🕒 Janela de Votação
Duração: 3 dias
Votação totalmente on-chain
👥 Quem pode votar
Apenas wallets que:
Mantêm MIMHO há 30 dias ou mais
Não pertencem ao projeto (Founder, DAO, Treasury, contratos, multisigs)
Estão registradas como wallets externas válidas no MIMHO Registry
🗳️ Opções de Voto
🔥 Queimar os tokens
🎁 Distribuir os tokens entre holders elegíveis
⚖️ Regras de Resultado
Se Burn vencer → tokens são queimados
Se Distribuição vencer → abre-se janela de claim
Se não houver quórum mínimo → burn automático
O burn é sempre o comportamento padrão em caso de dúvida ou inatividade.

🎁 6. DISTRIBUIÇÃO PARA HOLDERS (SE APROVADA)

📅 Janela de Claim
Duração: 7 dias
Nenhuma distribuição automática
Cada holder elegível deve chamar manualmente a função de claim
📐 Modelo de Distribuição
Baseado em snapshot on-chain
Distribuição proporcional ao saldo no snapshot
Mecanismo antibaleia aplicado:
Soft cap por wallet ou
Curva de peso não linear (ex: raiz quadrada)
Nenhuma carteira do projeto pode receber tokens
⏳ Tokens Não Reclamados
Após 7 dias, tokens não reclamados:
São queimados automaticamente
Evento público de encerramento é emitido

🔥 7. QUEIMA VOLUNTÁRIA (BOTÃO DE QUEIMA)

Qualquer holder pode queimar tokens voluntariamente para apoiar o projeto.
Características:
Sem retorno financeiro
Sem privilégios
Sem exceções
Respeita o piso mínimo de supply
Cada queima voluntária:
É registrada on-chain
Gera um NFT de certificação de queima

🏅 8. NFT DE QUEIMA (CERTIFICAÇÃO)

Emissão
Mintador oficial: MIMHO MART
Registro da ação: MIMHO Certify
NFT soulbound (não transferível)
Metadados do NFT
Quantidade queimada
Data e timestamp
Hash da transação
Supply antes e depois
Tipo de queima (voluntária, governada, evento)
Identificador do ciclo
Versão do contrato
Esse NFT funciona como prova histórica on-chain, não como recompensa financeira.

🔻 9. PISO MÍNIMO DE SUPPLY

Piso mínimo: 500.000.000.000 MIMHO
Quando o piso é atingido:
Queimas são automaticamente desativadas
Tokens passam a ser redirecionados (ex: staking ou treasury)
O piso é hardcoded e imutável

📢 10. EVENTOS E TRANSPARÊNCIA

O contrato emite eventos públicos para:
Depósito de tokens para queima
Abertura de ciclos
Resultado de votação
Claims individuais
Queimas executadas
Tokens queimados por expiração
Encerramento de ciclos com extrato final
Esses eventos permitem:
Dashboards públicos
Auditoria social
Bots de transparência
Análise histórica completa

👁️ 11. FUNÇÕES DE VISUALIZAÇÃO (VIEW)

O contrato expõe funções públicas de leitura para:
Status atual
Configurações
Ciclo ativo
Histórico de ciclos
Quantidade claimável por wallet
Estatísticas globais de burn
Nenhuma informação crítica fica oculta.

🛡️ 12. SEGURANÇA

Sem mint
Sem alteração de supply
Sem loops sobre holders
Sem privilégios ocultos
Proteção contra reentrância
Pausa emergencial
Controle via DAO ou owner limitado
Integrado ao MIMHO Registry

🧠 13. POSICIONAMENTO ESTRATÉGICO

O MIMHO Burn:
Não queima por hype
Não promete valorização
Não cria inflação
Não favorece insiders
Constrói narrativa de longo prazo
Cada queima é:
🔥 Econômica
📜 Histórica
🧠 Governada
👥 Comunitária

✅ CONCLUSÃO

O MIMHO Burn Governance Vault é:
Tecnicamente sólido
Sustentável
Modular
Auditável
Transparente
Preparado para décadas de operação
Ele transforma a queima de tokens em um processo consciente, verificável e governado, elevando o padrão do ecossistema MIMHO acima do mercado tradicional de memecoins.
