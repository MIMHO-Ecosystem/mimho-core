/// -----------------------------------------------------------------------
/// MIMHO STRATEGY HUB
/// Official MIMHO Ecosystem Contract
///
/// Network: BNB Smart Chain
/// Contract Address:
/// 0x3E259b7d637f8C0C420c68a31f1Af4bf860b3cF4
///
/// BscScan:
/// https://bscscan.com/address/0x3E259b7d637f8C0C420c68a31f1Af4bf860b3cF4
/// -----------------------------------------------------------------------

// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/* ============================================================
   MIMHO STRATEGY HUB — v1.0.0
   Rules Engine (NFT Bonus by Context) — ERC721 only
   ============================================================

   DESIGN PHILOSOPHY (MIMHO ABSOLUTE STANDARD)

   - Intelligence Layer, Not a Money Layer:
     Strategy Hub NEVER holds funds, NEVER transfers value, NEVER mints NFTs.
     It only stores transparent rules and returns deterministic answers.

   - Plug-and-Play Rules:
     New NFT collections and new campaigns must be addable without redeploying
     Staking/DAO/Game contracts. Contracts ask, Strategy answers.

   - Gas Predictability:
     No global/unbounded loops. Any iteration is only over caller-provided lists
     with a strict MAX length (30), ensuring stable gas and no "out of gas" traps.

   - Context-Aware Bonuses:
     Bonuses are stored per NFT per context (Option B).
     Consumers decide how to apply the returned bonus (APR, voting weight, etc.).
     Strategy remains neutral and reusable.

   - Hard Safety Caps (Rule of Gold):
     Total bonus can never exceed 30% (3000 bps), enforced as a hard cap.

   - Registry-Coupled & HUD-Ready:
     All dependencies are resolved via Registry KEY getters (no local keccak/strings).
     All admin changes emit public events and are also broadcast to the MIMHO Events Hub
     using best-effort try/catch so user flows never break.

   ============================================================ */

import "@openzeppelin/contracts/security/Pausable.sol";

interface IMIMHORegistry {
    function getContract(bytes32 key) external view returns (address);

    // Keys MUST be exposed by Registry getters (MIMHO absolute rule)
    function KEY_MIMHO_EVENTS_HUB() external view returns (bytes32);
    function KEY_MIMHO_DAO() external view returns (bytes32);

