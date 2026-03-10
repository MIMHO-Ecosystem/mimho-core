<<<<<<< HEAD
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

abstract contract MIMHO Quiz Academy {
    string public constant version = "0.0.0-placeholder";
    function contractType() public pure virtual returns (bytes32) { return keccak256("MIMHO_QUIZ"); }
}
 *
 * @dev STATUS: AWAITING DEPLOY
 * ------------------------------------------------------------
 * This file exists to:
 * - reserve the canonical contract name and path in the public repo
 * - provide an auditable, timestamped trail of the ecosystem structure
 * - link to the finalized technical specification before deployment
 *
 * Source of Truth (spec):
 * - contracts/specs/SPEC_FILE
 *
 * DESIGN PHILOSOPHY (MIMHO)
 * ------------------------------------------------------------
 * MIMHO contracts are designed to be:
 * - modular and Registry-driven (single source of truth)
 * - transparent and HUD-ready (standardized events)
 * - secure by default (no privileged hidden paths)
 * - upgrade-proof by architecture (clear separation of concerns)
 *
 * IMPORTANT
 * ------------------------------------------------------------
 * This is NOT the final deployed code.
 * The real implementation will be added only after:
 * - internal review
 * - dependency locking
 * - security checklist
 * - audit readiness
 */
abstract contract MIMHO Quiz Academy {
    /// @notice Human readable version for repository tracking (not on-chain guarantee).
    string public constant version = "0.0.0-placeholder";

    /// @notice Contract module type identifier (used by HUD/Events Hub in final builds).
    function contractType() public pure virtual returns (bytes32) {
        return CONTRACT_TYPE;
    }
}
=======
/// -----------------------------------------------------------------------
/// MIMHO QUIZ ACADEMY
/// Official MIMHO Ecosystem Contract
///
/// Network: BNB Smart Chain
/// Contract Address:
/// 0x0Aa3ea599427Db9c1154911001d459B6712d1BBD
///
/// BscScan:
/// https://bscscan.com/address/0x0Aa3ea599427Db9c1154911001d459B6712d1BBD
/// -----------------------------------------------------------------------

// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/* ============================================================
   MIMHO QUIZ — v1.0.0 (MIMHO ABSOLUTE STANDARD)
   ============================================================

   DESIGN PHILOSOPHY (MIMHO ABSOLUTE STANDARD)

   - Radical Transparency:
     Every meaningful action emits public events and forwards best-effort
     signals to the MIMHO Events Hub (HUD loudspeaker).

   - No Human Withdraw:
     No owner/DAO/anyone can withdraw funds. The contract only pays rewards
     to eligible users via claim() rules.

   - Sustainable Cycles:
     30-day cycles. Users may play unlimited times off-chain, but can only
     be rewarded once per cycle (on-chain).

   - Scalable Distribution:
     No loops over participants. Rewards computed once at cycle close,
     and each user claims individually (gas paid by claimant).

   - Safety First:
     Pausable. Reentrancy guard. Strict checks. Best-effort external calls.
     Dead-man failsafe after long inactivity sends remaining tokens to DAO wallet.

   - Ecosystem-Coupled:
     All integrations resolved via Registry KEY getters (no local keccak/strings).
     Events Hub emission is always try/catch (best-effort), never blocking users.

   - CEI Discipline (Quiz Academy):
     In completeQuiz, closeCycle, claimReward: all STATE UPDATES occur before
     any external interaction (token transfers, Events Hub emitEvent, Certify calls).

   ============================================================ */

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address a) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
}

interface IMIMHORegistry {
    function getContract(bytes32 key) external view returns (address);

    // --- KEY getters (ABSOLUTE STANDARD: never repeat strings/keccak locally)
    function KEY_MIMHO_TOKEN() external view returns (bytes32);
    function KEY_MIMHO_EVENTS_HUB() external view returns (bytes32);

    // DAO contract (governance controller)
    function KEY_MIMHO_DAO() external view returns (bytes32);

    // DAO treasury wallet (preferred) — fallback to KEY_MIMHO_DAO if unset
    function KEY_MIMHO_DAO_WALLET() external view returns (bytes32);

