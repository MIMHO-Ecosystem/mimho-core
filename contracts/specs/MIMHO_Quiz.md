> ⚠️ Contract addresses will be published only after official deployment and verification on BNB Chain.


📘 DOCUMENTAÇÃO TÉCNICA

MIMHO Quiz 
Educação Gamificada On-Chain do Ecossistema MIMHO

🧠 Visão Geral
O MIMHO Quiz é um contrato inteligente 100% on-chain criado para educar usuários sobre o ecossistema MIMHO por meio de quizzes gamificados, distribuindo recompensas em tokens MIMHO de forma justa, transparente, auditável e sustentável.
O contrato foi desenhado para:
Evitar qualquer tipo de retirada manual de fundos
Garantir máxima transparência
Prevenir abuso e exploração
Servir como base para produtos futuros da MIMHO Labs

🎯 Objetivos do Contrato
Incentivar aprendizado real sobre a MIMHO
Recompensar usuários ativos e engajados
Criar histórico público de participação educacional
Reforçar confiança no ecossistema
Transformar educação em ativo on-chain

🔁 Ciclos de Funcionamento
O Quiz opera em ciclos de 30 dias
Cada ciclo possui:
Identificador próprio (cycleId)
Pool de recompensas fixo
Contador de participantes
Usuários podem jogar quantas vezes quiserem
Cada carteira só pode receber recompensa 1 vez por ciclo

💰 Recompensas
Pool por ciclo
Valor inicial: 50.000.000 MIMHO por ciclo
Totalmente configurável para ciclos futuros
Alterações não afetam ciclos em andamento
Distribuição
Ao final do ciclo:
O contrato calcula:

recompensaPorUsuário = rewardPerCycle / totalParticipants
Todos os participantes que concluíram o quiz recebem o mesmo valor
O usuário precisa chamar a função claimReward()
📌 O contrato nunca empurra tokens, apenas libera via claim.

💼 Funding do Contrato
Pool inicial:
1.000.000.000 MIMHO do fundador
Pools futuros:
Carteira de Marketing
DAO (quando ativa)
Regras de funding
Apenas depósitos são permitidos
Nenhuma carteira (fundador, marketing, DAO ou contrato) pode retirar fundos
Todo funding emite evento público on-chain

🔐 Segurança e Transparência
❌ Proibido
Withdraw manual
Emergency withdraw humano
Qualquer função que permita retirada arbitrária
✅ Permitido
Apenas distribuição automática via regras do contrato
Fail-safe automático baseado em tempo (ver abaixo)
⏳ Fail-Safe Automático (Proteção Anti-Tokens Presos)
Para evitar tokens presos para sempre:
O contrato monitora o timestamp da última interação válida
Se o contrato ficar 100% inativo por 2 anos (730 dias):
Qualquer pessoa pode chamar triggerFailsafe()
O contrato transfere automaticamente todos os tokens restantes para a DAO
O contrato entra em estado final e imutável
📌 Não existe botão humano
📌 Não existe decisão subjetiva
📌 Apenas tempo + inatividade extrema
Isso não representa risco ao holder e aumenta a confiança.

🌟 DIFERENCIAIS EXCLUSIVOS MIMHO

⭐ 1. Certificação On-Chain (Badge / Prova de Conhecimento)
Ao concluir o quiz:
O usuário recebe uma prova pública on-chain
Pode ser implementado como:
NFT Soulbound (não transferível)
Registro no MIMHO Certify
💡 Significado:
“Esta carteira entende o ecossistema MIMHO.”
Uso futuro:
Governança
Pré-vendas
Acesso a quizzes premium
Status reputacional
⭐ 2. Histórico Público de Aprendizado
O contrato registra métricas educacionais:
Total de quizzes concluídos por carteira
Total de ciclos participados
Esses dados:
São públicos
Não dependem de backend
Criam identidade educacional on-chain
📌 Não é score financeiro
📌 É reputação de conhecimento
⭐ 3. Quiz como Produto da MIMHO Labs
O contrato já nasce preparado para:
Campanhas internas da MIMHO
Campanhas externas de outros projetos
Modelo de monetização via MIMHO Labs
Isso transforma o Quiz em:
Educação + Marketing + Receita On-Chain

🧩 Lógica de Elegibilidade
Para participar e receber recompensa:
Carteira deve ser EOA (não contrato)
Não pode ter recebido recompensa no mesmo ciclo
Deve concluir o quiz dentro do ciclo
Deve chamar claimReward() após o ciclo fechar

📣 Eventos Públicos (Auditáveis)
O contrato emite eventos para:
Início de ciclo
Encerramento de ciclo
Funding
Conclusão de quiz
Claim de recompensa
Atualização de parâmetros
Ativação de fail-safe
Esses eventos:
Alimentam o HUD
Servem para marketing
São prova pública de funcionamento correto

🧑‍💻 Integrações Nativas
O contrato é totalmente integrado ao ecossistema MIMHO:
MIMHO Registry
DAO (onlyDAOorOwner)
HUD
Events Hub
Certify (badge)
Labs (uso externo)
Pause emergencial
Evolução futura sem breaking changes

🛡️ Filosofia de Design (Design Philosophy)
Transparência acima de tudo
Nenhuma confiança em humanos
Regras claras e imutáveis
Educação antes de especulação
Segurança > complexidade
Tudo público, tudo auditável

✅ Status Final
Arquitetura: Aprovada
Segurança: Alta
Transparência: Máxima
Pronto para marketing: Sim
Pronto para DAO: Sim
Pronto para Labs: Sim