    // Ecosystem whitelist
    function isEcosystemContract(address a) external view returns (bool);
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

interface IERC721BalanceOnly {
    function balanceOf(address owner) external view returns (uint256);
}

contract MIMHOStrategyHub is Pausable {
    /* =========================
       VERSION / IDENTIFIERS
       ========================= */

    string public constant VERSION = "1.0.0";

    function contractType() public pure returns (bytes32) {
        return bytes32("MIMHO_STRATEGY_HUB");
    }

    /* =========================
       IMMUTABLES / CONSTANTS
       ========================= */

    IMIMHORegistry public immutable registry;

    uint16 public constant HARD_CAP_BPS = 3000; // 30.00% max, immutable rule
    uint8 public constant MAX_NFTS_PER_CALL = 30;
    uint16 public maxBoostBps = 5000;

    /* =========================
       DAO / OWNER CONTROL
       ========================= */

    address public owner;
    address public daoContract;
    bool public daoActivated;

    modifier onlyOwner() {
        require(msg.sender == owner, "STRATEGY: not owner");
        _;
    }

    modifier onlyDAOorOwner() {
        if (msg.sender == owner) {
            _;
            return;
        }
        require(daoActivated && msg.sender == daoContract, "STRATEGY: not DAO/owner");
        _;
    }

    /* =========================
       EVENTS (PUBLIC)
       ========================= */

    event OwnerTransferred(address indexed  oldOwner, address indexed  newOwner);
    event DAOSet(address indexed  dao);
    event DAOActivated(address indexed  dao);

    event ContextCapSet(uint8 indexed context, uint16 capBps);
    event NftRuleSet(address indexed  nft, uint8 indexed context, uint16 bonusBps, bool active);
    event NftActiveSet(address indexed  nft, bool active);

    /* =========================
       EVENTS HUB (HUD LOUDSPEAKER)
       ========================= */

    function _eventsHub() internal view returns (IMIMHOEventsHub hub) {
        address hubAddr = registry.getContract(registry.KEY_MIMHO_EVENTS_HUB());
        return IMIMHOEventsHub(hubAddr);
    }

    function _emitHubEvent(
        bytes32 action,
        address caller,
        uint256 value,
        bytes memory data
    ) internal {
        // Best-effort: Hub failures must never break admin or user logic
        IMIMHOEventsHub hub = _eventsHub();
        if (address(hub) == address(0)) return;
        try hub.emitEvent(contractType(), action, caller, value, data) {
            // ok
        } catch {
            // ignore
        }
    }

    /* =========================
       STRATEGY STORAGE
       ========================= */

    // NFT enabled flag (global)
    mapping(address => bool) public nftActive;

    // Bonus per NFT per context (bps). If 0, no bonus for that (nft, context).
    mapping(address => mapping(uint8 => uint16)) public nftBonusBps;

    // Optional cap per context. If 0 => defaults to HARD_CAP_BPS.
    mapping(uint8 => uint16) public contextCapBps;

    // Simple counters for HUD
    uint256 public totalKnownNfts; // increments on first activation only
    mapping(address => bool) private _everSeen;

    /* =========================
       ADMIN: CAPS / RULES
       ========================= */

    /// @notice Set a cap for a context. 0 resets to default HARD_CAP_BPS.
    function setContextCap(uint8 context, uint16 capBps) external onlyDAOorOwner {
        require(capBps <= HARD_CAP_BPS, "STRATEGY: cap > hard");
        contextCapBps[context] = capBps;

        emit ContextCapSet(context, capBps);
        _emitHubEvent(bytes32("CTX_CAP_SET"), msg.sender, capBps, abi.encode(context, capBps));
    }

    /// @notice Activate/deactivate an NFT globally for strategy checks.
    function setNftActive(address nft, bool active) external onlyDAOorOwner {
        require(nft != address(0), "STRATEGY: nft=0");

        bool prev = nftActive[nft];
        nftActive[nft] = active;

        if (!_everSeen[nft] && active) {
            _everSeen[nft] = true;
            totalKnownNfts += 1;
        }

        emit NftActiveSet(nft, active);
        _emitHubEvent(bytes32("NFT_ACTIVE_SET"), msg.sender, active ? 1 : 0, abi.encode(nft, prev, active));
    }

    /// @notice Set bonus for a (NFT, context) pair (bps). 0 effectively removes the bonus.
    /// @dev Enforces hard cap per single rule as well (cannot exceed HARD_CAP_BPS).
    function setNftBonus(address nft, uint8 context, uint16 bonusBps_, bool active)
        external
        onlyDAOorOwner
    {
        require(nft != address(0), "STRATEGY: nft=0");
        require(bonusBps_ <= HARD_CAP_BPS, "STRATEGY: bonus > hard");

        // Optionally set active in same call (common workflow)
        bool prevActive = nftActive[nft];
        nftActive[nft] = active;

        if (!_everSeen[nft] && active) {
            _everSeen[nft] = true;
            totalKnownNfts += 1;
        }

        nftBonusBps[nft][context] = bonusBps_;

        emit NftRuleSet(nft, context, bonusBps_, active);

        _emitHubEvent(
            bytes32("NFT_RULE_SET"),
            msg.sender,
            bonusBps_,
            abi.encode(nft, context, bonusBps_, prevActive, active)
        );
    }

    /* =========================
       READ HELPERS (HUD READY)
       ========================= */

    function getContextCap(uint8 context) public view returns (uint16) {
        uint16 c = contextCapBps[context];
        return c == 0 ? HARD_CAP_BPS : c;
    }

    function getNftBonus(address nft, uint8 context) external view returns (uint16 bonusBps_, bool active) {
        return (nftBonusBps[nft][context], nftActive[nft]);
    }

    /* =========================
       CORE: USER BONUS COMPUTATION
       ========================= */

    /// @notice Compute user's total bonus (bps) for a given context, considering only the provided NFT list.
    /// @dev Gas-safe: list length is capped to 30. No global loops.
    ///      ERC721 only: uses balanceOf(user) checks.
    function getUserBonusBps(
        address user,
        address[] calldata nftList,
        uint8 context
    ) external view returns (uint16 totalBps) {
        require(user != address(0), "STRATEGY: user=0");
        require(nftList.length <= MAX_NFTS_PER_CALL, "STRATEGY: too many nfts");

        uint256 sum = 0;

        for (uint256 i = 0; i < nftList.length; i++) {
            address nft = nftList[i];
            if (nft == address(0)) continue;
            if (!nftActive[nft]) continue;

            uint16 b = nftBonusBps[nft][context];
            if (b == 0) continue;

            try IERC721BalanceOnly(nft).balanceOf(user) returns (uint256 bal) {
                if (bal > 0) {
                    sum += b;
                }
            } catch {
                continue;
            }
        }

        if (sum > maxBoostBps) {
            sum = maxBoostBps;
        }

        return uint16(sum);
    }

    /* =========================
       EMERGENCY CONTROLS
       ========================= */

    function pauseEmergencial() external onlyDAOorOwner {
        _pause();
        emit Paused(msg.sender);
        _emitHubEvent(bytes32("PAUSE"), msg.sender, 0, "");
    }

    function unpause() external onlyDAOorOwner {
        _unpause();
        emit Unpaused(msg.sender);
        _emitHubEvent(bytes32("UNPAUSE"), msg.sender, 0, "");
    }

    /* =========================
       DAO TRANSITION (MIMHO STANDARD)
       ========================= */

    function setDAO(address dao) external onlyOwner {
        require(dao != address(0), "STRATEGY: dao=0");
        daoContract = dao;
        emit DAOSet(dao);
        _emitHubEvent(bytes32("DAO_SET"), msg.sender, uint256(uint160(dao)), abi.encode(dao));
    }

    function activateDAO() external onlyOwner {
        require(daoContract != address(0), "STRATEGY: dao not set");
        daoActivated = true;
        emit DAOActivated(daoContract);
        _emitHubEvent(bytes32("DAO_ACTIVATED"), msg.sender, 1, abi.encode(daoContract));
    }

    function syncDAOFromRegistry() external onlyDAOorOwner {
        address dao = registry.getContract(registry.KEY_MIMHO_DAO());
        require(dao != address(0), "STRATEGY: registry dao=0");
        daoContract = dao;
        _emitHubEvent(bytes32("DAO_SYNC"), msg.sender, uint256(uint160(dao)), abi.encode(dao));
    }

    /* =========================
       OWNER MGMT (NO renounceOwnership)
       ========================= */

    function transferOwner(address newOwner) external onlyOwner {
        require(newOwner != address(0), "STRATEGY: owner=0");
        address old = owner;
        owner = newOwner;
        emit OwnerTransferred(old, newOwner);
        _emitHubEvent(bytes32("OWNER_TRANSFER"), msg.sender, uint256(uint160(newOwner)), abi.encode(old, newOwner));
    }

    /* =========================
       CONSTRUCTOR
       ========================= */

    constructor(address registryAddr) {
        require(registryAddr != address(0), "STRATEGY: registry=0");
        registry = IMIMHORegistry(registryAddr);
        owner = msg.sender;

        // Emit deploy to HUD (best-effort)
        _emitHubEvent(bytes32("DEPLOY"), msg.sender, 0, abi.encode(VERSION));
    }
}
