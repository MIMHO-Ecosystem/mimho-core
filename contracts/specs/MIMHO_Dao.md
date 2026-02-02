> ⚠️ Contract addresses will be published only after official deployment and verification on BNB Chain.

📘 DOCUMENTAÇÃO TÉCNICA OFICIAL

MIMHO DAO
Camada de Governança On-Chain do Ecossistema MIMHO

🧠 Visão Geral

A MIMHO DAO é a entidade de governança do ecossistema, responsável por:
Eleição de cargos estratégicos
Administração simbólica e organizacional do ecossistema
Proposição de melhorias e supervisão das atividades do ecossistema
Garantia de transparência e auditabilidade máxima
Tudo é on-chain, modular, e integrado ao HUD, permitindo que qualquer ação seja auditável publicamente, sem comprometer a segurança do ecossistema.

🏛️ Estrutura de Cargos

Salário (% da arrecadação mensal)
Cargo
Responsabilidades
Presidente
Coordenação geral, organização das eleições, representação da DAO, proposição de melhorias
1,0%
Vice-Presidente
Apoio à Presidência, supervisão de projetos, representação quando necessário
0,7%
Tesoureiro
Controle de finanças operacionais, auditoria de movimentações, supervisão da arrecadação
0,6%
Moderador de Comunidade A
Mediação da comunidade, curadoria de debates, escuta ativa dos holders, organização de tópicos de discussão
0,5%
Moderador de Comunidade B
Igual ao Moderador A
0,5%
Total: 3,3% da arrecadação mensal
Salários pagos mensalmente em MIMHO, via contrato claimSalary(), com evento público no HUD.
Salário baseado somente na arrecadação do mês (fundos anteriores, tesouro, reservas e fundos travados não entram).

🗓️ Mandatos e Eleições

Duração: 1 ano
Calendário:
Setembro: abertura de candidaturas
Outubro: campanha (1 mês)
Novembro: votação on-chain
Dezembro: preparação para transição
Janeiro: início do mandato
Regra de mandatos: nenhum cargo pode ter 2 mandatos consecutivos (salvo falta de candidatos)
Ranking de eleição:
1º mais votado → Presidente
2º → Vice-Presidente
3º → Tesoureiro
4º e 5º → Moderadores
6º → suplente imediato
Impeachment:
Caso de abandono ou inatividade
Todos abaixo sobem na lista, suplente assume
Processo votado pela DAO, totalmente on-chain
Organização da próxima eleição: responsabilidade dos cargos eleitos

⚖️ Elegibilidade de candidatos

Holders há mais de 90 dias
Mínimo de 1.000.000 MIMHO (parametrizável pela DAO)
Candidatura registrada oficialmente on-chain
Snapshot oficial de elegíveis realizado 7 dias antes da eleição
Transparente, público e auditável

🗳️ Regras de votação

Votação: holders há mais de 90 dias, com mínimo de 1.000.000 MIMHO (parametrizável)
Peso do voto: raiz quadrada do número de tokens + bônus de ReputationScore / staking ativo
Limite máximo por carteira: configurável (ex: 5% do total)
Quórum: mínimo definido pela DAO (parametrizável)
Eventos: cada voto e resultado publicado no HUD

🔐 Poderes e Limites dos Cargos

Poder simbólico + organizacional, não executivo
Responsabilidades:
Moderar a comunidade
Organizar eleições
Propor melhorias
Trazer assuntos para debate
Movimentar ecossistema de forma transparente
Proibido:
Transferir fundos
Alterar salários
Modificar regras do ecossistema
Todas ações emitidas no HUD, auditáveis

🧱 Contratos e Modularidade

MIMHO_DAO_Governance: eleição, cargos, mandatos, impeachment, ranking
MIMHO_DAO_Payroll: cálculo de arrecadação, percentuais, claim, eventos HUD
Modular, seguro, fácil de auditar, pronto para upgrades e expansão

🔹 Segurança e Transparência

Auditável: todas ações públicas no HUD
Anti-abuso: regras de elegibilidade, limitação de voto, snapshot oficial, mandato único
Transparente: eventos on-chain de candidatura, votação, eleição, salário, impeachment
Seguro: fundos da DAO isolados, não incluídos nos cálculos de salário, contratos protegidos por reentrancy guard e checks-effects-interactions

🧠 Diferenciais MIMHO DAO

Sistema de eleições auditável e justo, equilibrando pequenos, médios e grandes holders
Pagamentos variáveis baseados em arrecadação mensal, promovendo incentivo à performance do ecossistema
Estrutura modular, permitindo evolução da governança sem risco sistêmico
Eventos HUD garantem transparência total, prontos para marketing e credibilidade
Mandatos rotativos e impeachment garantem renovação e responsabilidade