    // Optional
    function KEY_MIMHO_CERTIFY() external view returns (bytes32);
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
 * @dev Optional: MIMHO Certify integration (best-effort).
 *      If the Certify contract is not deployed / not set, calls are skipped.
 */
interface IMIMHOCertify {
    function certify(
        bytes32 module,
        bytes32 action,
        address subject,
        uint256 value,
        bytes calldata data
    ) external;
}

/* =========================
   Minimal OZ-like guards
   ========================= */

abstract contract ReentrancyGuard {
    uint256 private _status;
    constructor() { _status = 1; }
    modifier nonReentrant() {
        require(_status == 1, "REENTRANCY");
        _status = 2;
        _;
        _status = 1;
    }
}

abstract contract Ownable {
    address public owner;
    event OwnershipTransferred(address indexed  previousOwner, address indexed  newOwner);
    constructor(address initialOwner) {
        require(initialOwner != address(0), "OWNER_0");
        owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }
    modifier onlyOwner() { require(msg.sender == owner, "ONLY_OWNER"); _; }
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "OWNER_0");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
}

abstract contract Pausable {
    bool public paused;
    event Paused(address indexed  by);
    event Unpaused(address indexed  by);
    modifier whenNotPaused() { require(!paused, "PAUSED"); _; }
    modifier whenPaused() { require(paused, "NOT_PAUSED"); _; }
    function _pause() internal whenNotPaused { paused = true; emit Paused(msg.sender); }
    function _unpause() internal whenPaused { paused = false; emit Unpaused(msg.sender); }
}

/* ============================================================
   MIMHO QUIZ
   ============================================================ */
