/// -----------------------------------------------------------------------
/// MIMHO LOCKER
/// Official MIMHO Ecosystem Contract
///
/// Network: BNB Smart Chain
/// Contract Address:
/// 0xCF1F253D0EFAc28Cf0C96896846A8C70887f9957
///
/// BscScan:
/// https://bscscan.com/address/0xCF1F253D0EFAc28Cf0C96896846A8C70887f9957
/// -----------------------------------------------------------------------

// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/* ============================================================
   MIMHO LOCKER — v1.0.0 (MIMHO ABSOLUTE STANDARD)
   ============================================================

   DESIGN PHILOSOPHY (MIMHO ABSOLUTE STANDARD)

   - Trust Removal:
     The Locker exists to remove trust from token locking. Tokens are either
     locked or released by code-defined conditions. No manual overrides.

   - Radical Transparency:
     All meaningful actions emit public events and are queryable via view
     functions, enabling HUD, dashboards, bots, and social audit.

   - No Financial Complexity:
     The Locker does not price assets, does not use USD logic, and does not
     depend on external oracles. It is a custody/time/condition contract.

   - Fee-as-Fuel (MIMHO):
     Public locks pay fees strictly in MIMHO (service fuel). The locked token
     is never used as fee.

   - DAO-First Governance:
     Adjustable parameters are DAO-governed with an on-chain timelock window.
     After DAO activation, privileged operations are DAO-only where specified.

   - Never Break Users:
     Events Hub emission is best-effort (try/catch). Failure of the Hub must
     never break user flows or administrative safety actions.

   ============================================================ */

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address a) external view returns (uint256);
    function allowance(address o, address s) external view returns (uint256);
    function approve(address s, uint256 a) external returns (bool);
    function transfer(address to, uint256 a) external returns (bool);
    function transferFrom(address f, address t, uint256 a) external returns (bool);
    function decimals() external view returns (uint8);
}

interface IMIMHOEventsHub {
    function emitEvent(
        bytes32 module,
        bytes32 action,
        address caller,
        uint256 value,
        bytes calldata data
    ) external;
}

/**
 * @notice Registry interface (minimal for MIMHO Absolute Standard).
 * IMPORTANT: keys must be retrieved from Registry getters (no local keccak/strings).
 */
interface IMIMHORegistry {
    function getContract(bytes32 key) external view returns (address);

    function KEY_MIMHO_EVENTS_HUB() external view returns (bytes32);
    function KEY_MIMHO_TOKEN() external view returns (bytes32);
    function KEY_MIMHO_MARKETING_WALLET() external view returns (bytes32);
    function KEY_MIMHO_INJECT_LIQUIDITY() external view returns (bytes32);
}

abstract contract ReentrancyGuard {
    uint256 private _rg;
    modifier nonReentrant() {
        require(_rg == 0, "REENTRANCY");
        _rg = 1;
        _;
        _rg = 0;
    }
}

abstract contract Pausable {
    event Paused(address indexed  by);
    event Unpaused(address indexed  by);

    bool public paused;

    modifier whenNotPaused() {
        require(!paused, "PAUSED");
        _;
    }

    modifier whenPaused() {
        require(paused, "NOT_PAUSED");
        _;
    }

    function _pause() internal whenNotPaused {
        paused = true;
        emit Paused(msg.sender);
    }

    function _unpause() internal whenPaused {
        paused = false;
        emit Unpaused(msg.sender);
    }
}

abstract contract Ownable2StepLite {
    event OwnershipTransferStarted(address indexed  previousOwner, address indexed  newOwner);
    event OwnershipTransferred(address indexed  previousOwner, address indexed  newOwner);

    address public owner;
    address public pendingOwner;

    modifier onlyOwner() {
        require(msg.sender == owner, "ONLY_OWNER");
        _;
    }

    constructor() {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "ZERO");
        pendingOwner = newOwner;
        emit OwnershipTransferStarted(owner, newOwner);
    }

    function acceptOwnership() external {
        require(msg.sender == pendingOwner, "NOT_PENDING");
        address old = owner;
        owner = pendingOwner;
        pendingOwner = address(0);
        emit OwnershipTransferred(old, owner);
    }
}

