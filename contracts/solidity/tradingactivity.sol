<<<<<<< HEAD
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

abstract contract MIMHO Trading Activity {
    string public constant version = "0.0.0-placeholder";
    function contractType() public pure virtual returns (bytes32) { return keccak256("MIMHO_TRADING_ACTIVITY"); }
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
abstract contract MIMHO Trading Activity {
    /// @notice Human readable version for repository tracking (not on-chain guarantee).
    string public constant version = "0.0.0-placeholder";

    /// @notice Contract module type identifier (used by HUD/Events Hub in final builds).
    function contractType() public pure virtual returns (bytes32) {
        return CONTRACT_TYPE;
    }
}
=======
/// -----------------------------------------------------------------------
/// MIMHO TRADING ACTIVITY
/// Official MIMHO Ecosystem Contract
///
/// Network: BNB Smart Chain
/// Contract Address:
/// 0x92Da083378C9cE5373ba081444A46f4808437259
///
/// BscScan:
/// https://bscscan.com/address/0x92Da083378C9cE5373ba081444A46f4808437259
/// -----------------------------------------------------------------------

// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/* ============================================================
   MIMHO TRADING ACTIVITY — v1.0.1
   ============================================================

   DESIGN PHILOSOPHY (MIMHO ABSOLUTE STANDARD)

   - Observe, Never Influence:
     This module observes public on-chain trading activity and never
     executes swaps, moves funds, or affects price/liquidity.

   - Radical Transparency:
     All lifecycle transitions and public snapshots are emitted to the
     MIMHO Events Hub (HUD loudspeaker). Anyone can reconstruct results.

   - No Human Intervention Once Announced:
     After a cycle is announced, parameters cannot be changed and the
     cycle timeline is deterministic:
       * 72h pre-announcement window (ANNOUNCED)
       * 14 days active competition (ACTIVE)
       * automatic end (FINALIZED by anyone calling finalize)

   - Anti-Abuse by Objective Rules (No Censorship):
     Trades are never blocked. They may be ignored for scoring if they
     match objective invalid/suspicious patterns (e.g., same-block spam,
     too-fast sequences, circular toggles).

   - Gas-Sane & HUD-Friendly:
     No global sorting on-chain. The contract computes per-wallet scores.
     The HUD can build rankings off-chain and request on-chain broadcast
     via snapshot emissions (purely informational).

   - Registry-Coupled & Ecosystem-Only Ingestion:
     All dependencies are resolved via MIMHORegistry keys (no local strings).
     Whitelisted ecosystem contracts can report trades, and (pre-DAO) the
     Owner (or an authorized bot wallet) can also report for operational
     flexibility.

   ============================================================ */

interface IMIMHORegistry {
    function getContract(bytes32 key) external view returns (address);
    function isEcosystemContract(address a) external view returns (bool);

    // IMPORTANT: must be view (not pure) to match real Registry behavior
    function KEY_MIMHO_EVENTS_HUB() external view returns (bytes32);
    function KEY_MIMHO_DAO() external view returns (bytes32);
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
 * @dev Minimal Ownable2Step-like pattern (lightweight, no external deps).
 * If you already standardize OZ Ownable2Step across your repo, you can swap
 * this with OpenZeppelin imports.
 */
abstract contract Ownable2StepLite {
    address private _owner;
    address private _pendingOwner;

    event OwnershipTransferStarted(address indexed  previousOwner, address indexed  newOwner);
    event OwnershipTransferred(address indexed  previousOwner, address indexed  newOwner);

    constructor() {
        _owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    modifier onlyOwner() {
        require(msg.sender == _owner, "NOT_OWNER");
        _;
    }

    function owner() public view returns (address) { return _owner; }
    function pendingOwner() public view returns (address) { return _pendingOwner; }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "ZERO_OWNER");
        _pendingOwner = newOwner;
        emit OwnershipTransferStarted(_owner, newOwner);
    }

    function acceptOwnership() external {
        require(msg.sender == _pendingOwner, "NOT_PENDING_OWNER");
        address prev = _owner;
        _owner = _pendingOwner;
        _pendingOwner = address(0);
        emit OwnershipTransferred(prev, _owner);
    }
}

contract MIMHOTradingActivity is Ownable2StepLite {
    /* =========================
       icontratoMimho
       ========================= */

    /* ============
       Constants
       ============ */

    string public constant name = "MIMHO Trading Activity";
    string public constant version = "1.0.1";

    // Fixed timing (as approved)
    uint256 public constant ANNOUNCE_DELAY = 72 hours;
    uint256 public constant ACTIVE_DURATION = 14 days;

    // HUD snapshot throttling (gamification)
    uint256 public constant MIN_SNAPSHOT_INTERVAL = 4 hours;

    // Contract type for Events Hub module field
    bytes32 private constant _CONTRACT_TYPE = bytes32("MIMHO_TRADING_ACTIVITY");

    function contractType() public pure returns (bytes32) {
        return _CONTRACT_TYPE;
    }

    /* ============
       Registry
       ============ */

    IMIMHORegistry public registry;

    /* ============
       DAO takeover
       ============ */

    address public DAO_CONTRACT;
    bool public daoActivated;

    modifier onlyDAOorOwner() {
        if (daoActivated) {
            require(msg.sender == DAO_CONTRACT, "NOT_DAO");
        } else {
            require(msg.sender == owner(), "NOT_OWNER_PRE_DAO");
        }
        _;
    }

    event SetDAO(address indexed  dao);
    event ActivateDAO(address indexed  dao);

    function setDAO(address daoAddr) external onlyOwner {
        require(!daoActivated, "DAO_ALREADY_ACTIVE");
        require(daoAddr != address(0), "ZERO_DAO");
        DAO_CONTRACT = daoAddr;

        _emitHubEvent(bytes32("SET_DAO"), msg.sender, uint256(uint160(daoAddr)), "");
        emit SetDAO(daoAddr);
    }

    function activateDAO() external onlyOwner {
        require(!daoActivated, "DAO_ALREADY_ACTIVE");

        address daoAddr = registry.getContract(registry.KEY_MIMHO_DAO());
        require(daoAddr != address(0), "REGISTRY_DAO_NOT_SET");

        DAO_CONTRACT = daoAddr;
        daoActivated = true;

        _emitHubEvent(bytes32("ACTIVATE_DAO"), msg.sender, uint256(uint160(daoAddr)), "");
        emit ActivateDAO(daoAddr);
    }

    /* ============
       Pause (restricted)
       ============ */

    bool public paused;

    modifier whenNotPaused() {
        require(!paused, "PAUSED");
        _;
    }

    event Paused(address indexed  by);
    event Unpaused(address indexed  by);

    function pauseEmergencial() external onlyDAOorOwner {
        // Absolute rule: no intervention during ACTIVE
        require(state() != CycleState.ACTIVE, "CANNOT_PAUSE_ACTIVE");
        paused = true;

        _emitHubEvent(bytes32("PAUSE"), msg.sender, 1, "");
        emit Paused(msg.sender);
    }

    function unpause() external onlyDAOorOwner {
        paused = false;

        _emitHubEvent(bytes32("UNPAUSE"), msg.sender, 0, "");
        emit Unpaused(msg.sender);
    }

    /* =========================
       Trading Activity Cycles
       ========================= */

    enum CycleState { IDLE, ANNOUNCED, ACTIVE, ENDED, FINALIZED }

    struct CycleConfig {
        uint256 minTradeValueBNB;      // e.g., 0.05 BNB = 5e16
        uint256 minIntervalSec;        // e.g., 180 seconds
        uint256 circularWindowSec;     // e.g., 120 seconds
        uint256 circularBpsTolerance;  // e.g., 1000 = 10%
        uint256 maxSnapshotBatch;      // e.g., 100 (<= 250)
    }

    struct CycleMeta {
        uint256 cycleId;

        uint256 announcedAt; // when announced (starts 72h delay)
        uint256 startsAt;    // announcedAt + 72h
        uint256 endsAt;      // startsAt + 14d

        uint256 finalizedAt;

        bool finalized;
        bool startedEmitted; // one-shot guard for emitStarted()

        // snapshot pacing
        uint256 lastSnapshotAt;
        uint256 snapshotCount;

        CycleConfig cfg;
    }

    CycleMeta public current;

    /// @notice Test/UX helper: returns the full current cycle meta as a struct.
    /// @dev Public struct getters return tuples; this returns the actual struct.
    function getCurrent() external view returns (CycleMeta memory) {
        return current;
    }

    // Per-cycle scoring maps
    mapping(uint256 => mapping(address => uint256)) public score;           // computed score (qualified volume)
    mapping(uint256 => mapping(address => uint256)) public volumeBNB;       // qualified volume
    mapping(uint256 => mapping(address => uint256)) public tradeCount;      // qualified trades
    mapping(uint256 => mapping(address => uint256)) public lastValidTradeTs;
    mapping(uint256 => mapping(address => uint256)) public lastTradeBlock;
    mapping(uint256 => mapping(address => bool))    public lastSideIsBuy;
    mapping(uint256 => mapping(address => uint256)) public lastTradeValueBNB;

    event RegistryUpdated(address indexed  oldRegistry, address indexed  newRegistry);

    event TradingAnnounced(uint256 indexed cycleId, uint256 announcedAt, uint256 startsAt, uint256 endsAt);
    event TradingStarted(uint256 indexed cycleId, uint256 startsAt, uint256 endsAt);
    event TradingFinalized(uint256 indexed cycleId, uint256 finalizedAt);

    event TradeRecorded(
        uint256 indexed cycleId,
        address indexed reporter,
        address indexed trader,
        uint256 amountBNB,
        bool isBuy,
        bool counted,
        uint256 newScore
    );

    event SnapshotEmitted(uint256 indexed cycleId, uint256 indexed snapshotId, uint256 timestamp, uint256 batchSize);
    event ParticipantScore(uint256 indexed cycleId, address indexed  participant, uint256 score, uint256 volumeBNB, uint256 trades);

    /* ============
       Hub Emission (ABSOLUTE RULE)
       ============ */

    function _emitHubEvent(bytes32 action, address caller, uint256 value, bytes memory data) internal {
        address hubAddr = registry.getContract(registry.KEY_MIMHO_EVENTS_HUB());
        if (hubAddr == address(0)) return;

        // Best-effort: NEVER break main logic if hub fails
        try IMIMHOEventsHub(hubAddr).emitEvent(contractType(), action, caller, value, data) {
            // ok
        } catch {
            // swallow
        }
    }

    /* ============
       Modifiers
       ============ */

    modifier onlyEcosystemReporter() {
        require(
            registry.isEcosystemContract(msg.sender) ||
            msg.sender == owner() || // Owner (or authorized bot wallet) can report
            msg.sender == address(registry),
            "NOT_ECOSYSTEM_REPORTER"
        );
        _;
    }

    /* ============
       Constructor
       ============ */

    constructor(address registryAddr) {
        require(registryAddr != address(0), "ZERO_REGISTRY");
        registry = IMIMHORegistry(registryAddr);

        _emitHubEvent(bytes32("DEPLOY"), msg.sender, 0, abi.encode(registryAddr, version));
    }

    /* ============
       Admin (only when safe)
       ============ */

    function setRegistry(address newRegistry) external onlyDAOorOwner {
        require(newRegistry != address(0), "ZERO_REGISTRY");
        // Only allow changing registry when not in ACTIVE
        require(state() != CycleState.ACTIVE, "CANNOT_SET_REGISTRY_ACTIVE");

        address old = address(registry);
        registry = IMIMHORegistry(newRegistry);

        _emitHubEvent(bytes32("SET_REGISTRY"), msg.sender, uint256(uint160(newRegistry)), abi.encode(old, newRegistry));
        emit RegistryUpdated(old, newRegistry);
    }

    /* ============
       State helpers
       ============ */

    function state() public view returns (CycleState) {
        if (current.cycleId == 0) return CycleState.IDLE;
        if (current.finalized) return CycleState.FINALIZED;

        if (block.timestamp < current.startsAt) return CycleState.ANNOUNCED;

        if (block.timestamp >= current.startsAt && block.timestamp < current.endsAt) return CycleState.ACTIVE;

        return CycleState.ENDED;
    }

    function timeToStart() external view returns (uint256) {
        if (current.cycleId == 0) return 0;
        if (block.timestamp >= current.startsAt) return 0;
        return current.startsAt - block.timestamp;
    }

    function timeToEnd() external view returns (uint256) {
        if (current.cycleId == 0) return 0;
        if (block.timestamp >= current.endsAt) return 0;
        return current.endsAt - block.timestamp;
    }

    /* =========================
       Cycle Management
       ========================= */

    /**
     * @notice Announces a new trading activity cycle.
     * @dev After this call, no one can modify parameters. Timeline is deterministic.
     *      The cycle starts automatically after 72h and lasts 14 days.
     */
    function announceCycle(CycleConfig calldata cfg) external onlyDAOorOwner whenNotPaused {
        if (current.cycleId != 0) {
            require(current.finalized, "PREVIOUS_NOT_FINALIZED");
        }

        // Sanity checks
        require(cfg.minTradeValueBNB > 0, "MIN_TRADE_ZERO");
        require(cfg.maxSnapshotBatch > 0 && cfg.maxSnapshotBatch <= 250, "BAD_BATCH");
        require(cfg.circularBpsTolerance <= 5_000, "TOL_TOO_HIGH"); // <= 50%

        uint256 newId = current.cycleId + 1;

        uint256 announcedAt = block.timestamp;
        uint256 startsAt = announcedAt + ANNOUNCE_DELAY;
        uint256 endsAt = startsAt + ACTIVE_DURATION;

        current = CycleMeta({
            cycleId: newId,
            announcedAt: announcedAt,
            startsAt: startsAt,
            endsAt: endsAt,
            finalizedAt: 0,
            finalized: false,
            startedEmitted: false,
            lastSnapshotAt: 0,
            snapshotCount: 0,
            cfg: cfg
        });

        _emitHubEvent(bytes32("TRADING_ANNOUNCED"), msg.sender, newId, abi.encode(announcedAt, startsAt, endsAt, cfg));
        emit TradingAnnounced(newId, announcedAt, startsAt, endsAt);
    }

    /**
     * @notice Emits a "started" signal (optional). The state becomes ACTIVE purely by time.
     * @dev Anyone can call once the ACTIVE window begins, for HUD convenience.
     */
    function emitStarted() external whenNotPaused {
        require(state() == CycleState.ACTIVE, "NOT_ACTIVE");
        // Emit only once per cycle using snapshot counters as a guard.
        require(!current.startedEmitted, "ALREADY_SIGNALED");
        current.startedEmitted = true;
_emitHubEvent(bytes32("TRADING_STARTED"), msg.sender, current.cycleId, abi.encode(current.startsAt, current.endsAt));
        emit TradingStarted(current.cycleId, current.startsAt, current.endsAt);
    }

    /**
     * @notice Finalizes the cycle after it ends. Anyone can call.
     */
    function finalize() external whenNotPaused {
        require(state() == CycleState.ENDED, "NOT_ENDED");
        current.finalized = true;
        current.finalizedAt = block.timestamp;

        _emitHubEvent(bytes32("TRADING_FINALIZED"), msg.sender, current.cycleId, abi.encode(current.finalizedAt));
        emit TradingFinalized(current.cycleId, current.finalizedAt);
    }

    /* =========================
       Trade Reporting (Ingestion)
       ========================= */

    /**
     * @notice Reports a trade for scoring.
     * @dev Must be called by a whitelisted ecosystem contract OR by the owner/bot wallet.
     *      The reporter is responsible for computing/providing amountBNB notional.
     *
     * @param trader The end-user wallet address.
     * @param amountBNB The trade notional in BNB (wei).
     * @param isBuy True if MIMHO was bought (BNB -> MIMHO), false if sold.
     */
    function reportTrade(
        address trader,
        uint256 amountBNB,
        bool isBuy
    ) external onlyEcosystemReporter whenNotPaused {
        require(trader != address(0), "ZERO_TRADER");
        require(state() == CycleState.ACTIVE, "NOT_ACTIVE");

        uint256 id = current.cycleId;

        bool counted = _shouldCountTrade(id, trader, amountBNB, isBuy);
        uint256 newScore = score[id][trader];

        if (counted) {
            volumeBNB[id][trader] += amountBNB;
            tradeCount[id][trader] += 1;

            // Score function (V1): qualified volume in BNB (simple, transparent)
            newScore = newScore + amountBNB;
            score[id][trader] = newScore;

            lastValidTradeTs[id][trader] = block.timestamp;
        }

        // Always update anti-abuse trackers (even if ignored)
        lastTradeBlock[id][trader] = block.number;
        lastSideIsBuy[id][trader] = isBuy;
        lastTradeValueBNB[id][trader] = amountBNB;

        _emitHubEvent(
            bytes32("TRADE_RECORDED"),
            msg.sender,
            id,
            abi.encode(trader, amountBNB, isBuy, counted, newScore)
        );

        emit TradeRecorded(id, msg.sender, trader, amountBNB, isBuy, counted, newScore);
    }

    function _shouldCountTrade(
        uint256 id,
        address trader,
        uint256 amountBNB,
        bool isBuy
    ) internal view returns (bool) {
        CycleConfig memory cfg = current.cfg;

        // Minimum value
        if (amountBNB < cfg.minTradeValueBNB) return false;

        // Same-block spam
        if (lastTradeBlock[id][trader] == block.number && lastValidTradeTs[id][trader] == block.timestamp) return false;

        // Minimum interval between *counted* trades
        uint256 lastTs = lastValidTradeTs[id][trader];
        if (lastTs != 0 && (block.timestamp - lastTs) < cfg.minIntervalSec) return false;

        // Objective circular toggle heuristic:
        // If side toggles quickly and size is within tolerance window, ignore (typical wash loop).
        bool lastSide = lastSideIsBuy[id][trader];
        uint256 lastVal = lastTradeValueBNB[id][trader];

        if (lastVal != 0 && lastSide != isBuy) {
            // Use "now - lastTs" as a conservative window; if lastTs==0, skip this heuristic.
            if (lastTs != 0 && (block.timestamp - lastTs) <= cfg.circularWindowSec) {
                uint256 diff = (amountBNB > lastVal) ? (amountBNB - lastVal) : (lastVal - amountBNB);
                uint256 bps = (diff * 10_000) / lastVal;
                if (bps <= cfg.circularBpsTolerance) return false;
            }
        }

        return true;
    }

    /* =========================
       Snapshots & HUD Broadcast
       ========================= */

    /**
     * @notice Emits a snapshot marker + per-participant score events for HUD.
     * @dev Any address can call, rate-limited during ACTIVE, and bounded by batch size.
     */
    function emitSnapshot(address[] calldata participants) external whenNotPaused {
        CycleState st = state();
        require(st == CycleState.ACTIVE || st == CycleState.ENDED || st == CycleState.FINALIZED, "BAD_STATE");

        uint256 id = current.cycleId;
        require(id != 0, "NO_CYCLE");

        uint256 nowTs = block.timestamp;

        // Rate-limit snapshots during ACTIVE window
        if (st == CycleState.ACTIVE) {
            if (current.lastSnapshotAt != 0) {
                require(nowTs - current.lastSnapshotAt >= MIN_SNAPSHOT_INTERVAL, "SNAPSHOT_TOO_SOON");
            }
        }

        require(participants.length > 0 && participants.length <= current.cfg.maxSnapshotBatch, "BAD_PARTICIPANTS_LEN");

        current.snapshotCount += 1;
        current.lastSnapshotAt = nowTs;

        uint256 snapId = current.snapshotCount;

        _emitHubEvent(bytes32("SNAPSHOT"), msg.sender, id, abi.encode(snapId, nowTs, participants.length));
        emit SnapshotEmitted(id, snapId, nowTs, participants.length);

        // Broadcast participant scores (HUD sorts off-chain)
        for (uint256 i = 0; i < participants.length; i++) {
            address p = participants[i];
            emit ParticipantScore(id, p, score[id][p], volumeBNB[id][p], tradeCount[id][p]);
        }
    }

    /* =========================
       View Helpers (HUD-ready)
       ========================= */

    function getParticipant(uint256 cycleId, address p)
        external
        view
        returns (
            uint256 _score,
            uint256 _volumeBNB,
            uint256 _trades,
            uint256 _lastValidTradeTs,
            uint256 _lastTradeBlock
        )
    {
        _score = score[cycleId][p];
        _volumeBNB = volumeBNB[cycleId][p];
        _trades = tradeCount[cycleId][p];
        _lastValidTradeTs = lastValidTradeTs[cycleId][p];
        _lastTradeBlock = lastTradeBlock[cycleId][p];
    }

    function getCurrentConfig() external view returns (CycleConfig memory) {
        return current.cfg;
    }

    /* =========================
       Safety: Recover tokens
       ========================= */

    function recoverTokens(address token, address to, uint256 amount) external onlyDAOorOwner {
        // ✅ CORREÇÃO SLITHER: Zero check em todos os parâmetros de endereço
        require(token != address(0), "MIMHO: token=0");
        require(to != address(0), "MIMHO: to=0");
        
        require(state() != CycleState.ACTIVE, "CANNOT_RECOVER_ACTIVE");

        // Realiza a chamada de transferência
        (bool ok, bytes memory data) = token.call(abi.encodeWithSignature("transfer(address,uint256)", to, amount));
        require(ok && (data.length == 0 || abi.decode(data, (bool))), "TRANSFER_FAIL");

        _emitHubEvent(bytes32("RECOVER_TOKENS"), msg.sender, amount, abi.encode(token, to, amount));
    }

    receive() external payable {
        _emitHubEvent(bytes32("RECEIVE"), msg.sender, msg.value, "");
    }

    fallback() external payable {
        _emitHubEvent(bytes32("FALLBACK"), msg.sender, msg.value, msg.data);
    }

    /// @dev Resgata BNB preso acidentalmente no contrato.
    function rescueNative() external onlyDAOorOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "MIMHO: balance is zero");
        (bool success, ) = payable(msg.sender).call{value: balance}("");
        require(success, "MIMHO: rescue failed");
    }
}
>>>>>>> fe7ced1 (Add official deployed MIMHO contracts with BscScan headers)
