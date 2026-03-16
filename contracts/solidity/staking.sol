/// -----------------------------------------------------------------------
/// MIMHO STAKING
/// Official MIMHO Ecosystem Contract
///
/// Network: BNB Smart Chain
/// Contract Address:
/// 0x33Ad1c1D29F10fee5aC9D3E45067d821F52B097f
///
/// BscScan:
/// https://bscscan.com/address/0x33Ad1c1D29F10fee5aC9D3E45067d821F52B097f
/// -----------------------------------------------------------------------

// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * ============================================================
 * DESIGN PHILOSOPHY — MIMHO STAKING (IMMUTABLE, ENGLISH)
 * ============================================================
 *
 * PURPOSE
 * - Transparent, long-lived staking for MIMHO holders.
 * - Reward distribution is strictly bounded by on-chain caps and backed reserves.
 *
 * NON-NEGOTIABLE SAFETY RULES
 * 1) No admin withdrawals:
 *    - Owner/DAO/SAFEs can NEVER withdraw rewards or user funds.
 *    - Tokens only leave this contract via:
 *        (a) user unstake (principal)
 *        (b) user claim (rewards)
 *
 * 2) Best-effort observability:
 *    - Events are emitted locally and broadcast to Events Hub via try/catch.
 *    - Events Hub must never break user txs.
 *
 * 3) Registry as single source of truth:
 *    - Dependencies are resolved through Registry keys pulled from Registry getters.
 *    - No repeated strings/keccak for Registry keys inside this contract.
 *
 * 4) Long-term survivability:
 *    - Weekly distribution cap
 *    - Promised-phase annual cap for first N days (default 2 years)
 *    - Cooldowns and minimum hold to earn
 *    - DAO can tune parameters within safe bounds
 *
 * 5) Cross-chain future-proofing:
 *    - Optional best-effort hooks for Gateway/Veritas (no funds movement).
 *
 * 6) Reward reserve reconciliation:
 *    - syncRewardsFromBalance() lets DAO/Owner recognize inbound token flows
 *      (e.g., token tax streaming) as official rewardReserve:
 *        rewardReserve = balanceOf(this) - totalStaked
 * ============================================================
 */

import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/* ============================================================
                        REGISTRY INTERFACE
   ============================================================ */
interface IMIMHORegistry {
    function getContract(bytes32 key) external view returns (address);

    function KEY_MIMHO_TOKEN() external view returns (bytes32);
    function KEY_MIMHO_DAO() external view returns (bytes32);
    function KEY_MIMHO_EVENTS_HUB() external view returns (bytes32);
    function KEY_MIMHO_STRATEGY_HUB() external view returns (bytes32);

    function KEY_MIMHO_SCORE() external view returns (bytes32);
    function KEY_MIMHO_SECURITY_WALLET() external view returns (bytes32);
    function KEY_MIMHO_MART() external view returns (bytes32);
    function KEY_MIMHO_BET() external view returns (bytes32);

    function KEY_MIMHO_GATEWAY() external view returns (bytes32);
    function KEY_MIMHO_VERITAS() external view returns (bytes32);
}

/* ============================================================
                        EVENTS HUB INTERFACE
   ============================================================ */
interface IMIMHOEventsHub {
    function emitEvent(
        bytes32 module,
        bytes32 action,
        address caller,
        uint256 value,
        bytes calldata data
    ) external;
}

/* ============================================================
                    OPTIONAL HOOK INTERFACES
   ============================================================ */
interface IMIMHOScore {
    function getBoostValue(address user) external view returns (uint256); // bonusBps
}

interface IMIMHOStrategyHub {
    function getBoostValue(address user) external view returns (uint256); // bonusBps
}

interface IMIMHOSecurityWallet {
    function isSecurityActive(address user) external view returns (bool);
}

interface IMIMHOMartSpend {
    function totalSpentMIMHO(address user) external view returns (uint256);
}

interface IMIMHOBet {
    function isActiveBettor(address user) external view returns (bool);
}

