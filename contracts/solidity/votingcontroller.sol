<<<<<<< HEAD
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

abstract contract MIMHO Voting Controller {
    string public constant version = "0.0.0-placeholder";
    function contractType() public pure virtual returns (bytes32) { return keccak256("MIMHO_VOTING_CONTROLLER"); }
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
abstract contract MIMHO Voting Controller {
    /// @notice Human readable version for repository tracking (not on-chain guarantee).
    string public constant version = "0.0.0-placeholder";

    /// @notice Contract module type identifier (used by HUD/Events Hub in final builds).
    function contractType() public pure virtual returns (bytes32) {
        return CONTRACT_TYPE;
    }
}
=======
/// -----------------------------------------------------------------------
/// MIMHO LIQUIDITY VOTING CONTROLLER
/// Official MIMHO Ecosystem Contract
///
/// Network: BNB Smart Chain
/// Contract Address:
/// 0xFB7fDaac116a7766Ea6B4B6F470d48a50001aa68
///
/// BscScan:
/// https://bscscan.com/address/0xFB7fDaac116a7766Ea6B4B6F470d48a50001aa68
/// -----------------------------------------------------------------------

// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/* ============================================================
   MIMHO Inject Liquidity Voting Controller — v1.0.2 (Pre-DAO)
   ============================================================

   DESIGN PHILOSOPHY (MIMHO ABSOLUTE STANDARD)

   - Minimal, Single-Purpose Governance:
     This contract exists for one decision only: authorize (YES/NO)
     whether MIMHOInjectLiquidity may enable its auto-injection mode
     for the current cycle.

   - No Funds, No Economics, No Execution:
     It never holds, transfers, swaps, burns, mints, injects liquidity,
     or touches LP/BNB. It is NOT a DAO. It is only a gatekeeper.

   - Safe-by-Design:
     Limited surface area, strict phases (prepare -> vote -> finalize),
     reentrancy protection on voting, and no upgrade logic.

   - Transparent & HUD-Ready:
     Every meaningful action emits local events and also broadcasts
     (best-effort) to the MIMHO Events Hub via Registry resolution.

   - Registry-First, No Hardcoded Addresses:
     All integrations resolve addresses from MIMHORegistry using its
     public KEY getters (no local keccak/string repetition for keys).

   - Permission Model with Clean DAO Takeover:
     Uses onlyDAOorOwner before DAO activation and onlyDAO after.
     No renounceOwnership patterns.

   - No Cron / No Hidden Automation:
     Anyone can finalize after the end time. The "authorization" is pushed
     to InjectLiquidity at finalize (one call), InjectLiquidity does execution
     later under its own cooldown/guards.

   ============================================================ */

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";

interface IMIMHORegistry {
    function getContract(bytes32 key) external view returns (address);

    // ABSOLUTE RULE: use registry.KEY_*() + getContract(key)
    function KEY_MIMHO_TOKEN() external view returns (bytes32);
    function KEY_MIMHO_INJECT_LIQUIDITY() external view returns (bytes32);
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

interface IERC20Like {
    function balanceOf(address account) external view returns (uint256);
}

interface IMIMHOInjectLiquidity {
    function setAutoInject(bool enabled) external;
    function autoInjectEnabled() external view returns (bool);
}

contract MIMHOInjectLiquidityVotingController is ReentrancyGuard, Pausable, Ownable2Step {
    /*//////////////////////////////////////////////////////////////
                               MIMHO ID
    //////////////////////////////////////////////////////////////*/

    string public constant name = "MIMHO Inject Liquidity Voting Controller";
    string public constant version = "1.0.2";

    /// @dev Used by Events Hub as "module" identifier (HUD category)
    function contractType() public pure returns (bytes32) {
        return keccak256("MIMHO_VOTING_CONTROLLER_INJECT_LIQUIDITY");
    }

    /*//////////////////////////////////////////////////////////////
                           DAO TAKEOVER (ABS)
    //////////////////////////////////////////////////////////////*/

    address public daoAddress;
    bool public daoActivated;

    modifier onlyDAOorOwner() {
        require(msg.sender == owner() || (daoActivated && msg.sender == daoAddress), "MIMHO: not authorized");
        _;
    }

    modifier onlyDAO() {
        require(daoActivated && msg.sender == daoAddress, "MIMHO: DAO not active");
        _;
    }

    event DAOSet(address indexed dao);
    event DAOActivated(address indexed dao);

    /// @notice Manual set (pre-DAO), optional. After activation, DAO becomes enforced.
    function setDAO(address dao) external onlyOwner {
        require(!daoActivated, "MIMHO: DAO active");
        require(dao != address(0), "MIMHO: dao=0");

        daoAddress = dao;

        emit DAOSet(dao);
        _emitHubEvent(ACTION_SET_DAO, msg.sender, 0, abi.encode(dao));
    }

    /// @notice Activate DAO control (Registry-first).
    function activateDAO() external onlyOwner {
        require(!daoActivated, "MIMHO: DAO active");
        address dao = registry.getContract(registry.KEY_MIMHO_DAO());
        require(dao != address(0), "MIMHO: DAO not set in registry");

        daoAddress = dao;
        daoActivated = true;

        emit DAOActivated(dao);
        _emitHubEvent(ACTION_DAO_ACTIVATED, msg.sender, 0, abi.encode(dao));
    }

    /*//////////////////////////////////////////////////////////////
                               REGISTRY
    //////////////////////////////////////////////////////////////*/

    IMIMHORegistry public immutable registry;

    constructor(address registryAddr) {
        require(registryAddr != address(0), "MIMHO: registry=0");
        registry = IMIMHORegistry(registryAddr);

        // sensible defaults (avoid spam before config)
        voteCooldown = 7 days;
        minBalance = 0;

        _emitHubEvent(ACTION_DEPLOYED, msg.sender, 0, abi.encode(registryAddr, voteCooldown, minBalance));
    }

    /*//////////////////////////////////////////////////////////////
                           VOTING PARAMETERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Minimal balance required to vote (set to 0 for open voting).
    uint256 public minBalance;

    /// @notice Controls how frequently a new vote can be started.
    uint256 public voteCooldown;
    uint256 public lastVoteStart;

    uint256 public constant MIN_VOTE_COOLDOWN = 1 days;
    uint256 public constant MAX_VOTE_COOLDOWN = 45 days;

    /*//////////////////////////////////////////////////////////////
                              VOTING STATE
    //////////////////////////////////////////////////////////////*/

    uint256 public voteId;

    uint256 public prepareStart;
    uint256 public voteStart;
    uint256 public voteEnd;

    uint256 public yesVotes;
    uint256 public noVotes;

    bool public voteFinalized;

    mapping(address => uint256) private _votedIn;
    mapping(address => uint256) private _weightSnapshot;
    mapping(address => uint256) private _weightSnapshotIn;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event VoteStarted(uint256 indexed voteId, uint256 prepareStart, uint256 voteStart, uint256 voteEnd);
    event VoteCast(uint256 indexed voteId, address indexed voter, bool support, uint256 weight);
    event VoteFinalized(uint256 indexed voteId, bool approved);
    event AutoInjectStatusChanged(bool enabled);

    event MinBalanceChanged(uint256 newMinBalance);
    event VoteCooldownChanged(uint256 newCooldown);

    /*//////////////////////////////////////////////////////////////
                            EVENTS HUB (ABS)
    //////////////////////////////////////////////////////////////*/

    bytes32 private constant ACTION_DEPLOYED          = keccak256("DEPLOYED");
    bytes32 private constant ACTION_SET_DAO           = keccak256("SET_DAO");
    bytes32 private constant ACTION_DAO_ACTIVATED     = keccak256("DAO_ACTIVATED");
    bytes32 private constant ACTION_PAUSED            = keccak256("PAUSED");
    bytes32 private constant ACTION_UNPAUSED          = keccak256("UNPAUSED");

    bytes32 private constant ACTION_VOTE_STARTED      = keccak256("VOTE_STARTED");
    bytes32 private constant ACTION_VOTE_CAST         = keccak256("VOTE_CAST");
    bytes32 private constant ACTION_VOTE_FINALIZED    = keccak256("VOTE_FINALIZED");
    bytes32 private constant ACTION_AUTO_INJECT_SET   = keccak256("AUTO_INJECT_SET");

    bytes32 private constant ACTION_MIN_BALANCE_SET   = keccak256("MIN_BALANCE_SET");
    bytes32 private constant ACTION_VOTE_COOLDOWN_SET = keccak256("VOTE_COOLDOWN_SET");

    function _emitHubEvent(bytes32 action, address caller, uint256 value, bytes memory data) internal {
        address hubAddr = registry.getContract(registry.KEY_MIMHO_EVENTS_HUB());
        if (hubAddr == address(0)) return;

        try IMIMHOEventsHub(hubAddr).emitEvent(contractType(), action, caller, value, data) {
        } catch {
        }
    }

    /*//////////////////////////////////////////////////////////////
                             ADMIN CONFIG
    //////////////////////////////////////////////////////////////*/

    function setMinBalance(uint256 newMinBalance) external onlyDAOorOwner {
        require(!isVotingActive(), "MIMHO: locked during vote");
        minBalance = newMinBalance;
        emit MinBalanceChanged(newMinBalance);
        _emitHubEvent(ACTION_MIN_BALANCE_SET, msg.sender, newMinBalance, "");
    }

    function setVoteCooldown(uint256 newCooldown) external onlyDAOorOwner {
        require(!isVotingActive(), "MIMHO: locked during vote");
        require(newCooldown >= MIN_VOTE_COOLDOWN, "MIMHO: cooldown too low");
        require(newCooldown <= MAX_VOTE_COOLDOWN, "MIMHO: cooldown too high");
        voteCooldown = newCooldown;
        emit VoteCooldownChanged(newCooldown);
        _emitHubEvent(ACTION_VOTE_COOLDOWN_SET, msg.sender, newCooldown, "");
    }

    /*//////////////////////////////////////////////////////////////
                          START / PHASE CONTROL
    //////////////////////////////////////////////////////////////*/

    function startVote(uint256 prepareDuration, uint256 voteDuration)
        external
        onlyDAOorOwner
        whenNotPaused
    {
        require(prepareDuration > 0, "MIMHO: prepare=0");
        require(voteDuration > 0, "MIMHO: vote=0");
        require(!isVotingActive(), "MIMHO: already active");
        require(block.timestamp >= lastVoteStart + voteCooldown, "MIMHO: vote cooldown");

        require(registry.getContract(registry.KEY_MIMHO_TOKEN()) != address(0), "MIMHO: token not set in registry");
        require(registry.getContract(registry.KEY_MIMHO_INJECT_LIQUIDITY()) != address(0), "MIMHO: inject not set in registry");

        voteId += 1;

        prepareStart = block.timestamp;
        voteStart = block.timestamp + prepareDuration;
        voteEnd = voteStart + voteDuration;

        lastVoteStart = block.timestamp;

        yesVotes = 0;
        noVotes = 0;
        voteFinalized = false;

        emit VoteStarted(voteId, prepareStart, voteStart, voteEnd);
        _emitHubEvent(ACTION_VOTE_STARTED, msg.sender, 0, abi.encode(voteId, prepareStart, voteStart, voteEnd));
    }

    /*//////////////////////////////////////////////////////////////
                                VOTING
    //////////////////////////////////////////////////////////////*/

    function voteYes() external nonReentrant whenNotPaused { _vote(true); }
    function voteNo() external nonReentrant whenNotPaused { _vote(false); }

    function _vote(bool support) internal {
        require(isVotingPhase(), "MIMHO: not voting phase");
        require(_votedIn[msg.sender] != voteId, "MIMHO: already voted");
        require(canVote(msg.sender), "MIMHO: not eligible");

        uint256 weight = _snapshotWeight(msg.sender);
        require(weight > 0, "MIMHO: zero weight");

        _votedIn[msg.sender] = voteId;

        if (support) yesVotes += weight;
        else noVotes += weight;

        emit VoteCast(voteId, msg.sender, support, weight);
        _emitHubEvent(ACTION_VOTE_CAST, msg.sender, weight, abi.encode(voteId, support, weight));
    }

    function _snapshotWeight(address voter) internal returns (uint256) {
        if (_weightSnapshotIn[voter] != voteId) {
            address tokenAddr = registry.getContract(registry.KEY_MIMHO_TOKEN());
            require(tokenAddr != address(0), "MIMHO: token not set");
            uint256 bal = IERC20Like(tokenAddr).balanceOf(voter);
            _weightSnapshot[voter] = bal;
            _weightSnapshotIn[voter] = voteId;
        }
        return _weightSnapshot[voter];
    }

    /*//////////////////////////////////////////////////////////////
                               FINALIZE
    //////////////////////////////////////////////////////////////*/

    function finalizeVote() external whenNotPaused {
        require(hasVoteEnded(), "MIMHO: not ended");
        require(!voteFinalized, "MIMHO: finalized");

        address injectAddr = registry.getContract(registry.KEY_MIMHO_INJECT_LIQUIDITY());
        require(injectAddr != address(0), "MIMHO: inject not set in registry");

        voteFinalized = true;

        bool approved = yesVotes > noVotes;

        if (approved) {
            IMIMHOInjectLiquidity(injectAddr).setAutoInject(true);

            emit AutoInjectStatusChanged(true);
            _emitHubEvent(ACTION_AUTO_INJECT_SET, msg.sender, 1, abi.encode(true));
        }

        emit VoteFinalized(voteId, approved);
        _emitHubEvent(
            ACTION_VOTE_FINALIZED,
            msg.sender,
            approved ? 1 : 0,
            abi.encode(voteId, approved, yesVotes, noVotes)
        );
    }

    /*//////////////////////////////////////////////////////////////
                             VIEW (HUD)
    //////////////////////////////////////////////////////////////*/

    function isPreparePhase() public view returns (bool) {
        return prepareStart != 0 && block.timestamp >= prepareStart && block.timestamp < voteStart && !voteFinalized;
    }

    function isVotingPhase() public view returns (bool) {
        return voteStart != 0 && block.timestamp >= voteStart && block.timestamp < voteEnd && !voteFinalized;
    }

    function isVotingActive() public view returns (bool) {
        return (isPreparePhase() || isVotingPhase());
    }

    function hasVoteEnded() public view returns (bool) {
        return voteEnd != 0 && block.timestamp >= voteEnd;
    }

    function voteEndTime() external view returns (uint256) { return voteEnd; }

    function hasVoted(address voter) external view returns (bool) {
        return _votedIn[voter] == voteId;
    }

    function canVote(address voter) public view returns (bool) {
        address tokenAddr = registry.getContract(registry.KEY_MIMHO_TOKEN());
        if (tokenAddr == address(0)) return false;
        uint256 bal = IERC20Like(tokenAddr).balanceOf(voter);
        return bal >= minBalance;
    }

    function currentAutoInjectStatus() external view returns (bool) {
        address injectAddr = registry.getContract(registry.KEY_MIMHO_INJECT_LIQUIDITY());
        require(injectAddr != address(0), "MIMHO: inject not set");
        return IMIMHOInjectLiquidity(injectAddr).autoInjectEnabled();
    }

    function injectLiquidityAddress() external view returns (address) {
        return registry.getContract(registry.KEY_MIMHO_INJECT_LIQUIDITY());
    }

    function tokenAddress() external view returns (address) {
        return registry.getContract(registry.KEY_MIMHO_TOKEN());
    }

    /*//////////////////////////////////////////////////////////////
                                SAFETY
    //////////////////////////////////////////////////////////////*/

    function pauseEmergencial() external onlyDAOorOwner {
        _pause();
        _emitHubEvent(ACTION_PAUSED, msg.sender, 0, "");
    }

    function unpause() external onlyDAOorOwner {
        _unpause();
        _emitHubEvent(ACTION_UNPAUSED, msg.sender, 0, "");
    }

    /*//////////////////////////////////////////////////////////////
                              RECEIVE / FALLBACK
    //////////////////////////////////////////////////////////////*/

    receive() external payable { revert("MIMHO: no BNB"); }
    fallback() external payable { revert("MIMHO: invalid call"); }

    function rescueNative() external onlyDAOorOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "MIMHO: balance is zero");
        (bool success, ) = payable(msg.sender).call{value: balance}("");
        require(success, "MIMHO: rescue failed");
    }
}
>>>>>>> fe7ced1 (Add official deployed MIMHO contracts with BscScan headers)