contract MIMHOQuiz is Ownable, Pausable, ReentrancyGuard {
    /* =========================
       Constants / Metadata
       ========================= */
    string public constant name = "MIMHO Quiz";
    string public constant version = "1.0.0";

    // HUD / Events Hub module identifier
    bytes32 private constant MODULE = bytes32("MIMHO_QUIZ");

    // Cycle design
    uint256 public constant DEFAULT_CYCLE_DURATION = 30 days;

    // Dead-man failsafe
    uint256 public constant FAILSAFE_DELAY = 730 days; // 2 years

    /* =========================
       Registry / Hub (resolved via Registry keys)
       ========================= */
    IMIMHORegistry public immutable registry;

    /* =========================
       DAO Takeover Pattern
       ========================= */
    bool public daoActivated;

    modifier onlyDAOorOwner() {
        if (daoActivated) {
            address daoAddr = registry.getContract(registry.KEY_MIMHO_DAO());
            require(daoAddr != address(0), "DAO_NOT_SET");
            require(msg.sender == daoAddr, "ONLY_DAO");
        } else {
            require(msg.sender == owner, "ONLY_OWNER");
        }
        _;
    }

    function activateDAO() external onlyOwner {
        address daoAddr = registry.getContract(registry.KEY_MIMHO_DAO());
        require(daoAddr != address(0), "DAO_NOT_SET");
        daoActivated = true;
        emit DAOActivated(daoAddr);
        _emitHubEvent(bytes32("DAO_ACTIVATED"), msg.sender, 0, abi.encode(daoAddr));
    }

    /* =========================
       Programs (MIMHO + future Labs campaigns)
       ========================= */
    struct Program {
        bool exists;
        bool active;
        uint256 startTimestamp;
        uint256 cycleDuration;

        // Reward settings:
        // - rewardPerCycleCurrent is locked at cycle initialization
        // - pendingRewardPerCycle applies to the NEXT cycle initialization
        uint256 rewardPerCycleCurrent;
        uint256 pendingRewardPerCycle;
        bool hasPendingRewardUpdate;

        // Bookkeeping
        uint256 lastInitializedCycleId;
    }

    // programId => Program
    mapping(uint256 => Program) public programs;
    uint256 public nextProgramId; // starts from 1 for external; 0 is MIMHO default

    /* =========================
       Cycle Data
       ========================= */
    struct CycleData {
        bool initialized;
        bool closed;
        uint256 participants;
        uint256 rewardPool;
        uint256 rewardPerUser;
        uint256 closedAt;
    }

    // programId => cycleId => CycleData
    mapping(uint256 => mapping(uint256 => CycleData)) public cycles;

    // programId => cycleId => user => completed?
    mapping(uint256 => mapping(uint256 => mapping(address => bool))) public completed;

    // programId => cycleId => user => claimed?
    mapping(uint256 => mapping(uint256 => mapping(address => bool))) public claimed;

    /* =========================
       Differential #2: public learning history
       ========================= */
    mapping(address => uint256) public totalQuizCompletions;
    mapping(address => uint256) public totalCyclesParticipated;

    // programId => user => last cycle id participated (to avoid double-counting cyclesParticipated)
    mapping(uint256 => mapping(address => uint256)) private _lastCycleParticipated;

    /* =========================
       Funding / Failsafe
       ========================= */
    uint256 public lastInteractionTimestamp;
    bool public failsafeTriggered;

    /* =========================
       Events
       ========================= */
    event DAOActivated(address indexed  dao);

    event ProgramCreated(
        uint256 indexed programId,
        address indexed creator,
        uint256 startTimestamp,
        uint256 cycleDuration,
        uint256 rewardPerCycle
    );

    event ProgramStatusUpdated(uint256 indexed programId, bool active);

    event RewardPerCycleUpdateScheduled(uint256 indexed programId, uint256 oldValue, uint256 newValue);

    event CycleInitialized(uint256 indexed programId, uint256 indexed cycleId, uint256 rewardPool);
    event QuizCompleted(uint256 indexed programId, uint256 indexed cycleId, address indexed  user);
    event CycleClosed(uint256 indexed programId, uint256 indexed cycleId, uint256 participants, uint256 rewardPerUser);
    event RewardClaimed(uint256 indexed programId, uint256 indexed cycleId, address indexed  user, uint256 amount);

    event QuizFunded(address indexed  from, uint256 amount);

    event FailsafeTriggered(uint256 timestamp, uint256 remainingBalance, address indexed daoWallet);

    /* =========================
       Constructor
       ========================= */
    constructor(address registryAddress) Ownable(msg.sender) {
        require(registryAddress != address(0), "REGISTRY_0");
        registry = IMIMHORegistry(registryAddress);

        // Default Program 0 (MIMHO)
        programs[0] = Program({
            exists: true,
            active: true,
            startTimestamp: block.timestamp,
            cycleDuration: DEFAULT_CYCLE_DURATION,
            rewardPerCycleCurrent: 50_000_000 ether, // assumes 18 decimals; adjust if token differs
            pendingRewardPerCycle: 0,
            hasPendingRewardUpdate: false,
            lastInitializedCycleId: 0
        });

        nextProgramId = 1;
        lastInteractionTimestamp = block.timestamp;

        emit ProgramCreated(0, msg.sender, programs[0].startTimestamp, programs[0].cycleDuration, programs[0].rewardPerCycleCurrent);
        _emitHubEvent(bytes32("PROGRAM_CREATED"), msg.sender, 0, abi.encode(uint256(0), programs[0].cycleDuration, programs[0].rewardPerCycleCurrent));
    }

    /* ============================================================
       ABSOLUTE STANDARD: Events Hub emission (best-effort via Registry)
       ============================================================ */
    function contractType() public pure returns (bytes32) {
        return MODULE;
    }

    function _emitHubEvent(bytes32 action, address caller, uint256 value, bytes memory data) internal {
        address hubAddr = registry.getContract(registry.KEY_MIMHO_EVENTS_HUB());
        if (hubAddr == address(0)) return;
        try IMIMHOEventsHub(hubAddr).emitEvent(contractType(), action, caller, value, data) {
            // best-effort
        } catch {
            // never break core logic
        }
    }

    /* ============================================================
       Token resolver (via Registry)
       ============================================================ */
    function mimhoToken() public view returns (IERC20) {
        address tokenAddr = registry.getContract(registry.KEY_MIMHO_TOKEN());
        require(tokenAddr != address(0), "TOKEN_NOT_SET");
        return IERC20(tokenAddr);
    }

    /* ============================================================
       DAO treasury resolver (KEY_MIMHO_DAO_WALLET preferred; fallback KEY_MIMHO_DAO)
       ============================================================ */
    function daoTreasury() public view returns (address) {
    // Prefer DAO_WALLET if Registry supports it (avoid hard dependency)
    (bool ok, bytes memory ret) =
        address(registry).staticcall(abi.encodeWithSelector(IMIMHORegistry.KEY_MIMHO_DAO_WALLET.selector));

    if (ok && ret.length >= 32) {
        bytes32 keyWallet = abi.decode(ret, (bytes32));
        if (keyWallet != bytes32(0)) {
            address w = registry.getContract(keyWallet);
            if (w != address(0)) return w;
        }
    }

    // Fallback: DAO contract itself
    return registry.getContract(registry.KEY_MIMHO_DAO());
}

    /* ============================================================
       Admin controls (DAO or Owner until DAO activation)
       ============================================================ */
    function pauseEmergencial() external onlyDAOorOwner {
        _pause();
        _touch();
        _emitHubEvent(bytes32("PAUSED"), msg.sender, 0, "");
    }

    function unpause() external onlyDAOorOwner {
        _unpause();
        _touch();
        _emitHubEvent(bytes32("UNPAUSED"), msg.sender, 0, "");
    }

    /**
     * @notice Schedules reward-per-cycle update for the NEXT cycle only (never mid-cycle).
     */
    function setRewardPerCycle(uint256 programId, uint256 newRewardPerCycle) external onlyDAOorOwner {
        require(programs[programId].exists, "PROGRAM_NOT_FOUND");
        require(newRewardPerCycle > 0, "REWARD_0");
        Program storage p = programs[programId];

        uint256 old = p.rewardPerCycleCurrent;
        p.pendingRewardPerCycle = newRewardPerCycle;
        p.hasPendingRewardUpdate = true;

        emit RewardPerCycleUpdateScheduled(programId, old, newRewardPerCycle);
        _touch();
        _emitHubEvent(bytes32("REWARD_SCHEDULED"), msg.sender, newRewardPerCycle, abi.encode(programId, old, newRewardPerCycle));
    }

    function setProgramActive(uint256 programId, bool active) external onlyDAOorOwner {
        require(programs[programId].exists, "PROGRAM_NOT_FOUND");
        programs[programId].active = active;

        emit ProgramStatusUpdated(programId, active);
        _touch();
        _emitHubEvent(bytes32("PROGRAM_STATUS"), msg.sender, 0, abi.encode(programId, active));
    }

    /**
     * @notice Creates a new external program (MIMHO Labs-ready).
     */
    function createProgram(uint256 cycleDuration, uint256 rewardPerCycle_) external onlyDAOorOwner returns (uint256 programId) {
        require(cycleDuration >= 1 days && cycleDuration <= 365 days, "BAD_DURATION");
        require(rewardPerCycle_ > 0, "REWARD_0");

        programId = nextProgramId++;
        programs[programId] = Program({
            exists: true,
            active: true,
            startTimestamp: block.timestamp,
            cycleDuration: cycleDuration,
            rewardPerCycleCurrent: rewardPerCycle_,
            pendingRewardPerCycle: 0,
            hasPendingRewardUpdate: false,
            lastInitializedCycleId: 0
        });

        emit ProgramCreated(programId, msg.sender, block.timestamp, cycleDuration, rewardPerCycle_);
        _touch();
        _emitHubEvent(bytes32("PROGRAM_CREATED"), msg.sender, 0, abi.encode(programId, cycleDuration, rewardPerCycle_));
    }

    /* ============================================================
       Funding (deposit-only)
       ============================================================ */
    function fund(uint256 amount) external whenNotPaused nonReentrant {
        require(amount > 0, "AMOUNT_0");
        IERC20 token = mimhoToken();

        uint256 allow = token.allowance(msg.sender, address(this));
        require(allow >= amount, "ALLOWANCE_LOW");
        require(token.transferFrom(msg.sender, address(this), amount), "TRANSFER_FROM_FAIL");

        emit QuizFunded(msg.sender, amount);
        _touch();
        _emitHubEvent(bytes32("FUNDED"), msg.sender, amount, "");
    }

    /* ============================================================
       Cycle math & helpers
       ============================================================ */
    function currentCycleId(uint256 programId) public view returns (uint256) {
        Program storage p = programs[programId];
        require(p.exists, "PROGRAM_NOT_FOUND");
        if (block.timestamp < p.startTimestamp) return 0;
        return ((block.timestamp - p.startTimestamp) / p.cycleDuration) + 1; // starts at 1
    }

    function cycleEndTimestamp(uint256 programId, uint256 cycleId) public view returns (uint256) {
        Program storage p = programs[programId];
        require(p.exists, "PROGRAM_NOT_FOUND");
        require(cycleId > 0, "CYCLE_0");
        return p.startTimestamp + (cycleId * p.cycleDuration);
    }

    function timeUntilNextCycle(uint256 programId) external view returns (uint256) {
        uint256 c = currentCycleId(programId);
        if (c == 0) return 0;
        uint256 endTs = cycleEndTimestamp(programId, c);
        if (block.timestamp >= endTs) return 0;
        return endTs - block.timestamp;
    }

    function remainingPool() external view returns (uint256) {
        return mimhoToken().balanceOf(address(this));
    }

    function canReceiveReward(uint256 programId, address user) external view returns (bool) {
        Program storage p = programs[programId];
        if (!p.exists || !p.active) return false;
        if (failsafeTriggered || paused) return false;
        if (user == address(0)) return false;
        if (user.code.length != 0) return false;

        uint256 c = currentCycleId(programId);
        if (c == 0) return false;

        if (!completed[programId][c][user]) return false;
        if (claimed[programId][c][user]) return false;
        return true;
    }

    /* ============================================================
       Core flow (CEI enforced)
       ============================================================ */

    /**
     * @notice Marks the caller as completed for current cycle (off-chain quiz verification).
     * @dev CEI: all state updates happen before any external interaction (hub/certify).
     */
    function completeQuiz(uint256 programId) external whenNotPaused nonReentrant {
        require(!failsafeTriggered, "FAILSAFE_DONE");
        Program storage p = programs[programId];
        require(p.exists, "PROGRAM_NOT_FOUND");
        require(p.active, "PROGRAM_INACTIVE");

        require(msg.sender.code.length == 0, "NO_CONTRACTS");

        uint256 cId = currentCycleId(programId);
        require(cId > 0, "CYCLE_0");

        _ensureCycleInitialized(programId, cId);

        require(!completed[programId][cId][msg.sender], "ALREADY_COMPLETED");

        // -------------------------
        // EFFECTS (state first)
        // -------------------------
        completed[programId][cId][msg.sender] = true;
        cycles[programId][cId].participants += 1;

        totalQuizCompletions[msg.sender] += 1;
        if (_lastCycleParticipated[programId][msg.sender] != cId) {
            _lastCycleParticipated[programId][msg.sender] = cId;
            totalCyclesParticipated[msg.sender] += 1;
        }

        _touch();
        // -------------------------
        // INTERACTIONS / EVENTS
        // -------------------------
        emit QuizCompleted(programId, cId, msg.sender);
        _emitHubEvent(bytes32("QUIZ_COMPLETED"), msg.sender, 0, abi.encode(programId, cId));
        _bestEffortCertify(msg.sender, programId, cId);
    }

    /**
     * @notice Permissionless: closes a cycle after its end time, freezing rewardPerUser.
     * @dev CEI: set cd.closed/closedAt/rewardPerUser before any hub calls.
     */
    function closeCycle(uint256 programId, uint256 cycleId) external whenNotPaused nonReentrant {
        require(!failsafeTriggered, "FAILSAFE_DONE");
        Program storage p = programs[programId];
        require(p.exists, "PROGRAM_NOT_FOUND");

        require(cycleId > 0, "CYCLE_0");
        require(block.timestamp >= cycleEndTimestamp(programId, cycleId), "CYCLE_NOT_ENDED");

        _ensureCycleInitialized(programId, cycleId);

        CycleData storage cd = cycles[programId][cycleId];
        require(!cd.closed, "ALREADY_CLOSED");

        // -------------------------
        // EFFECTS (state first)
        // -------------------------
        cd.closed = true;
        cd.closedAt = block.timestamp;

        uint256 participants = cd.participants;
        uint256 perUser = 0;
        if (participants > 0) {
            perUser = cd.rewardPool / participants;
        }
        cd.rewardPerUser = perUser;

        _touch();
        // -------------------------
        // INTERACTIONS / EVENTS
        // -------------------------
        emit CycleClosed(programId, cycleId, participants, perUser);
        _emitHubEvent(bytes32("CYCLE_CLOSED"), msg.sender, perUser, abi.encode(programId, cycleId, participants, perUser));
    }

    /**
     * @notice Claims the reward for a closed cycle (max 1x per user per cycle).
     * @dev CEI: mark claimed + touch BEFORE token transfer or hub calls.
     */
    function claimReward(uint256 programId, uint256 cycleId) external whenNotPaused nonReentrant {
        require(!failsafeTriggered, "FAILSAFE_DONE");
        require(msg.sender.code.length == 0, "NO_CONTRACTS");
        require(cycleId > 0, "CYCLE_0");

        require(programs[programId].exists, "PROGRAM_NOT_FOUND");

        CycleData storage cd = cycles[programId][cycleId];
        require(cd.closed, "CYCLE_NOT_CLOSED");
        require(completed[programId][cycleId][msg.sender], "NOT_COMPLETED");
        require(!claimed[programId][cycleId][msg.sender], "ALREADY_CLAIMED");

        uint256 amount = cd.rewardPerUser;
        require(amount > 0, "NO_REWARD");

        IERC20 token = mimhoToken();
        require(token.balanceOf(address(this)) >= amount, "INSUFFICIENT_POOL");

        // -------------------------
        // EFFECTS (state first)
        // -------------------------
        claimed[programId][cycleId][msg.sender] = true;
        _touch();

        // -------------------------
        // INTERACTIONS / EVENTS
        // -------------------------
        require(token.transfer(msg.sender, amount), "TRANSFER_FAIL");

        emit RewardClaimed(programId, cycleId, msg.sender, amount);
        _emitHubEvent(bytes32("REWARD_CLAIMED"), msg.sender, amount, abi.encode(programId, cycleId));
    }

    /* ============================================================
       Differential #1: best-effort certify/badge
       ============================================================ */
    function _bestEffortCertify(address user, uint256 programId, uint256 cycleId) internal {
        address certifyAddr = registry.getContract(registry.KEY_MIMHO_CERTIFY());
        if (certifyAddr == address(0)) return;

        try IMIMHOCertify(certifyAddr).certify(
            contractType(),
            bytes32("QUIZ_BADGE"),
            user,
            cycleId,
            abi.encode(programId, cycleId, block.timestamp)
        ) {
            // best-effort
        } catch {
            // never break core logic
        }
    }

    /* ============================================================
       Cycle initialization (locks reward snapshot per cycle)
       ============================================================ */
    function _ensureCycleInitialized(uint256 programId, uint256 cycleId) internal {
        CycleData storage cd = cycles[programId][cycleId];
        if (cd.initialized) return;

        Program storage p = programs[programId];

        // Apply pending update only when initializing a new cycle (prevents mid-cycle changes)
        if (cycleId > p.lastInitializedCycleId) {
            if (p.hasPendingRewardUpdate) {
                p.rewardPerCycleCurrent = p.pendingRewardPerCycle;
                p.pendingRewardPerCycle = 0;
                p.hasPendingRewardUpdate = false;
            }
            p.lastInitializedCycleId = cycleId;
        }

        cd.initialized = true;
        cd.rewardPool = p.rewardPerCycleCurrent;

        emit CycleInitialized(programId, cycleId, cd.rewardPool);
        _emitHubEvent(bytes32("CYCLE_INITIALIZED"), msg.sender, cd.rewardPool, abi.encode(programId, cycleId, cd.rewardPool));
    }

    /* ============================================================
       Dead-man failsafe (no human withdraw)
       ============================================================ */
    function isFailsafeEligible() external view returns (bool) {
        if (failsafeTriggered) return false;
        return block.timestamp >= lastInteractionTimestamp + FAILSAFE_DELAY;
    }

    function timeUntilFailsafe() external view returns (uint256) {
        if (failsafeTriggered) return 0;
        uint256 due = lastInteractionTimestamp + FAILSAFE_DELAY;
        if (block.timestamp >= due) return 0;
        return due - block.timestamp;
    }

    /**
     * @notice Anyone can trigger failsafe after extreme inactivity.
     * @dev Sends remaining tokens to DAO treasury wallet:
     *      - preferred: KEY_MIMHO_DAO_WALLET
     *      - fallback : KEY_MIMHO_DAO (if wallet key unset)
     */
    function triggerFailsafe() external nonReentrant {
        require(!failsafeTriggered, "FAILSAFE_DONE");
        require(block.timestamp >= lastInteractionTimestamp + FAILSAFE_DELAY, "NOT_ELIGIBLE");

        address daoWallet = daoTreasury();
        require(daoWallet != address(0), "DAO_TREASURY_NOT_SET");

        IERC20 token = mimhoToken();
        uint256 bal = token.balanceOf(address(this));

        // Effects first
        failsafeTriggered = true;
        // Touch before transfer (CEI-friendly)
        _touch();

        if (bal > 0) {
            require(token.transfer(daoWallet, bal), "TRANSFER_FAIL");
        }

        emit FailsafeTriggered(block.timestamp, bal, daoWallet);
        _emitHubEvent(bytes32("FAILSAFE"), msg.sender, bal, abi.encode(daoWallet));
    }

    /* ============================================================
       Internal utilities
       ============================================================ */
    function _touch() internal {
        lastInteractionTimestamp = block.timestamp;
    }

    /* ============================================================
       ETH handling (not used)
       ============================================================ */
    receive() external payable { revert("NO_ETH"); }
    fallback() external payable { revert("NO_FALLBACK"); }

    /// @dev Resgata BNB preso acidentalmente no contrato.
    function rescueNative() external onlyDAOorOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "MIMHO: balance is zero");
        (bool success, ) = payable(msg.sender).call{value: balance}("");
        require(success, "MIMHO: rescue failed");
    }
}
>>>>>>> fe7ced1 (Add official deployed MIMHO contracts with BscScan headers)
