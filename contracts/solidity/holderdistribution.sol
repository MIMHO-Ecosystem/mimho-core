<<<<<<< HEAD
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

abstract contract MIMHO Holder Distribution {
    string public constant version = "0.0.0-placeholder";
    function contractType() public pure virtual returns (bytes32) { return keccak256("MIMHO_HOLDER_DISTRIBUTION"); }
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
abstract contract MIMHO Holder Distribution {
    /// @notice Human readable version for repository tracking (not on-chain guarantee).
    string public constant version = "0.0.0-placeholder";

    /// @notice Contract module type identifier (used by HUD/Events Hub in final builds).
    function contractType() public pure virtual returns (bytes32) {
        return CONTRACT_TYPE;
    }
}
=======
/// -----------------------------------------------------------------------
/// MIMHO HOLDER DISTRIBUTION VAULT
/// Official MIMHO Ecosystem Contract
///
/// Network: BNB Smart Chain
/// Contract Address:
/// 0x70512d12d402d8778660d886e19C14c043E86941
///
/// BscScan:
/// https://bscscan.com/address/0x70512d12d402d8778660d886e19C14c043E86941
/// -----------------------------------------------------------------------

// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/* ============================================================
   MIMHO HOLDER DISTRIBUTION VAULT — v1.0.0
   (Pull-based Merkle Distributions, Non-Custodial, HUD-ready)
   ============================================================

   MIMHO ABSOLUTE STANDARD (Applied)
   - Registry-first (no fixed addresses)
   - Events Hub emission via Registry + try/catch (best-effort)
   - onlyDAOorOwner + setDAO() + activateDAO()
   - pauseEmergencial/unpause
   - Maximum transparency: events + public views
   - Non-custodial: NO withdraw / NO admin rescue (by design)

   PURPOSE
   - Founder (or DAO later) deposits MIMHO tokens into this vault.
   - Opens a "Round" with a Merkle root that defines: (claimer, amount).
   - Each eligible holder calls claim() once per round.
   - 100% of deposited funds are destined to holders (no admin withdrawal).

   IMPORTANT NOTE
   - Eligibility lists are encoded into a Merkle root (snapshot off-chain).
     This is the only scalable way to distribute fairly on-chain without
     iterating holders (which is impossible on EVM).
   - On-chain protections still apply: excluded addresses cannot claim.

   ============================================================ */

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

/* =========================
   MIMHO REGISTRY INTERFACE
   ========================= */
interface IMIMHORegistry {
    function getContract(bytes32 key) external view returns (address);
    function isEcosystemContract(address a) external view returns (bool);
}

/* =========================
   MIMHO EVENTS HUB INTERFACE
   ========================= */
interface IMIMHOEventsHub {
    function emitEvent(
        bytes32 module,
        bytes32 action,
        address caller,
        uint256 value,
        bytes calldata data
    ) external;
}

contract MIMHOHolderDistributionVault is Ownable2Step, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /* ============================================================
                               CONSTANTS
       ============================================================ */

    string public constant version = "v1.0.0";

    // Registry keys (must match your ecosystem convention)
    bytes32 internal constant KEY_EVENTS_HUB = keccak256("MIMHO_EVENTS_HUB");

    // HUD module type for this contract
    bytes32 internal constant MODULE_TYPE = keccak256("MIMHO_HOLDER_DISTRIBUTION_VAULT");

    // HUD actions
    bytes32 internal constant ACT_DEPOSIT          = keccak256("DEPOSIT");
    bytes32 internal constant ACT_ROUND_OPEN       = keccak256("ROUND_OPEN");
    bytes32 internal constant ACT_ROUND_CLOSE      = keccak256("ROUND_CLOSE");
    bytes32 internal constant ACT_CLAIM            = keccak256("CLAIM");
    bytes32 internal constant ACT_EXCLUDE_ADDRESS  = keccak256("EXCLUDE_ADDRESS");
    bytes32 internal constant ACT_SET_DAO          = keccak256("SET_DAO");
    bytes32 internal constant ACT_ACTIVATE_DAO     = keccak256("ACTIVATE_DAO");
    bytes32 internal constant ACT_PAUSE            = keccak256("PAUSE");
    bytes32 internal constant ACT_UNPAUSE          = keccak256("UNPAUSE");

    /* ============================================================
                               IMMUTABLES
       ============================================================ */

    IMIMHORegistry public immutable registry;
    IERC20 public immutable mimhoToken;

    /* ============================================================
                               DAO CONTROL
       ============================================================ */

    address public DAO_CONTRACT;
    bool public daoActivated;

    modifier onlyDAOorOwner() {
        if (msg.sender == owner()) {
            _;
            return;
        }
        require(daoActivated && msg.sender == DAO_CONTRACT, "MIMHO: not DAO/owner");
        _;
    }

    /* ============================================================
                               EXCLUSIONS
       ============================================================ */

    // Permanent exclusion list. Once excluded, cannot be removed.
    mapping(address => bool) public excluded;

    /* ============================================================
                               ROUNDS
       ============================================================ */

    struct Round {
        bytes32 merkleRoot;
        uint256 totalAmount;   // total MIMHO allocated for this round
        uint256 claimedAmount; // total claimed so far
        uint64  startTime;
        uint64  endTime;       // claim window end (0 = no end)
        bool    active;
    }

    uint256 public currentRoundId;
    mapping(uint256 => Round) public rounds;
    mapping(uint256 => mapping(address => bool)) public hasClaimed;

    /* ============================================================
                                 EVENTS
       ============================================================ */

    event TokensDeposited(address indexed  from, uint256 amount);
    event RoundOpened(uint256 indexed roundId, bytes32 merkleRoot, uint256 totalAmount, uint64 startTime, uint64 endTime);
    event RoundClosed(uint256 indexed roundId, uint256 remainingUnclaimed);
    event Claimed(uint256 indexed roundId, address indexed  claimer, uint256 amount);
    event AddressExcluded(address indexed  addr);
    event DAOSet(address indexed  dao);
    event DAOActivated(address indexed  dao);

    /* ============================================================
                               CONSTRUCTOR
       ============================================================ */

    constructor(address registryAddress, address mimhoTokenAddress) {
        require(registryAddress != address(0), "MIMHO: registry=0");
        require(mimhoTokenAddress != address(0), "MIMHO: token=0");

        registry = IMIMHORegistry(registryAddress);
        mimhoToken = IERC20(mimhoTokenAddress);

        // Founder (owner) is excluded by default (can never claim)
        excluded[msg.sender] = true;
        emit AddressExcluded(msg.sender);

        // Best-effort HUD emission
        _emitHubEvent(ACT_EXCLUDE_ADDRESS, msg.sender, 0, abi.encode(msg.sender));
    }

    /* ============================================================
                             HUD / EVENTS HUB
       ============================================================ */

    function contractType() public pure returns (bytes32) {
        return MODULE_TYPE;
    }

    function _eventsHub() internal view returns (IMIMHOEventsHub hub) {
        address hubAddr = registry.getContract(KEY_EVENTS_HUB);
        if (hubAddr == address(0)) return IMIMHOEventsHub(address(0));
        return IMIMHOEventsHub(hubAddr);
    }

    function _emitHubEvent(bytes32 action, address caller, uint256 value, bytes memory data) internal {
        // Best-effort, never revert main logic
        IMIMHOEventsHub hub = _eventsHub();
        if (address(hub) == address(0)) return;

        try hub.emitEvent(contractType(), action, caller, value, data) {
            // ok
        } catch {
            // ignore
        }
    }

    /* ============================================================
                             ADMIN / DAO SETUP
       ============================================================ */

    function setDAO(address dao) external onlyDAOorOwner {
        require(dao != address(0), "MIMHO: dao=0");
        DAO_CONTRACT = dao;

        emit DAOSet(dao);
        _emitHubEvent(ACT_SET_DAO, msg.sender, 0, abi.encode(dao));
    }

    function activateDAO() external onlyDAOorOwner {
        require(DAO_CONTRACT != address(0), "MIMHO: dao not set");
        daoActivated = true;

        emit DAOActivated(DAO_CONTRACT);
        _emitHubEvent(ACT_ACTIVATE_DAO, msg.sender, 0, abi.encode(DAO_CONTRACT));
    }

    function pauseEmergencial() external onlyDAOorOwner {
        _pause();
        _emitHubEvent(ACT_PAUSE, msg.sender, 0, "");
    }

    function unpause() external onlyDAOorOwner {
        _unpause();
        _emitHubEvent(ACT_UNPAUSE, msg.sender, 0, "");
    }

    /* ============================================================
                               EXCLUSION MGMT
       ============================================================ */

    /// @notice Permanently excludes an address from claiming.
    /// @dev One-way operation for safety: cannot be undone.
    function excludeAddress(address addr) external onlyDAOorOwner {
        require(addr != address(0), "MIMHO: addr=0");
        require(!excluded[addr], "MIMHO: already excluded");

        excluded[addr] = true;

        emit AddressExcluded(addr);
        _emitHubEvent(ACT_EXCLUDE_ADDRESS, msg.sender, 0, abi.encode(addr));
    }

    /* ============================================================
                               FUNDING
       ============================================================ */

    /// @notice Deposit MIMHO tokens into the vault for future rounds.
    /// @dev Anyone may deposit (donations allowed). Vault remains non-custodial.
    function deposit(uint256 amount) external whenNotPaused nonReentrant {
        require(amount > 0, "MIMHO: amount=0");
        mimhoToken.safeTransferFrom(msg.sender, address(this), amount);

        emit TokensDeposited(msg.sender, amount);
        _emitHubEvent(ACT_DEPOSIT, msg.sender, amount, abi.encode(amount));
    }

    /* ============================================================
                               ROUND CONTROL
       ============================================================ */

    /// @notice Opens a new distribution round. Only one active round at a time.
    /// @param merkleRoot Merkle root encoding (claimer, amount, roundId).
    /// @param totalAmount Total amount allocated for this round.
    /// @param durationSeconds Claim window duration. Set 0 for no deadline.
    function openRound(bytes32 merkleRoot, uint256 totalAmount, uint64 durationSeconds)
        external
        onlyDAOorOwner
        whenNotPaused
    {
        require(merkleRoot != bytes32(0), "MIMHO: root=0");
        require(totalAmount > 0, "MIMHO: total=0");

        Round storage cur = rounds[currentRoundId];
        require(!cur.active, "MIMHO: active round");

        // Ensure vault has enough funds for this round (no admin withdraw exists)
        uint256 bal = mimhoToken.balanceOf(address(this));
        require(bal >= totalAmount, "MIMHO: insufficient vault balance");

        currentRoundId += 1;

        uint64 start = uint64(block.timestamp);
        uint64 end = durationSeconds == 0 ? uint64(0) : uint64(block.timestamp + durationSeconds);

        rounds[currentRoundId] = Round({
            merkleRoot: merkleRoot,
            totalAmount: totalAmount,
            claimedAmount: 0,
            startTime: start,
            endTime: end,
            active: true
        });

        emit RoundOpened(currentRoundId, merkleRoot, totalAmount, start, end);
        _emitHubEvent(ACT_ROUND_OPEN, msg.sender, totalAmount, abi.encode(currentRoundId, merkleRoot, totalAmount, start, end));
    }

    /// @notice Closes the current round (does not move funds).
    /// @dev Unclaimed tokens remain in the vault and can be used in future rounds.
    function closeRound() external onlyDAOorOwner whenNotPaused {
        Round storage r = rounds[currentRoundId];
        require(r.active, "MIMHO: no active round");

        r.active = false;

        uint256 remaining = r.totalAmount - r.claimedAmount;

        emit RoundClosed(currentRoundId, remaining);
        _emitHubEvent(ACT_ROUND_CLOSE, msg.sender, remaining, abi.encode(currentRoundId, remaining));
    }

    /* ============================================================
                                CLAIM
       ============================================================ */

    /// @notice Claims allocation for the caller in the active round.
    /// @param amount Amount assigned to msg.sender in the Merkle tree.
    /// @param proof Merkle proof for (msg.sender, amount, roundId).
    function claim(uint256 amount, bytes32[] calldata proof)
        external
        whenNotPaused
        nonReentrant
    {
        Round storage r = rounds[currentRoundId];
        require(r.active, "MIMHO: no active round");
        require(amount > 0, "MIMHO: amount=0");
        require(!excluded[msg.sender], "MIMHO: excluded");
        require(!registry.isEcosystemContract(msg.sender), "MIMHO: ecosystem contract");
        require(!hasClaimed[currentRoundId][msg.sender], "MIMHO: already claimed");

        if (r.endTime != 0) {
            require(block.timestamp <= r.endTime, "MIMHO: round ended");
        }

        // Leaf binds claim to this specific roundId (prevents proof reuse across rounds)
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(msg.sender, amount, currentRoundId))));
        require(MerkleProof.verify(proof, r.merkleRoot, leaf), "MIMHO: invalid proof");

        // Prevent over-claim
        require(r.claimedAmount + amount <= r.totalAmount, "MIMHO: exceeds round total");

        hasClaimed[currentRoundId][msg.sender] = true;
        r.claimedAmount += amount;

        mimhoToken.safeTransfer(msg.sender, amount);

        emit Claimed(currentRoundId, msg.sender, amount);
        _emitHubEvent(ACT_CLAIM, msg.sender, amount, abi.encode(currentRoundId, msg.sender, amount));
    }

    /* ============================================================
                               VIEWS
       ============================================================ */

    function getRound(uint256 roundId)
        external
        view
        returns (
            bytes32 merkleRoot,
            uint256 totalAmount,
            uint256 claimedAmount,
            uint64 startTime,
            uint64 endTime,
            bool active,
            uint256 remaining
        )
    {
        Round storage r = rounds[roundId];
        merkleRoot = r.merkleRoot;
        totalAmount = r.totalAmount;
        claimedAmount = r.claimedAmount;
        startTime = r.startTime;
        endTime = r.endTime;
        active = r.active;
        remaining = (r.totalAmount >= r.claimedAmount) ? (r.totalAmount - r.claimedAmount) : 0;
    }

    function vaultBalance() external view returns (uint256) {
        return mimhoToken.balanceOf(address(this));
    }
}
>>>>>>> fe7ced1 (Add official deployed MIMHO contracts with BscScan headers)