/* ============================================================
                        MIMHO IDENTITY
   ============================================================ */
interface IContratoMIMHO {
    function isContratoMIMHO() external pure returns (bool);
    function tipoContrato() external pure returns (string memory);
    function nomeProjeto() external pure returns (string memory);
}

/* ============================================================
                        OPTIONAL PROTOCOL BUTTONS
   ============================================================ */
interface IMIMHOProtocol {
    function contractName() external pure returns (string memory);
    function contractType() external pure returns (bytes32);
    function version() external pure returns (string memory);

    function paused() external view returns (bool);
    function isObservable() external pure returns (bool);
    function getActionType() external pure returns (bytes32);

    function getRiskLevel() external pure returns (uint8);
    function isFinalized() external view returns (bool);

    function getFinancialImpact(address user)
        external
        view
        returns (uint256 volumeIn, uint256 volumeOut, uint256 lockedValue);

    function getBoostValue(address user) external view returns (uint256);
    function onExternalAction(address user, bytes32 action) external;
}

/* ============================================================
                            STAKING
   ============================================================ */
contract MIMHOStaking is Ownable2Step, ReentrancyGuard, Pausable, IContratoMIMHO, IMIMHOProtocol {
    /* =======================================================
                            CONSTANTS
    ======================================================= */
    string private constant VERSION = "1.0.0";
    bytes32 private constant CONTRACT_TYPE = keccak256("MIMHO_STAKING");
    bytes32 private constant ACTION_TYPE   = keccak256("STAKING_ACTION");

    uint256 private constant BPS = 10_000;
    uint256 private constant ONE_YEAR = 365 days;

    // EventsHub action ids
    bytes32 private constant ACT_INIT              = keccak256("INITIALIZED");
    bytes32 private constant ACT_SET_DAO           = keccak256("SET_DAO");
    bytes32 private constant ACT_ACTIVATE_DAO      = keccak256("ACTIVATE_DAO");
    bytes32 private constant ACT_PAUSE             = keccak256("PAUSE");
    bytes32 private constant ACT_UNPAUSE           = keccak256("UNPAUSE");
    bytes32 private constant ACT_FUND              = keccak256("FUND_REWARDS");
    bytes32 private constant ACT_SYNC_RESERVE      = keccak256("SYNC_REWARD_RESERVE");
    bytes32 private constant ACT_STAKE             = keccak256("STAKE");
    bytes32 private constant ACT_UNSTAKE           = keccak256("UNSTAKE");
    bytes32 private constant ACT_ACCRUE            = keccak256("ACCRUE");
    bytes32 private constant ACT_REINVEST_TOGGLE   = keccak256("REINVEST_TOGGLE");
    bytes32 private constant ACT_CLAIM             = keccak256("CLAIM");
    bytes32 private constant ACT_SET_PARAMS        = keccak256("SET_PARAMS");
    bytes32 private constant ACT_SET_PROMISE       = keccak256("SET_PROMISED_PHASE");
    bytes32 private constant ACT_BLACKLIST         = keccak256("BLACKLIST");

    bytes32 private constant ACT_L2_SYNC           = keccak256("L2_SYNC");

    /* =======================================================
                            STORAGE
    ======================================================= */
    IMIMHORegistry public immutable registry;
    IERC20 public immutable mimhoToken;

    address public dao;
    bool public daoActivated;

    mapping(address => bool) public blacklist;

    uint256 public minStakeAmount;
    uint256 public minHoldToEarn;
    uint256 public claimCooldown;

    uint256 public baseApyBpsTop;
    uint256 public maxTotalApyBps;
    uint256 public maxBoostBps;

    uint256 public rewardReserve;

    uint256 public weeklyLimit;
    uint256 public weekStart;
    uint256 public distributedThisWeek;

    uint256 public promisedPhaseEndsAt;
    uint256 public annualCapPromised;
    uint256 public yearStart;
    uint256 public distributedThisYear;

    uint256 public maxClaimBpsOfWeekly;

    struct StakePos {
        uint256 amount;
        uint256 stakedAt;
        uint256 lastAccrueAt;
        uint256 lastClaimAt;
        uint256 accrued;
        bool reinvest;
    }

    mapping(address => StakePos) public stakes;
    uint256 public totalStaked;

    /* =======================================================
                            EVENTS
    ======================================================= */
    event Initialized(address indexed  by, address indexed registry, address token, uint256 timestamp);
    event DAOSet(address indexed  dao);
    event DAOActivated(address indexed  dao);

    event RewardFunded(address indexed  from, uint256 amount, uint256 newReserve);
    event RewardReserveSynced(address indexed  by, uint256 balance, uint256 totalStaked, uint256 oldReserve, uint256 newReserve);

    event Staked(address indexed  user, uint256 amount, uint256 newUserStake, uint256 totalStakedGlobal);
    event Unstaked(address indexed  user, uint256 amount, uint256 newUserStake, uint256 totalStakedGlobal);

    event Accrued(address indexed  user, uint256 amount, uint256 newAccrued);
    event Claimed(address indexed  user, uint256 rewardPaid, bool reinvested);

    event ReinvestToggled(address indexed  user, bool enabled);
    event BlacklistSet(address indexed  user, bool status);

    event ConfigUpdated(bytes32 indexed key, uint256 oldValue, uint256 newValue);

    /* =======================================================
                          MODIFIERS
    ======================================================= */
    modifier onlyDAOorOwner() {
        if (daoActivated) {
            require(msg.sender == dao, "MIMHO: DAO only");
        } else {
            require(msg.sender == owner(), "MIMHO: owner only");
        }
        _;
    }

    /* =======================================================
                          CONSTRUCTOR
    ======================================================= */
    constructor(address registryAddress) {
        require(registryAddress != address(0), "MIMHO: registry=0");
        registry = IMIMHORegistry(registryAddress);

        address tokenAddr = registry.getContract(registry.KEY_MIMHO_TOKEN());
        require(tokenAddr != address(0), "MIMHO: token not set in registry");
        mimhoToken = IERC20(tokenAddr);

        // Defaults
        minStakeAmount = 100_000 * 1e18;
        minHoldToEarn = 7 days;
        claimCooldown = 7 days;

        baseApyBpsTop = 3500;   // 35%
        maxTotalApyBps = 4000;  // 40% clamp
        maxBoostBps = 500;      // +5% max boost

        weeklyLimit = 25_000_000 * 1e18;
        maxClaimBpsOfWeekly = 500; // 5% per claim

        weekStart = _startOfWeek(block.timestamp);
        yearStart = _startOfYear(block.timestamp);

        promisedPhaseEndsAt = block.timestamp + 730 days;
        annualCapPromised = 15_000_000_000 * 1e18;

        emit Initialized(msg.sender, registryAddress, tokenAddr, block.timestamp);
        _emitHubEvent(ACT_INIT, 0, abi.encode(registryAddress, tokenAddr, block.timestamp));
    }

    /* =======================================================
                    MIMHO IDENTITY (HUD)
    ======================================================= */
    function isContratoMIMHO() external pure override returns (bool) { return true; }
    function tipoContrato() external pure override returns (string memory) { return "Staking"; }
    function nomeProjeto() external pure override returns (string memory) { return "MIMHO Staking"; }

    /* =======================================================
                IMIMHOProtocol BUTTONS (HUD)
    ======================================================= */
    function contractName() external pure override returns (string memory) { return "MIMHO Staking"; }
    function contractType() external pure override returns (bytes32) { return CONTRACT_TYPE; }
    function version() external pure override returns (string memory) { return VERSION; }

    function paused() public view override(IMIMHOProtocol, Pausable) returns (bool) { return Pausable.paused(); }
    function isObservable() external pure override returns (bool) { return true; }
    function getActionType() external pure override returns (bytes32) { return ACTION_TYPE; }
    function getRiskLevel() external pure override returns (uint8) { return 0; }
    function isFinalized() external pure override returns (bool) { return false; }

    function getFinancialImpact(address user)
        external
        view
        override
        returns (uint256 volumeIn, uint256 volumeOut, uint256 lockedValue)
    {
        StakePos memory p = stakes[user];
        return (0, 0, p.amount);
    }

    function getBoostValue(address user) external view override returns (uint256) {
        return _computeBoostBps(user);
    }

    function onExternalAction(address, bytes32) external pure override {
        // reserved
    }

    /* =======================================================
                        GOVERNANCE
    ======================================================= */
    function setDAO(address daoAddr) external onlyOwner whenNotPaused {
        require(daoAddr != address(0), "MIMHO: dao=0");
        require(dao == address(0), "MIMHO: dao already set");

        dao = daoAddr;
        emit DAOSet(daoAddr);
        _emitHubEvent(ACT_SET_DAO, 0, abi.encode(daoAddr));
    }

    function activateDAO() external onlyOwner whenNotPaused {
        require(dao != address(0), "MIMHO: dao not set");
        require(!daoActivated, "MIMHO: already activated");
        daoActivated = true;
        emit DAOActivated(dao);
        _emitHubEvent(ACT_ACTIVATE_DAO, 0, abi.encode(dao));
    }

    /* =======================================================
                        PAUSE (EMERGENCY)
    ======================================================= */
    function pauseEmergencial() external onlyDAOorOwner {
        _pause();
        _emitHubEvent(ACT_PAUSE, 0, "");
    }

    function unpause() external onlyDAOorOwner {
        _unpause();
        _emitHubEvent(ACT_UNPAUSE, 0, "");
    }

    /* =======================================================
                        FUND REWARDS
    ======================================================= */
    function fundRewards(uint256 amount) external nonReentrant whenNotPaused {
        require(amount > 0, "MIMHO: amount=0");
        require(mimhoToken.transferFrom(msg.sender, address(this), amount), "MIMHO: transferFrom fail");
        rewardReserve += amount;

        emit RewardFunded(msg.sender, amount, rewardReserve);
        _emitHubEvent(ACT_FUND, amount, abi.encode(amount, rewardReserve));
    }

    /* =======================================================
                    SYNC REWARDS FROM BALANCE
    ======================================================= */
    function syncRewardsFromBalance() external onlyDAOorOwner {
        uint256 bal = mimhoToken.balanceOf(address(this));
        require(bal >= totalStaked, "MIMHO: balance < totalStaked");

        uint256 newReserve = bal - totalStaked;
        uint256 oldReserve = rewardReserve;
        rewardReserve = newReserve;

        emit RewardReserveSynced(msg.sender, bal, totalStaked, oldReserve, newReserve);
        _emitHubEvent(ACT_SYNC_RESERVE, newReserve, abi.encode(bal, totalStaked, oldReserve, newReserve));
    }

    /* =======================================================
                            STAKE
    ======================================================= */
    function stake(uint256 amount) external nonReentrant whenNotPaused {
        require(!blacklist[msg.sender], "MIMHO: blacklisted");
        require(amount >= minStakeAmount, "MIMHO: below min stake");

        _accrue(msg.sender);

        require(mimhoToken.transferFrom(msg.sender, address(this), amount), "MIMHO: transferFrom fail");

        StakePos storage p = stakes[msg.sender];
        if (p.amount == 0) {
            p.stakedAt = block.timestamp;
            p.lastAccrueAt = block.timestamp;
        }
        p.amount += amount;
        totalStaked += amount;

        emit Staked(msg.sender, amount, p.amount, totalStaked);
        _emitHubEvent(ACT_STAKE, amount, abi.encode(msg.sender, amount, p.amount, totalStaked));
    }

    /* =======================================================
                            UNSTAKE
    ======================================================= */
    function unstake(uint256 amount) external nonReentrant whenNotPaused {
        StakePos storage p = stakes[msg.sender];
        require(amount > 0, "MIMHO: amount=0");
        require(p.amount >= amount, "MIMHO: insufficient");

        _accrue(msg.sender);

        p.amount -= amount;
        totalStaked -= amount;

        require(mimhoToken.transfer(msg.sender, amount), "MIMHO: transfer fail");

        emit Unstaked(msg.sender, amount, p.amount, totalStaked);
        _emitHubEvent(ACT_UNSTAKE, amount, abi.encode(msg.sender, amount, p.amount, totalStaked));
    }

    /* =======================================================
                            CLAIM
        ✅ Slither instruction:
        - Move _accrue to the top (after requires)
        - All state changes immediately after requires (CEI)
        - Absolute end: transfer/reinvest action
        - Hub emit must not happen mid-function (last line best-effort)
    ======================================================= */
    function claim() external nonReentrant whenNotPaused {
    require(!blacklist[msg.sender], "MIMHO: blacklisted");

    StakePos storage p = stakes[msg.sender];
    require(p.amount > 0, "MIMHO: no stake");

    // Must have held stake for minimum time to earn
    require(block.timestamp >= p.stakedAt + minHoldToEarn, "MIMHO: hold too short");

    // Cooldown between claims
    require(p.lastClaimAt == 0 || block.timestamp >= p.lastClaimAt + claimCooldown, "MIMHO: cooldown");

    // Roll caps windows first (pure state, no transfers)
    _rollWeekIfNeeded();
    _rollYearIfNeeded();

    // Accrue first (updates p.accrued and p.lastAccrueAt)
    _accrue(msg.sender);

    uint256 reward = p.accrued;
    require(reward > 0, "MIMHO: no reward");

    // Per-claim cap (anti-drain): max % of weeklyLimit
    uint256 maxPerClaim = (weeklyLimit * maxClaimBpsOfWeekly) / BPS;
    if (reward > maxPerClaim) {
        reward = maxPerClaim;
    }

    // Weekly cap
    require(distributedThisWeek + reward <= weeklyLimit, "MIMHO: weekly cap");

    // Promised-phase annual cap (first N days)
    if (block.timestamp <= promisedPhaseEndsAt) {
        require(distributedThisYear + reward <= annualCapPromised, "MIMHO: annual cap");
    }

    // Reserve safety
    require(rewardReserve >= reward, "MIMHO: reserve low");

    // --------------------
    // EFFECTS (CEI)
    // --------------------
    p.accrued -= reward;
    p.lastClaimAt = block.timestamp;

    rewardReserve -= reward;

    distributedThisWeek += reward;
    if (block.timestamp <= promisedPhaseEndsAt) {
        distributedThisYear += reward;
    }

    bool reinvested = p.reinvest;
    if (reinvested) {
        // Reinvest converts reward into more stake (no token leaves contract)
        p.amount += reward;
        totalStaked += reward;
    }

    emit Claimed(msg.sender, reward, reinvested);

    // --------------------
    // INTERACTIONS (ABSOLUTE END)
    // --------------------
    if (!reinvested) {
        require(mimhoToken.transfer(msg.sender, reward), "MIMHO: transfer fail");
    }

    _emitHubEvent(ACT_CLAIM, reward, abi.encode(msg.sender, reward, reinvested, p.amount, totalStaked, rewardReserve));
}

    function setReinvest(bool enabled) external whenNotPaused {
        stakes[msg.sender].reinvest = enabled;
        emit ReinvestToggled(msg.sender, enabled);
        _emitHubEvent(ACT_REINVEST_TOGGLE, 0, abi.encode(msg.sender, enabled));
    }

    /* =======================================================
                        ADMIN SAFE PARAMS
    ======================================================= */
    function setBlacklist(address user, bool status) external onlyDAOorOwner {
        // ✅ CORREÇÃO ITEM 7: Zero address check
        require(user != address(0), "MIMHO: user=0");

        // Proteção extra: não deixar o dono/dao se auto-bloquear
        require(user != msg.sender, "MIMHO: cannot blacklist self");

        blacklist[user] = status;
        emit BlacklistSet(user, status);
        _emitHubEvent(ACT_BLACKLIST, 0, abi.encode(user, status));
    }

    function setParams(
        uint256 minStakeAmountNew,
        uint256 minHoldToEarnNew,
        uint256 claimCooldownNew,
        uint256 weeklyLimitNew,
        uint256 maxClaimBpsOfWeeklyNew,
        uint256 baseApyBpsTopNew,
        uint256 maxTotalApyBpsNew,
        uint256 maxBoostBpsNew
    ) external onlyDAOorOwner {
        require(minStakeAmountNew > 0, "MIMHO: minStake=0");
        require(weeklyLimitNew > 0, "MIMHO: weekly=0");
        require(maxClaimBpsOfWeeklyNew <= BPS, "MIMHO: bps>100%");
        require(baseApyBpsTopNew <= BPS, "MIMHO: baseAPY>100%");
        require(maxTotalApyBpsNew <= BPS, "MIMHO: maxAPY>100%");
        require(maxTotalApyBpsNew >= baseApyBpsTopNew, "MIMHO: max<base");
        require(maxBoostBpsNew <= BPS, "MIMHO: boost>100%");

        _setCfg(keccak256("MIN_STAKE"), minStakeAmount, minStakeAmountNew); minStakeAmount = minStakeAmountNew;
        _setCfg(keccak256("MIN_HOLD"), minHoldToEarn, minHoldToEarnNew); minHoldToEarn = minHoldToEarnNew;
        _setCfg(keccak256("COOLDOWN"), claimCooldown, claimCooldownNew); claimCooldown = claimCooldownNew;
        _setCfg(keccak256("WEEKLY_LIMIT"), weeklyLimit, weeklyLimitNew); weeklyLimit = weeklyLimitNew;
        _setCfg(keccak256("MAX_CLAIM_BPS_WEEK"), maxClaimBpsOfWeekly, maxClaimBpsOfWeeklyNew); maxClaimBpsOfWeekly = maxClaimBpsOfWeeklyNew;

        _setCfg(keccak256("BASE_APY_TOP"), baseApyBpsTop, baseApyBpsTopNew); baseApyBpsTop = baseApyBpsTopNew;
        _setCfg(keccak256("MAX_TOTAL_APY"), maxTotalApyBps, maxTotalApyBpsNew); maxTotalApyBps = maxTotalApyBpsNew;
        _setCfg(keccak256("MAX_BOOST_BPS"), maxBoostBps, maxBoostBpsNew); maxBoostBps = maxBoostBpsNew;

        _emitHubEvent(ACT_SET_PARAMS, 0, abi.encode(
            minStakeAmountNew, minHoldToEarnNew, claimCooldownNew, weeklyLimitNew,
            maxClaimBpsOfWeeklyNew, baseApyBpsTopNew, maxTotalApyBpsNew, maxBoostBpsNew
        ));
    }

    function setPromisedPhase(uint256 endsAtNew, uint256 annualCapNew) external onlyDAOorOwner {
        require(endsAtNew >= block.timestamp, "MIMHO: endsAt<present");
        require(annualCapNew > 0, "MIMHO: annualCap=0");

        _setCfg(keccak256("PROMISE_END"), promisedPhaseEndsAt, endsAtNew); promisedPhaseEndsAt = endsAtNew;
        _setCfg(keccak256("PROMISE_ANNUAL_CAP"), annualCapPromised, annualCapNew); annualCapPromised = annualCapNew;

        _emitHubEvent(ACT_SET_PROMISE, 0, abi.encode(endsAtNew, annualCapNew));
    }

    /* =======================================================
                L2 / CROSS-CHAIN HOOKS (BEST-EFFORT)
    ======================================================= */
    function onL2Sync(address user, uint256 externalScoreHint, bytes calldata data) external whenNotPaused {
        address gw = registry.getContract(registry.KEY_MIMHO_GATEWAY());
        address ver = registry.getContract(registry.KEY_MIMHO_VERITAS());
        require(msg.sender == gw || msg.sender == ver, "MIMHO: only gateway/veritas");

        _emitHubEvent(ACT_L2_SYNC, 0, abi.encode(user, externalScoreHint, data, block.chainid));
    }

    /* =======================================================
                        VIEWS (HUD)
    ======================================================= */
    function getConfig() external view returns (
        address registryAddr,
        address tokenAddr,
        address daoAddr,
        bool daoActive,
        uint256 minStake,
        uint256 minHold,
        uint256 cooldown,
        uint256 baseApy,
        uint256 maxApy,
        uint256 maxBoost,
        uint256 weeklyCap,
        uint256 maxClaimBpsWeek,
        uint256 promisedEndsAt,
        uint256 annualCap,
        uint256 reserve
    ) {
        return (
            address(registry),
            address(mimhoToken),
            dao,
            daoActivated,
            minStakeAmount,
            minHoldToEarn,
            claimCooldown,
            baseApyBpsTop,
            maxTotalApyBps,
            maxBoostBps,
            weeklyLimit,
            maxClaimBpsOfWeekly,
            promisedPhaseEndsAt,
            annualCapPromised,
            rewardReserve
        );
    }

    function getStats() external view returns (
        uint256 total,
        uint256 reserve,
        uint256 distWeek,
        uint256 weekZero,
        uint256 distYear,
        uint256 yearZero
    ) {
        return (
            totalStaked,
            rewardReserve,
            distributedThisWeek,
            weekStart,
            distributedThisYear,
            yearStart
        );
    }

    function getUser(address user) external view returns (
        uint256 amount,
        uint256 stakedAt,
        uint256 lastAccrueAt,
        uint256 lastClaimAt,
        uint256 accrued,
        bool reinvest,
        uint256 boostBps
    ) {
        StakePos memory p = stakes[user];
        return (p.amount, p.stakedAt, p.lastAccrueAt, p.lastClaimAt, p.accrued, p.reinvest, _computeBoostBps(user));
    }

    function pendingReward(address user) external view returns (uint256) {
        StakePos memory p = stakes[user];
        if (p.amount == 0) return 0;
        uint256 extra = _earnedView(user, p);
        return p.accrued + extra;
    }

    /* =======================================================
                        INTERNAL: ACCRUAL
    ======================================================= */
    function _accrue(address user) internal {
        StakePos storage p = stakes[user];
        if (p.amount == 0) {
            p.lastAccrueAt = block.timestamp;
            return;
        }
        if (p.lastAccrueAt == 0) p.lastAccrueAt = block.timestamp;
        if (block.timestamp <= p.lastAccrueAt) return;

        uint256 earned = _earned(user, p);
        p.lastAccrueAt = block.timestamp;

        if (earned > 0) {
            p.accrued += earned;
            emit Accrued(user, earned, p.accrued);
            _emitHubEvent(ACT_ACCRUE, earned, abi.encode(user, earned, p.accrued));
        }
    }

    function _earned(address user, StakePos memory p) internal view returns (uint256) {
        if (block.timestamp < p.stakedAt + minHoldToEarn) return 0;

        uint256 dt = block.timestamp - p.lastAccrueAt;
        if (dt <= 0) return 0;

        uint256 boostBps = _computeBoostBps(user);
        uint256 apyBps = baseApyBpsTop + boostBps;
        if (apyBps > maxTotalApyBps) apyBps = maxTotalApyBps;

        return (p.amount * apyBps * dt) / (BPS * ONE_YEAR);
    }

    function _earnedView(address user, StakePos memory p) internal view returns (uint256) {
        if (p.amount == 0 || p.lastAccrueAt == 0) return 0;
        if (block.timestamp <= p.lastAccrueAt) return 0;
        if (block.timestamp < p.stakedAt + minHoldToEarn) return 0;
        return _earned(user, p);
    }

    /* =======================================================
                        INTERNAL: BOOSTS
    ======================================================= */
    function _computeBoostBps(address user) internal view returns (uint256) {
        address hub = registry.getContract(registry.KEY_MIMHO_STRATEGY_HUB());
        if (hub != address(0)) {
            try IMIMHOStrategyHub(hub).getBoostValue(user) returns (uint256 b) {
                if (b > maxBoostBps) b = maxBoostBps;
                return b;
            } catch {
                // fallback
            }
        }
        return _checkLocalBoosts(user);
    }

    function _checkLocalBoosts(address user) private view returns (uint256) {
        uint256 bLocal = 0;

        address scoreAddr = registry.getContract(registry.KEY_MIMHO_SCORE());
        if (scoreAddr != address(0)) {
            try IMIMHOScore(scoreAddr).getBoostValue(user) returns (uint256 b) {
                if (b > maxBoostBps) b = maxBoostBps;
                bLocal += b;
            } catch {}
        }

        address secAddr = registry.getContract(registry.KEY_MIMHO_SECURITY_WALLET());
        if (secAddr != address(0)) {
            try IMIMHOSecurityWallet(secAddr).isSecurityActive(user) returns (bool ok) {
                if (ok) bLocal += 100;
            } catch {}
        }

        address martAddr = registry.getContract(registry.KEY_MIMHO_MART());
        if (martAddr != address(0)) {
            try IMIMHOMartSpend(martAddr).totalSpentMIMHO(user) returns (uint256 spent) {
                if (spent >= 10_000_000 * 1e18) bLocal += 100;
            } catch {}
        }

        address betAddr = registry.getContract(registry.KEY_MIMHO_BET());
        if (betAddr != address(0)) {
            try IMIMHOBet(betAddr).isActiveBettor(user) returns (bool ok2) {
                if (ok2) bLocal += 100;
            } catch {}
        }

        if (bLocal > maxBoostBps) bLocal = maxBoostBps;
        return bLocal;
    }

    /* =======================================================
                        INTERNAL: CAPS WINDOWS
    ======================================================= */
    function _rollWeekIfNeeded() internal {
        uint256 ws = _startOfWeek(block.timestamp);
        if (ws != weekStart) {
            weekStart = ws;
            distributedThisWeek = 0;
        }
    }

    function _rollYearIfNeeded() internal {
        uint256 ys = _startOfYear(block.timestamp);
        if (ys != yearStart) {
            yearStart = ys;
            distributedThisYear = 0;
        }
    }

    function _startOfWeek(uint256 t) internal pure returns (uint256) {
        return t - (t % 7 days);
    }

    function _startOfYear(uint256 t) internal pure returns (uint256) {
        return t - (t % 365 days);
    }

    /* =======================================================
                    EVENTS HUB (ABSOLUTE STANDARD)
    ======================================================= */
    function _emitHubEvent(bytes32 action, uint256 value, bytes memory data) internal {
        address hubAddr = registry.getContract(registry.KEY_MIMHO_EVENTS_HUB());
        if (hubAddr == address(0)) return;

        try IMIMHOEventsHub(hubAddr).emitEvent(CONTRACT_TYPE, action, msg.sender, value, data) {
        } catch {
        }
    }

    function _setCfg(bytes32 key, uint256 oldV, uint256 newV) internal {
        emit ConfigUpdated(key, oldV, newV);
    }

    receive() external payable { revert("MIMHO: NO_BNB"); }
    fallback() external payable { revert("MIMHO: NO_BNB"); }

    /// @dev Resgata BNB preso acidentalmente no contrato.
    function rescueNative() external onlyDAOorOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "MIMHO: balance is zero");
        (bool success, ) = payable(msg.sender).call{value: balance}("");
        require(success, "MIMHO: rescue failed");
    }
}
