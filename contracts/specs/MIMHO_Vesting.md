> ⚠️ Contract addresses will be published only after official deployment and verification on BNB Chain.


📘 DOCUMENTAÇÃO TÉCNICA — CONTRATO MIMHO VESTING

🔹 Nome do Contrato

MIMHO Vesting

🔹 Objetivo

Gerenciar todos os vestings do ecossistema MIMHO de forma imutável, transparente e automática, garantindo que nenhum token prometido possa ser liberado fora das regras definidas em código.
No ecossistema MIMHO, promessas não existem — apenas regras on-chain.

🧱 1. VISÃO GERAL

O contrato MIMHO Vesting é responsável por:
Travar tokens por período definido (Cliff + Vesting)
Liberar tokens gradualmente conforme regras fixas
Executar queimas automáticas vinculadas a metas reais
Impedir liberações antecipadas ou manuais
Garantir igualdade de regras para todos os participantes
O contrato:
Não pode mintar tokens
Não pode alterar regras após o deploy
Não possui privilégios ocultos
Não permite saques fora do cronograma

🔐 2. PRINCÍPIOS DE DESIGN

Código é Lei
Transparência total
Modularidade
Fácil auditoria
Igualdade de regras
Sem intervenção humana
Sem exceções

🧩 3. ESTRUTURA MODULAR

Cada tipo de vesting é isolado logicamente, mesmo estando sob o mesmo contrato:
Vesting do Fundador
Vesting da Pré-venda
Vesting de Marketing
Vesting de Tesouraria DAO
Vesting de Reserva Técnica
Vesting para Listagens em CEX
Vesting de Recompensas de Staking (apenas custódia)
Cada módulo:
Possui regras próprias
Não interfere nos demais
Não compartilha saldos internos

📊 4. TIPOS DE VESTING E REGRAS

👑 Vesting do Fundador
Alocação total: 50 bilhões MIMHO
Cliff: 3 meses
Vesting: 24 meses
Liberação: linear mensal após o cliff
Queimas automáticas vinculadas a metas
Garantia mínima: nunca inferior a 100% da alocação líquida definida após queimas aprovadas
Queimas possíveis (exemplo):
Metas de holders
Metas de volume
Metas de crescimento do ecossistema
As queimas:
Ocorrem apenas sobre tokens ainda travados
São definitivas
Param automaticamente se o piso de supply do token for atingido

🟢 Vesting da Pré-venda
Entrega inicial: 20% no momento da compra
Vesting semanal: 5% por semana
Objetivo:
Evitar caçadores de pump
Incentivar holders reais
Tokens são intransferíveis antes da liberação
Nenhum privilégio por valor investido

📣 Vesting de Marketing (Regra Única e Igualitária)
Regra única para todos:
Influenciadores pequenos ou grandes
Parcerias nacionais ou internacionais
Entrega inicial: 20% após entrega do primeiro conteúdo
Vesting semanal: 10% por semana
Nenhuma liberação antecipada
Tokens só podem ser revendidos após liberação on-chain
No MIMHO, marketing também é holder.

🏛️ Vesting Tesouraria DAO
Alocação: 150 bilhões MIMHO
Tokens totalmente travados
Liberação apenas após:
Ativação da DAO
Governança on-chain
Fundador não possui acesso direto

🧰 Vesting Reserva Técnica
Alocação: 50 bilhões MIMHO
Vesting longo
Uso exclusivo para:
Emergências técnicas
Migrações
Auditorias
Totalmente rastreável por eventos públicos

🏦 Vesting para Listagens em CEX
Alocação: 150 bilhões MIMHO
Tokens ficam 100% travados
Liberação condicionada a:
Evento específico (listagem)
Confirmação on-chain
Nenhuma liberação manual

💰 Custódia para Staking
Alocação: 100 bilhões MIMHO
Tokens ficam travados no contrato
Só podem sair como:
Recompensa de staking
Ninguém pode sacar ou mover esses tokens

🔥 5. MECÂNICA DE QUEIMA PROGRAMADA

Queimas são automáticas
Baseadas em eventos externos verificados por contratos auxiliares
Nunca afetam tokens já liberados
Nunca reduzem abaixo do piso mínimo de supply
Totalmente auditáveis por eventos

🔘 6. FUNÇÕES DE VISUALIZAÇÃO (TRANSPARÊNCIA)

O contrato expõe funções públicas para:
Saldo total travado
Total já liberado
Próxima liberação
Quantidade liberável
Percentuais e ciclos
Status de cada vesting
Essas funções permitem:
Dashboards públicos
Bots de alerta
Auditoria social contínua

📢 7. EVENTOS ON-CHAIN

Todos os eventos importantes emitem logs públicos:
Tokens travados
Tokens liberados
Tokens queimados
Início de vesting
Conclusão de vesting
Pausas emergenciais
Ativação da DAO
Nada ocorre de forma silenciosa.

🛡️ 8. SEGURANÇA

Sem mint
Sem blacklist
Sem whitelist
Sem alteração de regras
Sem funções administrativas perigosas
Proteção contra reentrância
Pausa emergencial apenas para proteção sistêmica
Transição segura para DAO (onlyDAOorOwner)

🧠 9. FILOSOFIA CENTRAL

“No MIMHO, tokens não são liberados por confiança,
são liberados por código.”
O contrato de vesting garante que:
O fundador siga as mesmas regras públicas
O marketing tenha compromisso de longo prazo
A pré-venda forme holders reais
A DAO nasça com tesouraria protegida

✅ CONCLUSÃO

O contrato MIMHO Vesting:
Elimina promessas vazias
Elimina risco humano
Elimina dúvidas sobre desbloqueios
Eleva o padrão de confiança do projeto
É um pilar central da transparência e longevidade do ecossistema MIMHO.