contract MIMHOLocker is Ownable2StepLite, Pausable, ReentrancyGuard {
    /* ============================================================
                                CONSTANTS
       ============================================================ */

    string public constant icontratoMimho = "MIMHO_LOCKER";
    string public constant version = "1.0.0";

    address public constant FOUNDER_SAFE = 0x3b50433D64193923199aAf209eE8222B9c728Fbd;
    address public constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    uint256 public constant SUPPLY_FLOOR = 500_000_000_000 * 1e18;

    uint16 public constant BPS_DENOM = 10_000;
    uint16 public constant FOUNDER_BPS = 1_000;     // 10%
    uint16 public constant MARKETING_BPS = 1_000;   // 10%
    uint16 public constant BURN_OR_LP_BPS = 3_000;  // 30%
    uint16 public constant DAO_BPS = 5_000;         // 50%

    uint64 public constant FEE_TIMELOCK = 2 days;
    uint64 public constant WEEK = 7 days;

    bytes32 public constant MODULE_LOCKER = keccak256("MIMHO_LOCKER");

    bytes32 public constant ACTION_LOCK_CREATED      = keccak256("LOCK_CREATED");
    bytes32 public constant ACTION_LOCK_EXTENDED     = keccak256("LOCK_EXTENDED");
    bytes32 public constant ACTION_LOCK_RELEASED     = keccak256("LOCK_RELEASED");
    bytes32 public constant ACTION_FEE_COLLECTED     = keccak256("FEE_COLLECTED");
    bytes32 public constant ACTION_FEE_DISTRIBUTED   = keccak256("FEE_DISTRIBUTED");
    bytes32 public constant ACTION_BURN_EXECUTED     = keccak256("BURN_EXECUTED");
    bytes32 public constant ACTION_DAO_LOCK_READY    = keccak256("DAO_LOCK_READY");
    bytes32 public constant ACTION_CEX_RELEASE_APPR  = keccak256("CEX_RELEASE_APPROVED");
    bytes32 public constant ACTION_PAUSED            = keccak256("PAUSED");
    bytes32 public constant ACTION_UNPAUSED          = keccak256("UNPAUSED");

    /* ============================================================
                                DAO CONTROL
       ============================================================ */

    address public daocontract;
    bool public daoActivated;

    modifier onlyDAO() {
        require(daoActivated && msg.sender == daocontract, "ONLY_DAO");
        _;
    }

    modifier onlyDAOorOwner() {
        if (daoActivated) {
            require(msg.sender == daocontract, "ONLY_DAO");
        } else {
            require(msg.sender == owner, "ONLY_OWNER_PRE_DAO");
        }
        _;
    }

    function setDAO(address dao) external onlyOwner {
        require(dao != address(0), "ZERO");
        daocontract = dao;
        emit DAOSet(dao);
        _emitHubEvent(keccak256("DAO_SET"), msg.sender, 0, abi.encode(dao));
    }

    function activateDAO() external onlyOwner {
        require(daocontract != address(0), "DAO_NOT_SET");
        daoActivated = true;
        emit DAOActivated(daocontract);
        _emitHubEvent(keccak256("DAO_ACTIVATED"), msg.sender, 0, abi.encode(daocontract));
    }

    event DAOSet(address indexed  dao);
    event DAOActivated(address indexed  dao);

    /* ============================================================
                                REGISTRY + HUB
       ============================================================ */

    IMIMHORegistry public immutable registry;

    event RegistrySet(address indexed  registry);

    constructor(address registryAddress) {
        require(registryAddress != address(0), "ZERO_REGISTRY");
        registry = IMIMHORegistry(registryAddress);
        emit RegistrySet(registryAddress);
    }

    function contractType() public pure returns (bytes32) {
        return MODULE_LOCKER;
    }

    function _emitHubEvent(bytes32 action, address caller, uint256 value, bytes memory data) internal {
        address hubAddr = registry.getContract(registry.KEY_MIMHO_EVENTS_HUB());
        if (hubAddr == address(0)) return;
        try IMIMHOEventsHub(hubAddr).emitEvent(contractType(), action, caller, value, data) {
            // ok
        } catch {
            // swallow
        }
    }

    /* ============================================================
                                LOCK MODEL
       ============================================================ */

    enum LockCategory {
        PUBLIC_LOCK,
        DAO_TREASURY_LOCK,
        CEX_RESERVE_LOCK
    }

    struct LockInfo {
        address token;
        address ownerOrController;
        uint256 amount;
        uint64  startTimestamp;
        uint64  unlockTimestamp; // public locks only (0 for internal locks)
        LockCategory category;
        bool released;
    }

    uint256 public nextLockId = 1;

    mapping(uint256 => LockInfo) private _locks;
    mapping(address => uint256) public totalLocked;
    mapping(address => uint256[]) private _userLockIds;

    /* ============================================================
                           INTERNAL CONTROLLED LOCKS
       ============================================================ */

    struct CEXReleaseApproval {
        address recipient;
        uint256 amount;
        bool approved;
        bool executed;
    }

    mapping(uint256 => CEXReleaseApproval) public cexApprovals;

    /* ============================================================
                                FEES (PUBLIC LOCKS)
       ============================================================ */

    struct FeeParams {
        uint256 baseFeeMIMHO;
        uint256 feePerWeekMIMHO;
    }

    FeeParams public feeParams;

    FeeParams public pendingFeeParams;
    uint64 public pendingFeeEta;
    bool public feeUpdatePending;

    event FeeParamsUpdateScheduled(uint256 baseFee, uint256 perWeekFee, uint64 eta);
    event FeeParamsUpdated(uint256 baseFee, uint256 perWeekFee);

    /* ============================================================
                                EVENTS (PUBLIC)
       ============================================================ */

    event LockCreated(
        uint256 indexed lockId,
        address indexed token,
        address indexed lockOwner,
        uint256 amount,
        uint64 unlockTimestamp,
        LockCategory category
    );

    event LockExtended(uint256 indexed lockId, uint64 oldUnlockTimestamp, uint64 newUnlockTimestamp);

    event LockReleased(
        uint256 indexed lockId,
        address indexed token,
        address indexed to,
        uint256 amount,
        LockCategory category
    );

    event FeeCollected(address indexed  payer, uint256 baseFee, uint256 weeksCount, uint256 perWeekFee, uint256 totalFee);

    event FeeDistributed(uint256 toFounder, uint256 toMarketing, uint256 toBurnOrLP, uint256 toDAO, bool burnUsed);

    event BurnExecuted(address indexed  token, uint256 amount);

    event DAOTreasuryReleaseApproved(uint256 indexed lockId, address indexed  dao);
    event CEXReleaseApproved(uint256 indexed lockId, address indexed  recipient, uint256 amount);
    event CEXReleaseExecuted(uint256 indexed lockId, address indexed  recipient, uint256 amount);

    /* ============================================================
                                ADMIN SAFETY
       ============================================================ */

    event PauseEmergencial(address indexed  by);
    event Unpause(address indexed  by);

    function pauseEmergencial() external onlyDAOorOwner {
        _pause();
        emit PauseEmergencial(msg.sender);
        _emitHubEvent(ACTION_PAUSED, msg.sender, 0, "");
    }

    function unpause() external onlyDAOorOwner {
        _unpause();
        emit Unpause(msg.sender);
        _emitHubEvent(ACTION_UNPAUSED, msg.sender, 0, "");
    }

    /* ============================================================
                                INITIAL CONFIG
       ============================================================ */

    function initFeeParams(uint256 baseFeeMIMHO, uint256 feePerWeekMIMHO) external onlyOwner {
        require(!daoActivated, "DAO_ACTIVE");
        feeParams = FeeParams({baseFeeMIMHO: baseFeeMIMHO, feePerWeekMIMHO: feePerWeekMIMHO});
        emit FeeParamsUpdated(baseFeeMIMHO, feePerWeekMIMHO);
    }

    /* ============================================================
                         DAO TIMELOCKED FEE UPDATES
       ============================================================ */

    function scheduleFeeParamsUpdate(uint256 baseFeeMIMHO, uint256 feePerWeekMIMHO) external onlyDAO whenNotPaused {
        pendingFeeParams = FeeParams({baseFeeMIMHO: baseFeeMIMHO, feePerWeekMIMHO: feePerWeekMIMHO});
        pendingFeeEta = uint64(block.timestamp + FEE_TIMELOCK);
        feeUpdatePending = true;

        emit FeeParamsUpdateScheduled(baseFeeMIMHO, feePerWeekMIMHO, pendingFeeEta);
    }

    function executeFeeParamsUpdate() external onlyDAO whenNotPaused {
        require(feeUpdatePending, "NO_PENDING");
        require(block.timestamp >= pendingFeeEta, "TIMELOCK");
        feeParams = pendingFeeParams;
        feeUpdatePending = false;

        emit FeeParamsUpdated(feeParams.baseFeeMIMHO, feeParams.feePerWeekMIMHO);
    }

    /* ============================================================
                             PUBLIC LOCK FUNCTIONS
       ============================================================ */

    /**
     * ✅ SECURITY (Fees before lock struct):
     * _collectAndDistributeFee MUST run before writing to _locks (and before any lockId is created).
     */
    function createPublicLock(
        address token,
        uint256 amount,
        uint64 unlockTimestamp
    ) external nonReentrant whenNotPaused returns (uint256 lockId) {
        // 1. CHECKS
        require(token != address(0), "TOKEN_ZERO");
        require(amount > 0, "AMOUNT_ZERO");
        require(unlockTimestamp > uint64(block.timestamp), "BAD_UNLOCK");

        // 2. EFFECTS (Mudança de estado IMEDIATA)
        // ✅ Geramos o bloqueio no banco de dados ANTES de mexer no dinheiro.
        // Isso garante que, se houver reentrada, o contrato já sabe que esta trava existe.
        lockId = _createLock(
            token,
            msg.sender,
            amount,
            uint64(block.timestamp),
            unlockTimestamp,
            LockCategory.PUBLIC_LOCK
        );
        _userLockIds[msg.sender].push(lockId);

        // 3. INTERACTIONS (Transferências por último)
        uint64 duration = unlockTimestamp - uint64(block.timestamp);

        // Primeiro: Cobrança e distribuição de taxas
        _collectAndDistributeFee(msg.sender, duration);

        // Segundo: Puxamos o token que ficará travado
        require(IERC20(token).transferFrom(msg.sender, address(this), amount), "TRANSFER_IN_FAIL");

        // 4. EVENTS & HUB
        emit LockCreated(lockId, token, msg.sender, amount, unlockTimestamp, LockCategory.PUBLIC_LOCK);
        _emitHubEvent(ACTION_LOCK_CREATED, msg.sender, amount, abi.encode(lockId, token, amount, unlockTimestamp, uint8(LockCategory.PUBLIC_LOCK)));

        return lockId;
    }

    /**
     * ✅ Same CEI-style ordering: fee first, then state update.
     */
    function extendPublicLock(uint256 lockId, uint64 newUnlockTimestamp) external nonReentrant whenNotPaused {
        LockInfo storage L = _locks[lockId];
        require(L.ownerOrController == msg.sender, "NOT_OWNER");
        require(L.category == LockCategory.PUBLIC_LOCK, "NOT_PUBLIC");
        require(!L.released, "RELEASED");
        require(newUnlockTimestamp > L.unlockTimestamp, "NOT_EXTEND");

        uint64 oldUnlock = L.unlockTimestamp;
        uint64 extra = newUnlockTimestamp - oldUnlock;

        // fee first
        _collectAndDistributeFee(msg.sender, extra);

        // then mutate state
        L.unlockTimestamp = newUnlockTimestamp;

        emit LockExtended(lockId, oldUnlock, newUnlockTimestamp);
        _emitHubEvent(ACTION_LOCK_EXTENDED, msg.sender, 0, abi.encode(lockId, oldUnlock, newUnlockTimestamp));
    }

    function releasePublicLock(uint256 lockId) external nonReentrant whenNotPaused {
        LockInfo storage L = _locks[lockId];
        require(L.category == LockCategory.PUBLIC_LOCK, "NOT_PUBLIC");
        require(!L.released, "RELEASED");
        require(msg.sender == L.ownerOrController, "NOT_OWNER");
        require(_isUnlockableTime(L.unlockTimestamp), "NOT_UNLOCKABLE");

        // state first
        L.released = true;
        totalLocked[L.token] -= L.amount;

        // external transfer last
        require(IERC20(L.token).transfer(L.ownerOrController, L.amount), "TRANSFER_OUT_FAIL");

        emit LockReleased(lockId, L.token, L.ownerOrController, L.amount, LockCategory.PUBLIC_LOCK);
        _emitHubEvent(ACTION_LOCK_RELEASED, msg.sender, L.amount, abi.encode(lockId, L.token, L.amount, uint8(LockCategory.PUBLIC_LOCK)));
    }

    /* ============================================================
                        INTERNAL LOCKS (ECOSYSTEM)
       ============================================================ */

    function createDAOTreasuryLock(address token, uint256 amount)
        external
        nonReentrant
        whenNotPaused
        onlyDAOorOwner
        returns (uint256 lockId)
    {
        require(token != address(0), "TOKEN_ZERO");
        require(amount > 0, "AMOUNT_ZERO");

        require(IERC20(token).transferFrom(msg.sender, address(this), amount), "TRANSFER_IN_FAIL");

        lockId = _createLock(
            token,
            daoActivated ? daocontract : msg.sender,
            amount,
            uint64(block.timestamp),
            0,
            LockCategory.DAO_TREASURY_LOCK
        );

        emit LockCreated(lockId, token, daoActivated ? daocontract : msg.sender, amount, 0, LockCategory.DAO_TREASURY_LOCK);
        _emitHubEvent(ACTION_LOCK_CREATED, msg.sender, amount, abi.encode(lockId, token, amount, uint64(0), uint8(LockCategory.DAO_TREASURY_LOCK)));
    }

    function releaseDAOTreasuryLock(uint256 lockId, address recipient, uint256 amount)
        external
        nonReentrant
        whenNotPaused
        onlyDAO
    {
        require(recipient != address(0), "RECIPIENT_ZERO");
        LockInfo storage L = _locks[lockId];
        require(L.category == LockCategory.DAO_TREASURY_LOCK, "NOT_DAO_LOCK");
        require(!L.released, "RELEASED");
        require(amount > 0 && amount <= L.amount, "BAD_AMOUNT");

        L.amount -= amount;
        totalLocked[L.token] -= amount;

        if (L.amount == 0) L.released = true;

        require(IERC20(L.token).transfer(recipient, amount), "TRANSFER_OUT_FAIL");

        emit DAOTreasuryReleaseApproved(lockId, msg.sender);
        emit LockReleased(lockId, L.token, recipient, amount, LockCategory.DAO_TREASURY_LOCK);
        _emitHubEvent(ACTION_DAO_LOCK_READY, msg.sender, amount, abi.encode(lockId, L.token, recipient, amount));
    }

    function createCEXReserveLock(address token, uint256 amount)
        external
        nonReentrant
        whenNotPaused
        onlyDAOorOwner
        returns (uint256 lockId)
    {
        require(token != address(0), "TOKEN_ZERO");
        require(amount > 0, "AMOUNT_ZERO");

        require(IERC20(token).transferFrom(msg.sender, address(this), amount), "TRANSFER_IN_FAIL");

        lockId = _createLock(
            token,
            daoActivated ? daocontract : msg.sender,
            amount,
            uint64(block.timestamp),
            0,
            LockCategory.CEX_RESERVE_LOCK
        );

        emit LockCreated(lockId, token, daoActivated ? daocontract : msg.sender, amount, 0, LockCategory.CEX_RESERVE_LOCK);
        _emitHubEvent(ACTION_LOCK_CREATED, msg.sender, amount, abi.encode(lockId, token, amount, uint64(0), uint8(LockCategory.CEX_RESERVE_LOCK)));
    }

    function approveCEXRelease(uint256 lockId, address recipient, uint256 amount) external onlyDAO whenNotPaused {
        require(recipient != address(0), "RECIPIENT_ZERO");
        LockInfo storage L = _locks[lockId];
        require(L.category == LockCategory.CEX_RESERVE_LOCK, "NOT_CEX_LOCK");
        require(!L.released, "RELEASED");
        require(amount > 0 && amount <= L.amount, "BAD_AMOUNT");

        CEXReleaseApproval storage A = cexApprovals[lockId];
        require(!A.executed, "ALREADY_EXECUTED");

        A.recipient = recipient;
        A.amount = amount;
        A.approved = true;

        emit CEXReleaseApproved(lockId, recipient, amount);
        _emitHubEvent(ACTION_CEX_RELEASE_APPR, msg.sender, amount, abi.encode(lockId, recipient, amount));
    }

    function executeCEXRelease(uint256 lockId) external nonReentrant whenNotPaused onlyDAO {
        LockInfo storage L = _locks[lockId];
        require(L.category == LockCategory.CEX_RESERVE_LOCK, "NOT_CEX_LOCK");
        require(!L.released, "RELEASED");

        CEXReleaseApproval storage A = cexApprovals[lockId];
        require(A.approved, "NOT_APPROVED");
        require(!A.executed, "EXECUTED");
        require(A.amount > 0 && A.amount <= L.amount, "BAD_AMOUNT");

        A.executed = true;

        L.amount -= A.amount;
        totalLocked[L.token] -= A.amount;
        if (L.amount == 0) L.released = true;

        require(IERC20(L.token).transfer(A.recipient, A.amount), "TRANSFER_OUT_FAIL");

        emit CEXReleaseExecuted(lockId, A.recipient, A.amount);
        emit LockReleased(lockId, L.token, A.recipient, A.amount, LockCategory.CEX_RESERVE_LOCK);
        _emitHubEvent(ACTION_LOCK_RELEASED, msg.sender, A.amount, abi.encode(lockId, L.token, A.recipient, A.amount, uint8(LockCategory.CEX_RESERVE_LOCK)));
    }

    /* ============================================================
                              FEE LOGIC (MIMHO)
       ============================================================ */

    function getFeeEstimate(uint64 durationSeconds) public view returns (uint256 totalFee, uint256 weeksCount) {
        weeksCount = _ceilWeeks(durationSeconds);
        totalFee = feeParams.baseFeeMIMHO + (feeParams.feePerWeekMIMHO * weeksCount);
    }

    function _ceilWeeks(uint64 durationSeconds) internal pure returns (uint256) {
        uint256 w = (uint256(durationSeconds) + (WEEK - 1)) / WEEK;
        if (w <= 0) w = 1;
        return w;
    }

    function _mimhoToken() internal view returns (IERC20) {
        address mimho = registry.getContract(registry.KEY_MIMHO_TOKEN());
        require(mimho != address(0), "MIMHO_TOKEN_NOT_SET");
        return IERC20(mimho);
    }

    function _marketingWallet() internal view returns (address) {
        return registry.getContract(registry.KEY_MIMHO_MARKETING_WALLET());
    }

    function _injectLiquidityContract() internal view returns (address) {
        return registry.getContract(registry.KEY_MIMHO_INJECT_LIQUIDITY());
    }

    // Launch dead-end prevention: if DAO not set, route DAO share to founder safe temporarily.
    function _daoPayoutAddressOrFallback() internal view returns (address) {
        return (daocontract == address(0)) ? FOUNDER_SAFE : daocontract;
    }

    function _collectAndDistributeFee(address payer, uint64 durationSeconds) internal {
        (uint256 totalFee, uint256 weeksCount) = getFeeEstimate(durationSeconds);
        require(totalFee > 0, "FEE_ZERO");

        IERC20 mimho = _mimhoToken();

        require(mimho.transferFrom(payer, address(this), totalFee), "FEE_TRANSFER_FAIL");

        emit FeeCollected(payer, feeParams.baseFeeMIMHO, weeksCount, feeParams.feePerWeekMIMHO, totalFee);
        _emitHubEvent(ACTION_FEE_COLLECTED, payer, totalFee, abi.encode(totalFee, weeksCount));

        uint256 toFounder = (totalFee * FOUNDER_BPS) / BPS_DENOM;
        uint256 toMarketing = (totalFee * MARKETING_BPS) / BPS_DENOM;
        uint256 toBurnOrLP = (totalFee * BURN_OR_LP_BPS) / BPS_DENOM;
        uint256 toDAO = totalFee - toFounder - toMarketing - toBurnOrLP;

        require(mimho.transfer(FOUNDER_SAFE, toFounder), "FOUNDER_PAY_FAIL");

        address daoPayout = _daoPayoutAddressOrFallback();
        address marketing = _marketingWallet();
        if (marketing == address(0)) marketing = daoPayout;
        require(mimho.transfer(marketing, toMarketing), "MKT_PAY_FAIL");

        bool burnUsed = false;
        uint256 supply = mimho.totalSupply();

        if (supply > SUPPLY_FLOOR) {
            require(mimho.transfer(BURN_ADDRESS, toBurnOrLP), "BURN_PAY_FAIL");
            burnUsed = true;
            emit BurnExecuted(address(mimho), toBurnOrLP);
            _emitHubEvent(ACTION_BURN_EXECUTED, payer, toBurnOrLP, abi.encode(toBurnOrLP));
        } else {
            address inj = _injectLiquidityContract();
            if (inj != address(0)) {
                bool ok = mimho.transfer(inj, toBurnOrLP);
                if (!ok) {
                    require(mimho.transfer(daoPayout, toBurnOrLP), "DAO_FALLBACK_FAIL");
                }
            } else {
                require(mimho.transfer(daoPayout, toBurnOrLP), "DAO_PAY_FAIL");
            }
        }

        require(mimho.transfer(daoPayout, toDAO), "DAO_PAY_FAIL");

        emit FeeDistributed(toFounder, toMarketing, toBurnOrLP, toDAO, burnUsed);
        _emitHubEvent(ACTION_FEE_DISTRIBUTED, payer, totalFee, abi.encode(toFounder, toMarketing, toBurnOrLP, toDAO, burnUsed));
    }

    /* ============================================================
                              VIEW / QUERIES
       ============================================================ */

    function getLockInfo(uint256 lockId) external view returns (
        address token,
        address ownerOrController,
        uint256 amount,
        uint64 startTimestamp,
        uint64 unlockTimestamp,
        LockCategory category,
        bool released
    ) {
        LockInfo memory L = _locks[lockId];
        return (L.token, L.ownerOrController, L.amount, L.startTimestamp, L.unlockTimestamp, L.category, L.released);
    }

    /**
     * ✅ SECURITY (Explicit time check):
     * - Avoid truncation casts of block.timestamp.
     * - Be explicit: unlockTimestamp != 0 AND now >= unlockTimestamp.
     */
    function isUnlockable(uint256 lockId) public view returns (bool) {
        LockInfo memory L = _locks[lockId];
        if (L.released) return false;
        if (L.category != LockCategory.PUBLIC_LOCK) return false;
        return _isUnlockableTime(L.unlockTimestamp);
    }

    function _isUnlockableTime(uint64 unlockTimestamp) internal view returns (bool) {
        if (unlockTimestamp == 0) return false;
        return uint256(block.timestamp) >= uint256(unlockTimestamp);
    }

    function userLockCount(address user) external view returns (uint256) {
        // ✅ CORREÇÃO SLITHER: Zero check em funções de consulta pública
        require(user != address(0), "MIMHO: user=0");
        return _userLockIds[user].length;
    }

    function userLockIdAt(address user, uint256 index) external view returns (uint256) {
        // ✅ CORREÇÃO SLITHER: Zero check
        require(user != address(0), "MIMHO: user=0");
        require(index < _userLockIds[user].length, "OOB");
        return _userLockIds[user][index];
    }

    function getUserLocks(address user) external view returns (uint256[] memory) {
        // ✅ CORREÇÃO SLITHER: Zero check
        require(user != address(0), "MIMHO: user=0");
        return _userLockIds[user];
    }

    /* ============================================================
                         RECOVER TOKENS (SAFE POLICY)
       ============================================================ */

    event TokensRecovered(address indexed  token, address indexed  to, uint256 amount);

    function recoverTokens(address token, address to, uint256 amount) external onlyDAOorOwner nonReentrant {
        require(token != address(0) && to != address(0), "ZERO");
        uint256 bal = IERC20(token).balanceOf(address(this));
        uint256 locked = totalLocked[token];
        require(bal > locked, "NO_EXCESS");
        uint256 excess = bal - locked;
        require(amount > 0 && amount <= excess, "AMOUNT_EXCEEDS_EXCESS");

        require(IERC20(token).transfer(to, amount), "RECOVER_FAIL");
        emit TokensRecovered(token, to, amount);
        _emitHubEvent(keccak256("TOKENS_RECOVERED"), msg.sender, amount, abi.encode(token, to, amount));
    }

    /* ============================================================
                           INTERNAL CREATE LOCK
       ============================================================ */

    function _createLock(
        address token,
        address controller,
        uint256 amount,
        uint64 startTs,
        uint64 unlockTs,
        LockCategory category
    ) internal returns (uint256 lockId) {
        lockId = nextLockId++;
        _locks[lockId] = LockInfo({
            token: token,
            ownerOrController: controller,
            amount: amount,
            startTimestamp: startTs,
            unlockTimestamp: unlockTs,
            category: category,
            released: false
        });

        totalLocked[token] += amount;
    }
}
