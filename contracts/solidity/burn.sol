<<<<<<< HEAD
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

abstract contract MIMHO Burn {
    string public constant version = "0.0.0-placeholder";
    function contractType() public pure virtual returns (bytes32) { return keccak256("MIMHO_BURN"); }
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
abstract contract MIMHO Burn {
    /// @notice Human readable version for repository tracking (not on-chain guarantee).
    string public constant version = "0.0.0-placeholder";

    /// @notice Contract module type identifier (used by HUD/Events Hub in final builds).
    function contractType() public pure virtual returns (bytes32) {
        return CONTRACT_TYPE;
    }
}
=======
/// -----------------------------------------------------------------------
/// MIMHO BURN GOVERNANCE VAULT
/// Official MIMHO Ecosystem Contract
///
/// Network: BNB Smart Chain
/// Contract Address:
/// 0xFb75bC0A920635b810eD3842a1164Ca10CA6E7eD
///
/// BscScan:
/// https://bscscan.com/address/0xFb75bC0A920635b810eD3842a1164Ca10CA6E7eD
/// -----------------------------------------------------------------------

// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/* ============================================================
   MIMHO BURN GOVERNANCE VAULT — v1.1.2 (Slither CEI “Ninja”)
   ============================================================

   DESIGN PHILOSOPHY (MIMHO ABSOLUTE STANDARD)
   - Token stays SIMPLE: complex burn/distribution lives here, not in the token.
   - No holder iteration (no on-chain loops over holder lists).
   - Pull-over-push: eligible users must claim; nothing is auto-sent.
   - Fail-safe default: if quorum not met -> BURN.
   - Supply floor respected: burn disabled at/under floor and redirected safely.
   - Radical transparency: events + EventsHub best-effort emission (try/catch).
   - Registry-first: resolve dependencies via Registry KEY getters (no local keccak strings).
   - Voting WITHOUT IVotes: stake-to-vote (Voting Power Vault).
     Users deposit MIMHO here to get voting power, and voting locks withdrawals until vote end.

   SLITHER CEI “NINJA” RULE (applied)
   - In functions that transfer tokens and/or call EventsHub:
     * ALL state updates happen immediately after require checks (effects)
     * ALL external calls (token transfers, registry-dependent calls, hub emission) happen at the end
     * Hub emission is the LAST LINE (best-effort)
   - _executeBurnOrRedirect no longer emits hub events internally (caller emits hub last).
   ============================================================ */

import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IMIMHORegistry {
    function getContract(bytes32 key) external view returns (address);
    function isEcosystemContract(address a) external view returns (bool);

    function KEY_MIMHO_TOKEN() external view returns (bytes32);
    function KEY_MIMHO_EVENTS_HUB() external view returns (bytes32);
    function KEY_MIMHO_STAKING() external view returns (bytes32);
    function KEY_MIMHO_CERTIFY() external view returns (bytes32);
    function KEY_MIMHO_MART() external view returns (bytes32);
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

interface IMIMHOCertify {
    function recordBurn(
        address burner,
        uint256 amount,
        uint256 timestamp,
        bytes32 contextHash,
        bytes calldata data
    ) external;
}

interface IMIMHOMart {
    function mintBurnBadge(
        address to,
        uint256 amount,
        uint256 timestamp,
        bytes32 contextHash,
        string calldata reason
    ) external returns (uint256 tokenId);
}

contract MIMHOBurnGovernanceVault is ReentrancyGuard, Pausable {
    /* ============================================================
                                VERSION
       ============================================================ */
    string public constant version = "1.1.2";

    /* ============================================================
                               OWNERSHIP / DAO
       ============================================================ */
    address public owner;
    address public pendingOwner;

    address public daoContract; // camelCase
    bool public daoActivated;

    modifier onlyOwner() {
        require(msg.sender == owner, "NOT_OWNER");
        _;
    }

    modifier onlyDAOorOwner() {
        require(msg.sender == owner || (daoActivated && msg.sender == daoContract), "NOT_DAO_OR_OWNER");
        _;
    }

    event OwnershipTransferStarted(address indexed  previousOwner, address indexed  newOwner);
    event OwnershipTransferred(address indexed  previousOwner, address indexed  newOwner);

    event DAOSet(address indexed  dao);
    event DAOActivated(address indexed  dao);

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "ZERO_OWNER");
        pendingOwner = newOwner;
        emit OwnershipTransferStarted(owner, newOwner);
    }

    function acceptOwnership() external {
        require(msg.sender == pendingOwner, "NOT_PENDING_OWNER");
        address prev = owner;
        owner = pendingOwner;
        pendingOwner = address(0);
        emit OwnershipTransferred(prev, owner);
    }

    function setDAO(address dao) external onlyOwner {
        require(dao != address(0), "ZERO_DAO");
        daoContract = dao;
        emit DAOSet(dao);
    }

    function activateDAO() external onlyOwner {
        require(daoContract != address(0), "DAO_NOT_SET");
        require(!daoActivated, "DAO_ALREADY_ACTIVE");
        daoActivated = true;
        emit DAOActivated(daoContract);
    }

    // Legacy getter for older integrations
    function DAO_CONTRACT() external view returns (address) {
        return daoContract;
    }

    /* ============================================================
                               REGISTRY
       ============================================================ */
    IMIMHORegistry public immutable registry;

    /* ============================================================
                              EVENTS HUB (HUD)
       ============================================================ */
    function contractType() public pure returns (bytes32) {
        return bytes32("MIMHO_BURN");
    }

    bytes32 public constant ACTION_DEPOSIT = keccak256("DEPOSIT_FOR_BURN");
    bytes32 public constant ACTION_CYCLE_OPEN = keccak256("CYCLE_OPENED");
    bytes32 public constant ACTION_VOTE = keccak256("VOTED");
    bytes32 public constant ACTION_FINALIZE = keccak256("CYCLE_FINALIZED");
    bytes32 public constant ACTION_CLAIM = keccak256("CLAIMED");
    bytes32 public constant ACTION_EXPIRE = keccak256("EXPIRED_AND_BURNED");
    bytes32 public constant ACTION_VOL_BURN = keccak256("VOLUNTARY_BURN");
    bytes32 public constant ACTION_REDIRECT = keccak256("REDIRECTED");
    bytes32 public constant ACTION_PAUSE = keccak256("PAUSED");
    bytes32 public constant ACTION_UNPAUSE = keccak256("UNPAUSED");
    bytes32 public constant ACTION_VP_DEPOSIT = keccak256("VOTING_POWER_DEPOSIT");
    bytes32 public constant ACTION_VP_WITHDRAW = keccak256("VOTING_POWER_WITHDRAW");

    function _emitHubEvent(bytes32 action, address caller, uint256 value, bytes memory data) internal {
        address hubAddr = registry.getContract(registry.KEY_MIMHO_EVENTS_HUB());
        if (hubAddr == address(0)) return;
        try IMIMHOEventsHub(hubAddr).emitEvent(contractType(), action, caller, value, data) {
            // best-effort
        } catch {
            // never break main logic
        }
    }

    /* ============================================================
                             TOKEN HELPERS
       ============================================================ */
    function mimhoToken() public view returns (address) {
        return registry.getContract(registry.KEY_MIMHO_TOKEN());
    }

    function _token() internal view returns (IERC20) {
        return IERC20(mimhoToken());
    }

    /* ============================================================
                             CONFIGURATION
       ============================================================ */
    uint256 public cycleTriggerAmount; // default: 500,000,000 MIMHO
    uint256 public voteDuration;       // default: 3 days
    uint256 public claimDuration;      // default: 7 days
    uint256 public minHoldAge;         // default: 30 days
    uint16 public quorumBps;           // default: 5% of VP snapshot
    uint16 public claimCapBps;         // default: 0.50%

    uint256 public constant SUPPLY_FLOOR = 500_000_000_000 * 1e18;

    mapping(address => bool) public blockedWallet;

    event ConfigUpdated(
        uint256 cycleTriggerAmount,
        uint256 voteDuration,
        uint256 claimDuration,
        uint256 minHoldAge,
        uint16 quorumBps,
        uint16 claimCapBps
    );
    event BlockedWalletSet(address indexed  wallet, bool blocked);

    /* ============================================================
                                ELIGIBILITY
       ============================================================ */
    mapping(address => uint256) public firstSeenAt;
    event Registered(address indexed  user, uint256 timestamp);

    function register() external whenNotPaused {
        if (firstSeenAt[msg.sender] == 0) {
            firstSeenAt[msg.sender] = block.timestamp;
            emit Registered(msg.sender, block.timestamp);
        }
    }

    function _isBlocked(address a) internal view returns (bool) {
        if (a == address(0)) return true;
        if (blockedWallet[a]) return true;
        if (registry.isEcosystemContract(a)) return true;
        return false;
    }

    function _isEligibleAddress(address a) internal view returns (bool) {
        if (_isBlocked(a)) return false;
        uint256 seen = firstSeenAt[a];
        if (seen == 0) return false;
        if (block.timestamp < seen + minHoldAge) return false;
        return true;
    }

    /* ============================================================
                          VOTING POWER VAULT
       ============================================================ */
    mapping(address => uint256) public votingPowerStaked;
    uint256 public totalVotingPowerStaked;

    mapping(address => uint256) public lockedUntil;

    event VotingPowerDeposited(address indexed  user, uint256 amount, uint256 newBalance, uint256 newTotal);
    event VotingPowerWithdrawn(address indexed  user, uint256 amount, uint256 newBalance, uint256 newTotal);
    event VotingPowerLocked(address indexed  user, uint256 untilTimestamp, uint256 cycleId);

    // Non-withdrawable pools
    uint256 public burnReserve;
    uint256 public reservedForCycles;

    /* ============================================================
                                 CYCLES
       ============================================================ */
    enum CycleState {
        NONE,
        VOTING,
        CLAIMING,
        BURNED,
        DISTRIBUTED
    }

    struct Cycle {
        CycleState state;
        uint256 amount;
        uint256 startTime;
        uint256 voteEndTime;
        uint256 claimEndTime;
        uint256 totalYes;
        uint256 totalNo;
        uint256 vpSnapshot;
        uint256 quorumTarget;
        uint256 totalClaimed;
        uint256 totalCappedBurned;
        bool finalized;
        bool distribute;
    }

    uint256 public cycleCount;
    uint256 public activeCycleId;

    mapping(uint256 => Cycle) public cycles;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    mapping(uint256 => mapping(address => bool)) public votedYes;
    mapping(uint256 => mapping(address => bool)) public hasClaimed;

    event Deposit(address indexed  from, uint256 amount, string source);

    event CycleOpened(
        uint256 indexed cycleId,
        uint256 amount,
        uint256 startTime,
        uint256 voteEndTime,
        uint256 vpSnapshot,
        uint256 quorumTarget
    );

    event Voted(uint256 indexed cycleId, address indexed  voter, bool distribute, uint256 weight);

    event CycleFinalized(uint256 indexed cycleId, bool distribute, uint256 totalYes, uint256 totalNo, bool quorumMet);

    event DistributionClaimed(
        uint256 indexed cycleId,
        address indexed holder,
        uint256 paidAmount,
        uint256 rawAmount,
        uint256 cappedAmount
    );

    event CycleClosed(
        uint256 indexed cycleId,
        uint256 totalDistributed,
        uint256 totalBurned,
        uint256 burnedRemainder,
        uint256 burnedCappedPortion,
        bytes32 contextHash
    );

    /* ============================================================
                         BURN EXEC RESULT (NO HUB INSIDE)
       ============================================================ */
    enum BurnRoute {
        BURN,
        STAKING
    }

    event BurnExecuted(address indexed  caller, uint256 amount, address indexed  burnSink, bytes32 contextHash, string reason);
    event Redirected(address indexed  caller, uint256 amount, address indexed  destination, bytes32 contextHash, string reason);

    /* ============================================================
                               CONSTRUCTOR
       ============================================================ */
    constructor(address registryAddress) {
        require(registryAddress != address(0), "ZERO_REGISTRY");
        registry = IMIMHORegistry(registryAddress);
        owner = msg.sender;

        cycleTriggerAmount = 500_000_000 * 1e18;
        voteDuration = 3 days;
        claimDuration = 7 days;
        minHoldAge = 30 days;
        quorumBps = 500;
        claimCapBps = 50;

        emit ConfigUpdated(cycleTriggerAmount, voteDuration, claimDuration, minHoldAge, quorumBps, claimCapBps);
    }

    /* ============================================================
                                ADMIN
       ============================================================ */
    function setConfig(
        uint256 _cycleTriggerAmount,
        uint256 _voteDuration,
        uint256 _claimDuration,
        uint256 _minHoldAge,
        uint16 _quorumBps,
        uint16 _claimCapBps
    ) external onlyDAOorOwner {
        require(_cycleTriggerAmount > 0, "BAD_TRIGGER");
        require(_voteDuration >= 1 hours && _voteDuration <= 30 days, "BAD_VOTE_DUR");
        require(_claimDuration >= 1 days && _claimDuration <= 30 days, "BAD_CLAIM_DUR");
        require(_minHoldAge >= 1 days && _minHoldAge <= 365 days, "BAD_HOLD_AGE");
        require(_quorumBps <= 10_000, "BAD_QUORUM");
        require(_claimCapBps <= 10_000, "BAD_CAP");

        cycleTriggerAmount = _cycleTriggerAmount;
        voteDuration = _voteDuration;
        claimDuration = _claimDuration;
        minHoldAge = _minHoldAge;
        quorumBps = _quorumBps;
        claimCapBps = _claimCapBps;

        emit ConfigUpdated(cycleTriggerAmount, voteDuration, claimDuration, minHoldAge, quorumBps, claimCapBps);
    }

    function setBlockedWallet(address wallet, bool blocked) external onlyDAOorOwner {
        require(wallet != address(0), "ZERO_WALLET");
        blockedWallet[wallet] = blocked;
        emit BlockedWalletSet(wallet, blocked);
    }

    function pauseEmergencial() external onlyDAOorOwner {
        _pause();
        _emitHubEvent(ACTION_PAUSE, msg.sender, 0, "");
    }

    function unpause() external onlyDAOorOwner {
        _unpause();
        _emitHubEvent(ACTION_UNPAUSE, msg.sender, 0, "");
    }

    /// @notice Rescue native currency forcibly sent (selfdestruct / mistaken transfer).
    function rescueBNB(address to, uint256 amount) external onlyOwner nonReentrant {
        require(to != address(0), "ZERO_TO");
        require(amount > 0, "ZERO_AMOUNT");
        (bool ok, ) = to.call{value: amount}("");
        require(ok, "BNB_RESCUE_FAIL");
    }

    /* ============================================================
                        VOTING POWER (CEI NINJA)
       ============================================================ */
    function depositVotingPower(uint256 amount) external nonReentrant whenNotPaused {
        require(amount > 0, "ZERO_AMOUNT");
        require(mimhoToken() != address(0), "TOKEN_NOT_SET");
        require(!_isBlocked(msg.sender), "BLOCKED");

        // effects first
        if (firstSeenAt[msg.sender] == 0) {
            firstSeenAt[msg.sender] = block.timestamp;
            emit Registered(msg.sender, block.timestamp);
        }

        votingPowerStaked[msg.sender] += amount;
        totalVotingPowerStaked += amount;

        emit VotingPowerDeposited(msg.sender, amount, votingPowerStaked[msg.sender], totalVotingPowerStaked);

        // interactions at the end
        require(_token().transferFrom(msg.sender, address(this), amount), "TRANSFER_FROM_FAIL");
        _emitHubEvent(ACTION_VP_DEPOSIT, msg.sender, amount, abi.encode(votingPowerStaked[msg.sender], totalVotingPowerStaked)); // last line
    }

    function withdrawVotingPower(uint256 amount) external nonReentrant whenNotPaused {
        require(amount > 0, "ZERO_AMOUNT");
        require(block.timestamp >= lockedUntil[msg.sender], "LOCKED");

        uint256 bal = votingPowerStaked[msg.sender];
        require(bal >= amount, "INSUFFICIENT_VP");

        // effects first
        votingPowerStaked[msg.sender] = bal - amount;
        totalVotingPowerStaked -= amount;

        // ensure accounting safety (no withdrawal of non-withdrawable pools)
        uint256 contractBal = _token().balanceOf(address(this));
        uint256 requiredNonWithdrawable = burnReserve + reservedForCycles;
        require(contractBal >= requiredNonWithdrawable + totalVotingPowerStaked, "INSUFFICIENT_LIQUIDITY");

        emit VotingPowerWithdrawn(msg.sender, amount, votingPowerStaked[msg.sender], totalVotingPowerStaked);

        // interactions at the end
        require(_token().transfer(msg.sender, amount), "TRANSFER_FAIL");
        _emitHubEvent(ACTION_VP_WITHDRAW, msg.sender, amount, abi.encode(votingPowerStaked[msg.sender], totalVotingPowerStaked)); // last line
    }

    /* ============================================================
                         DEPOSIT FOR BURN (CEI NINJA)
       ============================================================ */
    function depositForBurn(uint256 amount, string calldata source) external nonReentrant whenNotPaused {
        require(amount > 0, "ZERO_AMOUNT");
        require(mimhoToken() != address(0), "TOKEN_NOT_SET");

        // effects first
        burnReserve += amount;

        emit Deposit(msg.sender, amount, source);

        // interactions at the end
        require(_token().transferFrom(msg.sender, address(this), amount), "TRANSFER_FROM_FAIL");
        _maybeOpenCycle(); // internal
        _emitHubEvent(ACTION_DEPOSIT, msg.sender, amount, abi.encode(source)); // last line
    }

    function _maybeOpenCycle() internal {
        if (activeCycleId != 0) return;
        if (burnReserve < cycleTriggerAmount) return;

        burnReserve -= cycleTriggerAmount;
        reservedForCycles += cycleTriggerAmount;

        cycleCount += 1;
        uint256 cycleId = cycleCount;
        activeCycleId = cycleId;

        uint256 start = block.timestamp;
        uint256 end = start + voteDuration;

        uint256 vpSnap = totalVotingPowerStaked;
        uint256 quorumTarget = (vpSnap * quorumBps) / 10_000;

        cycles[cycleId] = Cycle({
            state: CycleState.VOTING,
            amount: cycleTriggerAmount,
            startTime: start,
            voteEndTime: end,
            claimEndTime: 0,
            totalYes: 0,
            totalNo: 0,
            vpSnapshot: vpSnap,
            quorumTarget: quorumTarget,
            totalClaimed: 0,
            totalCappedBurned: 0,
            finalized: false,
            distribute: false
        });

        emit CycleOpened(cycleId, cycleTriggerAmount, start, end, vpSnap, quorumTarget);

        // NOTE: _maybeOpenCycle is internal; hub emission is done by the caller where needed.
        // If you want a hub broadcast for cycle open, call openCycleBroadcast() externally.
    }

    /// @notice Optional manual broadcast for HUD (keeps slither happy by being the last line in this function).
    function broadcastCycleOpened(uint256 cycleId) external whenNotPaused {
        Cycle storage c = cycles[cycleId];
        require(c.state != CycleState.NONE, "NO_CYCLE");
        _emitHubEvent(ACTION_CYCLE_OPEN, msg.sender, c.amount, abi.encode(cycleId, c.startTime, c.voteEndTime, c.vpSnapshot, c.quorumTarget)); // last line
    }

    /* ============================================================
                                VOTING
       ============================================================ */
    function vote(uint256 cycleId, bool distribute) external nonReentrant whenNotPaused {
        Cycle storage c = cycles[cycleId];
        require(c.state == CycleState.VOTING, "NOT_VOTING");
        require(block.timestamp < c.voteEndTime, "VOTE_ENDED");
        require(!hasVoted[cycleId][msg.sender], "ALREADY_VOTED");
        require(_isEligibleAddress(msg.sender), "NOT_ELIGIBLE");

        uint256 weight = votingPowerStaked[msg.sender];
        require(weight > 0, "NO_VOTING_POWER");

        // effects first
        hasVoted[cycleId][msg.sender] = true;
        if (distribute) {
            votedYes[cycleId][msg.sender] = true;
            c.totalYes += weight;
        } else {
            c.totalNo += weight;
        }

        if (lockedUntil[msg.sender] < c.voteEndTime) {
            lockedUntil[msg.sender] = c.voteEndTime;
            emit VotingPowerLocked(msg.sender, c.voteEndTime, cycleId);
        }

        emit Voted(cycleId, msg.sender, distribute, weight);

        // interactions at the end
        _emitHubEvent(ACTION_VOTE, msg.sender, weight, abi.encode(cycleId, distribute)); // last line
    }

    /* ============================================================
                             FINALIZE (CEI NINJA)
       ============================================================ */
    function finalizeCycle(uint256 cycleId) external nonReentrant whenNotPaused {
        Cycle storage c = cycles[cycleId];
        require(c.state == CycleState.VOTING, "BAD_STATE");
        require(block.timestamp >= c.voteEndTime, "TOO_EARLY");
        require(!c.finalized, "ALREADY_FINALIZED");

        // effects first
        c.finalized = true;

        uint256 totalVotes = c.totalYes + c.totalNo;
        bool quorumMet = totalVotes >= c.quorumTarget;
        bool distribute = quorumMet && (c.totalYes > c.totalNo);
        c.distribute = distribute;

        if (distribute) {
            c.state = CycleState.CLAIMING;
            c.claimEndTime = block.timestamp + claimDuration;

            emit CycleFinalized(cycleId, true, c.totalYes, c.totalNo, quorumMet);

            // interactions at the end
            _emitHubEvent(ACTION_FINALIZE, msg.sender, c.amount, abi.encode(cycleId, true, c.totalYes, c.totalNo, quorumMet)); // last line
            return;
        }

        // burn path: effects first
        c.state = CycleState.BURNED;
        activeCycleId = 0;
        reservedForCycles -= c.amount;

        emit CycleFinalized(cycleId, false, c.totalYes, c.totalNo, quorumMet);

        // interactions at the end (burn transfer first, hub last)
        (BurnRoute route, address destinationOrSink) = _executeBurnOrRedirect(c.amount, bytes32(0), "VOTE_RESULT_OR_NO_QUORUM");
        _maybeOpenCycle();

        _emitHubEvent(
            ACTION_REDIRECT,
            msg.sender,
            c.amount,
            abi.encode(route == BurnRoute.BURN ? "BURN" : "STAKING", destinationOrSink, bytes32(0), "VOTE_RESULT_OR_NO_QUORUM")
        ); // last line
    }

    /* ============================================================
                                CLAIM (CEI NINJA)
       ============================================================ */
    function getClaimableAmount(uint256 cycleId, address user) public view returns (uint256 rawAmount, uint256 cappedAmount) {
        Cycle storage c = cycles[cycleId];
        if (c.state != CycleState.CLAIMING) return (0, 0);
        if (block.timestamp > c.claimEndTime) return (0, 0);
        if (!_isEligibleAddress(user)) return (0, 0);
        if (hasClaimed[cycleId][user]) return (0, 0);
        if (!votedYes[cycleId][user]) return (0, 0);

        uint256 totalYes = c.totalYes;
        if (totalYes == 0) return (0, 0);

        uint256 userWeight = votingPowerStaked[user];
        if (userWeight == 0) return (0, 0);

        rawAmount = (c.amount * userWeight) / totalYes;

        uint256 cap = (c.amount * claimCapBps) / 10_000;
        cappedAmount = rawAmount > cap ? cap : rawAmount;
    }

    function claim(uint256 cycleId) external nonReentrant whenNotPaused {
        Cycle storage c = cycles[cycleId];
        require(c.state == CycleState.CLAIMING, "NOT_CLAIMING");
        require(block.timestamp <= c.claimEndTime, "CLAIM_ENDED");
        require(!hasClaimed[cycleId][msg.sender], "ALREADY_CLAIMED");
        require(_isEligibleAddress(msg.sender), "NOT_ELIGIBLE");
        require(votedYes[cycleId][msg.sender], "NOT_YES_VOTER");

        (uint256 rawAmount, uint256 cappedAmount) = getClaimableAmount(cycleId, msg.sender);
        require(cappedAmount > 0, "NOTHING_TO_CLAIM");

        // effects first
        hasClaimed[cycleId][msg.sender] = true;
        if (rawAmount > cappedAmount) {
            c.totalCappedBurned += (rawAmount - cappedAmount);
        }
        c.totalClaimed += cappedAmount;
        reservedForCycles -= cappedAmount;

        emit DistributionClaimed(cycleId, msg.sender, cappedAmount, rawAmount, cappedAmount);

        // interactions at the end (transfer first, hub last)
        require(_token().transfer(msg.sender, cappedAmount), "TRANSFER_FAIL");
        _emitHubEvent(ACTION_CLAIM, msg.sender, cappedAmount, abi.encode(cycleId, rawAmount, cappedAmount)); // last line
    }

    /* ============================================================
                        CLOSE EXPIRED (CEI NINJA)
       ============================================================ */
    function closeExpiredCycle(uint256 cycleId) external nonReentrant whenNotPaused {
        // 1. CHECKS
        Cycle storage c = cycles[cycleId];
        require(c.state == CycleState.CLAIMING, "NOT_CLAIMING");
        require(block.timestamp > c.claimEndTime, "NOT_EXPIRED");

        uint256 remainder = c.amount - c.totalClaimed;
        bytes32 ctx = keccak256(abi.encodePacked("MIMHO_BURN_CLOSE", cycleId, block.number, block.timestamp, remainder));

        // 2. EFFECTS (Mudanças de estado no contrato)
        c.state = CycleState.DISTRIBUTED;
        activeCycleId = 0;

        if (remainder > 0) {
            reservedForCycles -= remainder;
        }

        // ✅ MOVE _maybeOpenCycle para cá: 
        // Atualizamos o estado do próximo ciclo ANTES de interagir com tokens externos.
        _maybeOpenCycle();

        emit CycleClosed(cycleId, c.totalClaimed, remainder, remainder, c.totalCappedBurned, ctx);

        // 3. INTERACTIONS (Dinheiro e chamadas externas por último)
        BurnRoute route = BurnRoute(0); 
        address destinationOrSink = address(0);

        if (remainder > 0) {
            // Esta função realiza a transferência real de tokens
            (route, destinationOrSink) = _executeBurnOrRedirect(remainder, ctx, "CLAIM_EXPIRED_REMAINDER");
        }

        // 4. HUB EVENT (Sempre a última linha, por segurança)
        _emitHubEvent(
            ACTION_EXPIRE,
            msg.sender,
            remainder,
            abi.encode(
                cycleId, 
                c.totalClaimed, 
                remainder, 
                c.totalCappedBurned, 
                route == BurnRoute.BURN ? "BURN" : "STAKING", 
                destinationOrSink, 
                ctx
            )
        );
    }

    /* ============================================================
                         BURN / REDIRECT (NO HUB)
       ============================================================ */
    function _executeBurnOrRedirect(uint256 amount, bytes32 contextHash, string memory reason)
        internal
        returns (BurnRoute route, address destinationOrSink)
    {
        // Slither: init locals early
        uint256 supply = 0;
        bool canReadSupply = false;

        address tokenAddr = mimhoToken();
        require(tokenAddr != address(0), "TOKEN_NOT_SET");

        (bool ok, bytes memory ret) = tokenAddr.staticcall(abi.encodeWithSignature("totalSupply()"));
        if (ok && ret.length >= 32) {
            canReadSupply = true;
            supply = abi.decode(ret, (uint256));
        }

        if (canReadSupply && supply <= SUPPLY_FLOOR) {
            address stakingAddr = registry.getContract(registry.KEY_MIMHO_STAKING());
            require(stakingAddr != address(0), "STAKING_NOT_SET");

            require(_token().transfer(stakingAddr, amount), "REDIRECT_FAIL");

            emit Redirected(msg.sender, amount, stakingAddr, contextHash, reason);
            return (BurnRoute.STAKING, stakingAddr);
        } else {
            address burnSink = address(0x000000000000000000000000000000000000dEaD);
            require(_token().transfer(burnSink, amount), "BURN_TRANSFER_FAIL");

            emit BurnExecuted(msg.sender, amount, burnSink, contextHash, reason);
            return (BurnRoute.BURN, burnSink);
        }
    }

    /* ============================================================
                        VOLUNTARY BURN + NFT BADGE
       ============================================================ */
    event VoluntaryBurn(address indexed  burner, uint256 amount, bytes32 contextHash, string reason);
    event BurnBadgeMintAttempt(address indexed  burner, bytes32 contextHash, bool success, uint256 tokenId);

    function burnVoluntarily(uint256 amount, string calldata reason) external nonReentrant whenNotPaused {
        require(amount > 0, "ZERO_AMOUNT");
        require(!_isBlocked(msg.sender), "BLOCKED");
        require(mimhoToken() != address(0), "TOKEN_NOT_SET");

        bytes32 ctx = keccak256(abi.encodePacked("MIMHO_VOL_BURN", msg.sender, amount, block.number, block.timestamp, reason));

        // no state effects needed besides events; keep CEI ordering anyway
        emit VoluntaryBurn(msg.sender, amount, ctx, reason);

        // interactions at the end (pull -> burn/redirect -> certify/mint -> hub last)
        require(_token().transferFrom(msg.sender, address(this), amount), "TRANSFER_FROM_FAIL");

        (BurnRoute route, address destinationOrSink) = _executeBurnOrRedirect(amount, ctx, "VOLUNTARY_BURN");

        _bestEffortCertifyAndMint(msg.sender, amount, ctx, reason);

        _emitHubEvent(
            ACTION_VOL_BURN,
            msg.sender,
            amount,
            abi.encode(ctx, reason, route == BurnRoute.BURN ? "BURN" : "STAKING", destinationOrSink)
        ); // last line
    }

    function _bestEffortCertifyAndMint(address burner, uint256 amount, bytes32 ctx, string memory reason) internal {
        address certifyAddr = registry.getContract(registry.KEY_MIMHO_CERTIFY());
        if (certifyAddr != address(0)) {
            try IMIMHOCertify(certifyAddr).recordBurn(
                burner,
                amount,
                block.timestamp,
                ctx,
                abi.encode(reason, contractType(), version)
            ) {
                // best-effort
            } catch {
                // ignore
            }
        }

        address martAddr = registry.getContract(registry.KEY_MIMHO_MART());
        if (martAddr != address(0)) {
            try IMIMHOMart(martAddr).mintBurnBadge(
                burner,
                amount,
                block.timestamp,
                ctx,
                reason
            ) returns (uint256 tokenId) {
                bool success = (tokenId != 0);
                emit BurnBadgeMintAttempt(burner, ctx, success, tokenId);
            } catch {
                emit BurnBadgeMintAttempt(burner, ctx, false, 0);
            }
        }
    }

    /* ============================================================
                              VIEW HELPERS
       ============================================================ */
    function getStatus()
        external
        view
        returns (
            uint256 _activeCycleId,
            CycleState _state,
            uint256 contractTokenBalance,
            uint256 _burnReserve,
            uint256 _reservedForCycles,
            uint256 _totalVotingPowerStaked,
            bool paused_,
            address tokenAddr,
            address dao,
            bool daoActive
        )
    {
        _activeCycleId = activeCycleId;
        _state = (_activeCycleId == 0) ? CycleState.NONE : cycles[_activeCycleId].state;
        tokenAddr = mimhoToken();
        contractTokenBalance = (tokenAddr == address(0)) ? 0 : _token().balanceOf(address(this));
        _burnReserve = burnReserve;
        _reservedForCycles = reservedForCycles;
        _totalVotingPowerStaked = totalVotingPowerStaked;
        paused_ = paused();
        dao = daoContract;
        daoActive = daoActivated;
    }

    function getConfig()
        external
        view
        returns (
            uint256 _cycleTriggerAmount,
            uint256 _voteDuration,
            uint256 _claimDuration,
            uint256 _minHoldAge,
            uint16 _quorumBps,
            uint16 _claimCapBps
        )
    {
        return (cycleTriggerAmount, voteDuration, claimDuration, minHoldAge, quorumBps, claimCapBps);
    }

    function getCycle(uint256 cycleId) external view returns (Cycle memory) {
        return cycles[cycleId];
    }

    function isEligible(address user) external view returns (bool eligible, uint256 seenAt, bool blocked) {
        seenAt = firstSeenAt[user];
        blocked = _isBlocked(user);
        eligible = _isEligibleAddress(user);
    }

    function getVotingPower(address user)
        external
        view
        returns (uint256 staked, uint256 totalStaked, uint256 lockUntil)
    {
        return (votingPowerStaked[user], totalVotingPowerStaked, lockedUntil[user]);
    }

    /* ============================================================
                                RECEIVE
       ============================================================ */
    receive() external payable {
        revert("NO_NATIVE_ACCEPT");
    }
}
>>>>>>> fe7ced1 (Add official deployed MIMHO contracts with BscScan headers)
