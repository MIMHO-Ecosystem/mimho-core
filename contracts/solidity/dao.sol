<<<<<<< HEAD
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

abstract contract MIMHO DAO {
    string public constant version = "0.0.0-placeholder";
    function contractType() public pure virtual returns (bytes32) { return keccak256("MIMHO_DAO"); }
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
abstract contract MIMHO Dao {
    /// @notice Human readable version for repository tracking (not on-chain guarantee).
    string public constant version = "0.0.0-placeholder";

    /// @notice Contract module type identifier (used by HUD/Events Hub in final builds).
    function contractType() public pure virtual returns (bytes32) {
        return CONTRACT_TYPE;
    }
}
=======
/// -----------------------------------------------------------------------
/// MIMHO DAO GOVERNANCE V2
/// Official MIMHO Ecosystem Contract
///
/// Network: BNB Smart Chain
/// Contract Address:
/// 0x32158B17E3C0D2Acd8Ef5B74fa95578b933e4322
///
/// BscScan:
/// https://bscscan.com/address/0x32158B17E3C0D2Acd8Ef5B74fa95578b933e4322
/// -----------------------------------------------------------------------

// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/* ============================================================
   MIMHO DAO GOVERNANCE — v1.0.0 (Protocolo Absoluto MIMHO)
   ============================================================

   DESIGN PHILOSOPHY (ENGLISH)

   - Radical Transparency:
     Every critical action is publicly observable via native events AND
     is broadcast (best-effort) to the MIMHO Events Hub for the HUD feed.

   - Zero Funds Custody:
     This contract does NOT hold or distribute funds. Payroll is a separate
     contract/module. Governance here focuses on elections + roles logic only.

   - Fair Voting:
     Quadratic voting (sqrt(balance)) + optional bonus (reputation/staking hook)
     to reward long-term participation without excluding anyone.

   - Sybil Resistance:
     Voters/candidates must satisfy minimum holding time and minimum balance.
     Parameters are DAO-governed to evolve with price/supply dynamics.

   - Modular Ecosystem Wiring:
     All dependencies are resolved through MIMHORegistry keys (NO local keccak strings).
     Registry may be updated only by DAO/Owner under the standard takeover pattern.

   - Never Break User Transactions:
     Calls to Events Hub are best-effort via try/catch. If Hub reverts, governance
     flows keep working.

   NOTE:
   - This contract DOES NOT mint NFTs. MIMHO Mart / Observer can mint based on events.
   - No anti-whale caps are enforced (explicitly per your decision).

   ============================================================ */

interface IMIMHORegistry {
    function getContract(bytes32 key) external view returns (address);

    // ✅ Absolute rule: resolve keys via getters on the Registry (no local keccak strings)
    function KEY_MIMHO_EVENTS_HUB() external view returns (bytes32);
    function KEY_MIMHO_REPUTATION() external view returns (bytes32);
    function KEY_MIMHO_TOKEN() external view returns (bytes32);
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

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
}

/// @dev Optional bonus hook. Return bonus as percentage (e.g., 0..50).
interface IMIMHOReputationBonus {
    function getBonusPercent(address user) external view returns (uint256);
}

contract MIMHODaoGovernance {
    /*//////////////////////////////////////////////////////////////
                                ICONTRATO
    //////////////////////////////////////////////////////////////*/
    // Padrão Completo MIMHO: marcador simples e público
    string public constant icontratoMimho = "icontratoMimho";
    string public constant version = "1.0.0";

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/
    uint256 public constant MIN_HOLD_TIME_DEFAULT = 90 days;

    // HUD actions (bytes32) — stable identifiers
    bytes32 public constant ACTION_HOLDING_REGISTERED  = keccak256("DAO_HOLDING_REGISTERED");
    bytes32 public constant ACTION_CANDIDATE_REGISTERED= keccak256("DAO_CANDIDATE_REGISTERED");
    bytes32 public constant ACTION_ELECTION_STARTED    = keccak256("DAO_ELECTION_STARTED");
    bytes32 public constant ACTION_VOTE_CAST           = keccak256("DAO_VOTE_CAST");
    bytes32 public constant ACTION_ELECTION_FINISHED   = keccak256("DAO_ELECTION_FINISHED");
    bytes32 public constant ACTION_IMPEACHMENT         = keccak256("DAO_IMPEACHMENT");
    bytes32 public constant ACTION_PARAMS_UPDATED      = keccak256("DAO_PARAMS_UPDATED");
    bytes32 public constant ACTION_REGISTRY_UPDATED    = keccak256("DAO_REGISTRY_UPDATED");
    bytes32 public constant ACTION_PAUSED              = keccak256("DAO_PAUSED");
    bytes32 public constant ACTION_UNPAUSED            = keccak256("DAO_UNPAUSED");
    bytes32 public constant ACTION_DAO_SET             = keccak256("DAO_DAO_SET");
    bytes32 public constant ACTION_DAO_ACTIVATED       = keccak256("DAO_DAO_ACTIVATED");

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/
    IMIMHORegistry public registry;
    IERC20 public mimhoToken; // resolved once and kept in sync with registry if you want; can also be immutable if you prefer.

    // Ownership / DAO takeover (standard MIMHO)
    address public immutable owner;
    address public dao;
    bool public daoActivated;

    // Emergency pause
    bool public paused;

    // Governance parameters (DAO-controlled)
    uint256 public minHoldTime;           // default 90d
    uint256 public minTokensToVote;       // default 1,000,000 MIMHO (set at deploy)
    uint256 public minTokensToCandidate;  // default 1,000,000 MIMHO (set at deploy)
    uint256 public maxBonusPercent;       // safety cap on bonus percent (e.g., 50)

    // Election state
    bool public electionActive;
    uint256 public electionStart;
    uint256 public electionEnd;

    // Candidate set
    address[] private _candidates;
    mapping(address => bool) public isCandidate;

    // Voting
    mapping(address => bool) public hasVoted;
    mapping(address => uint256) public votesReceived;

    // Holding-time registration (simple on-chain anchor)
    mapping(address => uint256) public holdingSince;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/
    event CandidateRegistered(address indexed  candidate);
    event HoldingRegistered(address indexed  user, uint256 since);
    event VoteCast(address indexed  voter, address indexed  candidate, uint256 weight, uint256 baseWeight, uint256 bonusPercent);
    event ElectionStarted(uint256 indexed start, uint256 indexed end);
    event ElectionFinished(address[] ranking);
    event ImpeachmentExecuted(uint256 indexed indexRemoved, address indexed  removed, address indexed promoted);
    event ParamsUpdated(uint256 minHoldTime, uint256 minTokensToVote, uint256 minTokensToCandidate, uint256 maxBonusPercent);
    event RegistryUpdated(address indexed  newRegistry);
    event DAOSet(address indexed  dao);
    event DAOActivated(address indexed  dao);
    event Paused();
    event Unpaused();

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier whenNotPaused() {
        require(!paused, "MIMHO: paused");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "MIMHO: not owner");
        _;
    }

    modifier onlyDAOorOwner() {
        // before activation, owner controls; after activation, DAO (and owner as fallback if you prefer)
        if (daoActivated) {
            require(msg.sender == dao || msg.sender == owner, "MIMHO: not DAO/owner");
        } else {
            require(msg.sender == owner, "MIMHO: not owner (DAO not active)");
        }
        _;
    }

    modifier onlyBeforeElection() {
        require(!electionActive, "MIMHO: election active");
        _;
    }

    modifier onlyDuringElection() {
        require(electionActive, "MIMHO: election not active");
        _;
    }

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(
    address registryAddr,
    uint256 _minTokensToVote,
    uint256 _minTokensToCandidate,
    uint256 _maxBonusPercent
    
) {
    require(registryAddr != address(0), "MIMHO: registry=0");

    owner = msg.sender;

        registry = IMIMHORegistry(registryAddr);
        

        // Resolve token via Registry key (Absolute rule)
        address tokenAddr = registry.getContract(registry.KEY_MIMHO_TOKEN());
        require(tokenAddr != address(0), "MIMHO: token not set in Registry");
        mimhoToken = IERC20(tokenAddr);

        minHoldTime = MIN_HOLD_TIME_DEFAULT;
        minTokensToVote = _minTokensToVote;
        minTokensToCandidate = _minTokensToCandidate;
        maxBonusPercent = _maxBonusPercent;
        

        // Emit parameters to HUD best-effort
        _emitHubEvent(ACTION_PARAMS_UPDATED, msg.sender, 0, abi.encode(minHoldTime, minTokensToVote, minTokensToCandidate, maxBonusPercent));
    }

    /*//////////////////////////////////////////////////////////////
                            PROTOCOL ID
    //////////////////////////////////////////////////////////////*/
    function contractType() public pure returns (bytes32) {
        return keccak256("MIMHO_DAO_GOVERNANCE");
    }

    /*//////////////////////////////////////////////////////////////
                        DAO TAKEOVER (STANDARD)
    //////////////////////////////////////////////////////////////*/
    function setDAO(address daoAddr) external onlyOwner {
        require(daoAddr != address(0), "MIMHO: dao=0");
        require(!daoActivated, "MIMHO: DAO already active");
        dao = daoAddr;
        emit DAOSet(daoAddr);
        _emitHubEvent(ACTION_DAO_SET, msg.sender, 0, abi.encode(daoAddr));
    }

    function activateDAO() external onlyOwner {
        require(dao != address(0), "MIMHO: DAO not set");
        require(!daoActivated, "MIMHO: already active");
        daoActivated = true;
        emit DAOActivated(dao);
        _emitHubEvent(ACTION_DAO_ACTIVATED, msg.sender, 0, abi.encode(dao));
    }

    /*//////////////////////////////////////////////////////////////
                        REGISTRY (DAO-GOVERNED)
    //////////////////////////////////////////////////////////////*/
    function setRegistry(address newRegistry) external onlyDAOorOwner {
        require(newRegistry != address(0), "MIMHO: registry=0");
        registry = IMIMHORegistry(newRegistry);

        // Refresh token from Registry key (safety)
        address tokenAddr = registry.getContract(registry.KEY_MIMHO_TOKEN());
        require(tokenAddr != address(0), "MIMHO: token missing in Registry");
        mimhoToken = IERC20(tokenAddr);

        emit RegistryUpdated(newRegistry);
        _emitHubEvent(ACTION_REGISTRY_UPDATED, msg.sender, 0, abi.encode(newRegistry, tokenAddr));
    }

    /*//////////////////////////////////////////////////////////////
                            EMERGENCY PAUSE
    //////////////////////////////////////////////////////////////*/
    function pauseEmergencial() external onlyDAOorOwner {
        paused = true;
        emit Paused();
        _emitHubEvent(ACTION_PAUSED, msg.sender, 0, "");
    }

    function unpause() external onlyDAOorOwner {
        paused = false;
        emit Unpaused();
        _emitHubEvent(ACTION_UNPAUSED, msg.sender, 0, "");
    }

    /*//////////////////////////////////////////////////////////////
                            PARAMETERS
    //////////////////////////////////////////////////////////////*/
    function setElectionParams(
        uint256 _minHoldTime,
        uint256 _minTokensToVote,
        uint256 _minTokensToCandidate,
        uint256 _maxBonusPercent
    ) external onlyDAOorOwner {
        require(!electionActive, "MIMHO: cannot change during election");
        require(_minHoldTime >= 1 days && _minHoldTime <= 3650 days, "MIMHO: holdTime invalid");
        require(_maxBonusPercent <= 500, "MIMHO: bonus too high"); // hard cap 500% just in case

        minHoldTime = _minHoldTime;
        minTokensToVote = _minTokensToVote;
        minTokensToCandidate = _minTokensToCandidate;
        maxBonusPercent = _maxBonusPercent;

        emit ParamsUpdated(minHoldTime, minTokensToVote, minTokensToCandidate, maxBonusPercent);
        _emitHubEvent(ACTION_PARAMS_UPDATED, msg.sender, 0, abi.encode(minHoldTime, minTokensToVote, minTokensToCandidate, maxBonusPercent));
    }

    /*//////////////////////////////////////////////////////////////
                        HOLDING TIME ANCHOR
    //////////////////////////////////////////////////////////////*/
    function registerHolding() external whenNotPaused {
        if (holdingSince[msg.sender] == 0) {
            holdingSince[msg.sender] = block.timestamp;
            emit HoldingRegistered(msg.sender, block.timestamp);
            _emitHubEvent(ACTION_HOLDING_REGISTERED, msg.sender, block.timestamp, "");
        }
    }

    function _checkEligibility(address user, uint256 minTokens) internal view {
        require(mimhoToken.balanceOf(user) >= minTokens, "MIMHO: insufficient tokens");
        uint256 since = holdingSince[user];
        require(since != 0, "MIMHO: holding not registered");
        require(block.timestamp - since >= minHoldTime, "MIMHO: holding time not met");
    }

    /*//////////////////////////////////////////////////////////////
                            CANDIDATURE
    //////////////////////////////////////////////////////////////*/
    function registerCandidate() external whenNotPaused onlyBeforeElection {
        _checkEligibility(msg.sender, minTokensToCandidate);
        require(!isCandidate[msg.sender], "MIMHO: already candidate");

        isCandidate[msg.sender] = true;
        _candidates.push(msg.sender);

        emit CandidateRegistered(msg.sender);
        _emitHubEvent(ACTION_CANDIDATE_REGISTERED, msg.sender, 0, "");
    }

    function candidatesCount() external view returns (uint256) {
        return _candidates.length;
    }

    function candidateAt(uint256 index) external view returns (address) {
        return _candidates[index];
    }

    function getCandidates() external view returns (address[] memory) {
        return _candidates;
    }

    /*//////////////////////////////////////////////////////////////
                            ELECTION CONTROL
    //////////////////////////////////////////////////////////////*/
    function startElection(uint256 durationSeconds) external onlyDAOorOwner onlyBeforeElection {
        require(_candidates.length >= 5, "MIMHO: need >= 5 candidates");
        require(durationSeconds >= 1 days && durationSeconds <= 60 days, "MIMHO: duration invalid");

        electionStart = block.timestamp;
        electionEnd = block.timestamp + durationSeconds;
        electionActive = true;

        // Reset vote flags for new election (IMPORTANT)
        // NOTE: We cannot loop all voters. We keep `hasVoted` as-is and use an electionId approach
        // in v2 if you want unlimited elections. For now, treat as one election cycle per contract.
        // (You can deploy per cycle or extend in v2).
        emit ElectionStarted(electionStart, electionEnd);
        _emitHubEvent(ACTION_ELECTION_STARTED, msg.sender, electionEnd, abi.encode(electionStart, electionEnd));
    }

    function finishElection() external whenNotPaused {
        require(electionActive, "MIMHO: not active");
        require(block.timestamp >= electionEnd, "MIMHO: not finished");
        electionActive = false;

        address[] memory ranking = _rankCandidates();

        emit ElectionFinished(ranking);
        _emitHubEvent(ACTION_ELECTION_FINISHED, msg.sender, ranking.length, abi.encode(ranking));
    }

    /*//////////////////////////////////////////////////////////////
                                VOTING
    //////////////////////////////////////////////////////////////*/
    function vote(address candidate) external whenNotPaused onlyDuringElection {
        require(isCandidate[candidate], "MIMHO: invalid candidate");
        require(!hasVoted[msg.sender], "MIMHO: already voted");

        _checkEligibility(msg.sender, minTokensToVote);

        uint256 bal = mimhoToken.balanceOf(msg.sender);
        uint256 baseWeight = _sqrt(bal);

        uint256 bonusPercent = _getBonusPercent(msg.sender);
        if (bonusPercent > maxBonusPercent) bonusPercent = maxBonusPercent;

        uint256 weight = baseWeight + (baseWeight * bonusPercent) / 100;

        votesReceived[candidate] += weight;
        hasVoted[msg.sender] = true;

        emit VoteCast(msg.sender, candidate, weight, baseWeight, bonusPercent);
        _emitHubEvent(ACTION_VOTE_CAST, msg.sender, weight, abi.encode(candidate, baseWeight, bonusPercent));
    }

    function _getBonusPercent(address user) internal view returns (uint256) {
        address repAddr = registry.getContract(registry.KEY_MIMHO_REPUTATION());
        if (repAddr == address(0)) return 0;
        // If Reputation contract is missing or reverts, return 0 (soft dependency).
        try IMIMHOReputationBonus(repAddr).getBonusPercent(user) returns (uint256 b) {
            return b;
        } catch {
            return 0;
        }
    }

    /*//////////////////////////////////////////////////////////////
                            IMPEACHMENT
    //////////////////////////////////////////////////////////////*/
    /// @notice Governance action (triggered by DAO/Owner) — the impeachment voting
    /// process can be implemented in a separate Proposal module if desired.
    /// This function applies the “ladder promotion” rule you defined:
    /// removing index i promotes i+1 into that slot, and shifts up.
    function impeach(uint256 indexRemoved) external onlyDAOorOwner {
        require(_candidates.length >= 2, "MIMHO: insufficient roster");
        require(indexRemoved < _candidates.length - 1, "MIMHO: invalid index");

        address removed = _candidates[indexRemoved];
        address promoted = _candidates[indexRemoved + 1];

        // Shift left
        for (uint256 i = indexRemoved; i < _candidates.length - 1; i++) {
            _candidates[i] = _candidates[i + 1];
        }
        _candidates.pop();

        // Candidate status:
        // removed is no longer in roster but remains marked as candidate historically.
        // If you want to fully remove, uncomment:
        // isCandidate[removed] = false;

        emit ImpeachmentExecuted(indexRemoved, removed, promoted);
        _emitHubEvent(ACTION_IMPEACHMENT, msg.sender, 0, abi.encode(indexRemoved, removed, promoted));
    }

    /*//////////////////////////////////////////////////////////////
                            TRANSPARENCY VIEWS
    //////////////////////////////////////////////////////////////*/
    function getElectionState()
        external
        view
        returns (
            bool _active,
            uint256 _start,
            uint256 _end,
            uint256 _candidateCount
        )
    {
        return (electionActive, electionStart, electionEnd, _candidates.length);
    }

    function getVotes(address candidate) external view returns (uint256) {
        return votesReceived[candidate];
    }

    function previewRanking() external view returns (address[] memory) {
        return _rankCandidates();
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/
    function _rankCandidates() internal view returns (address[] memory) {
        address[] memory sorted = _candidates;
        uint256 n = sorted.length;

        // O(n^2) sorting is acceptable for small candidate lists.
        // If you expect large lists, we can switch to off-chain ranking + on-chain verification in v2.
        for (uint256 i = 0; i < n; i++) {
            for (uint256 j = i + 1; j < n; j++) {
                if (votesReceived[sorted[j]] > votesReceived[sorted[i]]) {
                    address tmp = sorted[i];
                    sorted[i] = sorted[j];
                    sorted[j] = tmp;
                }
            }
        }
        return sorted;
    }

    function _sqrt(uint256 x) internal pure returns (uint256 y) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }

    /*//////////////////////////////////////////////////////////////
                        EVENTS HUB (HUD) — ABSOLUTE RULE
    //////////////////////////////////////////////////////////////*/
    function _emitHubEvent(
        bytes32 action,
        address caller,
        uint256 value,
        bytes memory data
    ) internal {
        address hubAddr = registry.getContract(registry.KEY_MIMHO_EVENTS_HUB());
        if (hubAddr == address(0)) return;

        // best-effort: never break core logic
        try IMIMHOEventsHub(hubAddr).emitEvent(
            contractType(),
            action,
            caller,
            value,
            data
        ) {
            // ok
        } catch {
            // swallow
        }
    }

    /*//////////////////////////////////////////////////////////////
                            RECEIVE / FALLBACK
    //////////////////////////////////////////////////////////////*/
    receive() external payable {
        // This contract should not hold funds; accept only if someone mistakenly sends.
        // Optionally, you can revert here to be strict:
        // revert("MIMHO: no funds");
    }

    fallback() external payable {}

    /// @dev Resgata BNB preso acidentalmente no contrato.
    function rescueNative() external onlyDAOorOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "MIMHO: balance is zero");
        (bool success, ) = payable(msg.sender).call{value: balance}("");
        require(success, "MIMHO: rescue failed");
    }
}
>>>>>>> fe7ced1 (Add official deployed MIMHO contracts with BscScan headers)
