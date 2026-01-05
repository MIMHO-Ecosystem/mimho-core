📘 DOCUMENTAÇÃO TÉCNICA — MIMHO LOCKER

🔹 Nome do Contrato
MIMHO Locker

🔹 Objetivo
O MIMHO Locker é responsável por travar tokens LP do par MIMHO/BNB na PancakeSwap, garantindo:
Confiança máxima aos investidores
Travamento permanente de LP da pré-venda
Transparência total, auditável on-chain
Integração futura com MIMHO Labs para lock de parceiros

🧱 1. Funções principais

1.1 Locks permanentes
Travamento de LP tokens da pré-venda
Imutável: nunca podem ser resgatados
isPermanent = true
unlockTimestamp = 0
1.2 Locks temporários
Futuro uso para parceiros via MIMHO Labs
unlockTimestamp > now
isPermanent = false
1.3 Registro de contratos autorizados
Só contratos listados podem criar locks (pré-venda, Labs, DAO)
Atualizações públicas via evento

🔗 2. Estrutura de dados

Solidity
struct Lock {
    address owner;
    address lpToken;
    uint256 amount;
    uint256 unlockTimestamp;
    bool isPermanent;
    LockOrigin origin;
}

enum LockOrigin {
    PRESALE,
    DAO,
    LABS,
    PARTNER
}
Cada lock recebe lockId único
origin indica a origem da liquidez travada

🔍 3. Funções públicas (view)

Todas as informações relevantes podem ser consultadas:
Copiar código
Solidity
function getLock(uint256 lockId) external view returns (
    address owner,
    address lpToken,
    uint256 amount,
    uint256 unlockTimestamp,
    bool isPermanent,
    LockOrigin origin
);

function totalLocked(address lpToken) external view returns (uint256);
function isLPForeverLocked(address lpToken) external view returns (bool);

📢 4. Eventos públicos

Todos os eventos relevantes são emitidos e totalmente auditáveis:
Copiar código
Solidity
event LockCreated(
    uint256 indexed lockId,
    address indexed owner,
    address indexed lpToken,
    uint256 amount,
    uint256 unlockTimestamp,
    bool isPermanent,
    LockOrigin origin
);

event PermanentLockCreated(
    uint256 indexed lockId,
    address indexed lpToken,
    uint256 amount,
    LockOrigin origin
);

event TimedLockCreated(
    uint256 indexed lockId,
    address indexed lpToken,
    uint256 amount,
    uint256 unlockTimestamp,
    LockOrigin origin
);

event LPRegistered(address indexed lpToken);

event AuthorizedContractUpdated(
    address indexed contractAddress,
    bool authorized
);

🔐 5. Segurança

❌ Sem withdraw
❌ Sem backdoor
❌ Sem upgrade ou proxy
❌ Sem multisig override
Reentrancy guard aplicado
Validações estritas de LP e origem
Nenhum lock permanente pode ser removido

🧠 6. Design Philosophy MIMHO

Simplicidade: apenas travamento de LP
Segurança máxima: impossível resgatar LP travado da pré-venda
Imutabilidade: locks permanentes não podem ser alterados
Transparência total: todos os dados consultáveis, todos os eventos públicos
Modularidade: apenas travamento; integração futura com Labs
Auditabilidade: fácil de auditar, sem dependência circular
Escalabilidade: compatível com HUD, dashboards e oráculos

📈 7. Integração com o ecossistema

Recebe LP tokens do Token MIMHO ou de contratos autorizados (pré-venda, Labs)
Permite prova de liquidez travada para investidores e exchanges
Eventos alimentam HUD e dashboards públicos
Funciona como base de confiança para futuras integrações MIMHO Labs

✅ 8. Conclusão

O MIMHO Locker garante:

Travamento perpétuo de 90% da pré-venda
Transparência total via eventos e funções de visualização
Segurança máxima, sem possibilidade de resgate
Arquitetura modular pronta para futuras integrações
Confiança máxima para investidores e parceiros
