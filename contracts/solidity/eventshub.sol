/// -----------------------------------------------------------------------
/// MIMHO EVENTS HUB
/// Official MIMHO Ecosystem Contract
///
/// Network: BNB Smart Chain
/// Contract Address:
/// 0xC4A934CBb3A507e295d2D84C25A6Ed7437C36E42
///
/// BscScan:
/// https://bscscan.com/address/0xC4A934CBb3A507e295d2D84C25A6Ed7437C36E42
/// -----------------------------------------------------------------------

// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/* ============================================================
   MIMHO EVENTS HUB — v1.0.0 (Registry-Coupled, Ecosystem-Only)
   ============================================================

   DESIGN PHILOSOPHY (MIMHO ABSOLUTE STANDARD)

   - Radical Transparency:
     The Hub is the canonical, immutable on-chain feed for the MIMHO HUD.
     If it happened in the ecosystem, it can be emitted here.

   - Zero Business Logic:
     No tokenomics, no funds, no rules execution. Only emits facts.

   - Ecosystem-Only Emission (Hard Security):
     Only (a) the MIMHO Registry itself OR (b) contracts whitelisted by
     Registry.isEcosystemContract(msg.sender) can emit.
     EOAs are always blocked.

   - Never Block Users:
     The Hub can revert freely on invalid emits. Ecosystem contracts must
     call it using try/catch (best-effort) so user transactions never break.

   - Multi-chain Native:
     One Hub per chain, same ABI, same event shape. Includes timestamp+chainId.

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

interface IMIMHORegistry {
    function isEcosystemContract(address a) external view returns (bool);
}

/* Optional (fits your Camada 1–4 expectations) */
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

contract MIMHOEventsHub is IMIMHOEventsHub, IMIMHOProtocol {
    /* ============================================================
                                CONSTANTS
       ============================================================ */

    bytes32 public constant CONTRACT_TYPE = keccak256("MIMHO_EVENTS_HUB");
    bytes32 public constant ACTION_TYPE   = keccak256("ECOSYSTEM_EVENT");
    uint8  public constant RISK_LEVEL     = 1; // low risk infra (no funds)

    string public constant HUB_VERSION    = "1.0.0";

    // ============================================================
    // GAS GUARD (PAYLOAD LIMIT)
    // ============================================================
    // Hard cap on bytes payload in HubEvent to prevent out-of-gas issues
    // caused by oversized calldata payloads (attack or bug).
    uint256 public constant MAX_EVENT_DATA_BYTES = 1024;

    /* ============================================================
                                STATE
       ============================================================ */

    // Admin (NOT allowed to emit HUD events directly)
    address public immutable owner;
    address public dao;
    bool public daoActivated;

    IMIMHORegistry public registry;

    bool private _paused;

    // Emergency denylist for emitters (contracts)
    mapping(address => bool) public blacklistedEmitters;

    uint256 public immutable deployedAt;

    /* ============================================================
                                EVENTS
       ============================================================ */

    /// @notice Universal ecosystem event (HUD feed)
    event HubEvent(
        uint256 indexed timestamp,
        uint256 indexed chainId,
        bytes32 indexed module,
        bytes32 action,
        address origin,  // msg.sender (emitter contract)
        address caller,  // actor (user/operator)
        uint256 value,   // amount/score/etc
        bytes data       // ABI-encoded payload
    );

    // ✅ Gas Guard telemetry (public)
    event PayloadTruncated(
        uint256 indexed timestamp,
        uint256 indexed chainId,
        bytes32 indexed module,
        bytes32 action,
        address origin,
        address caller,
        uint256 value,
        uint256 originalLength,
        uint256 keptLength
    );

    // Admin events (public)
    event OwnerSet(address indexed  owner);
    event DAOSet(address indexed  dao);
    event DAOActivated(address indexed  dao);
    event RegistryUpdated(address indexed  oldRegistry, address indexed  newRegistry);
    event Paused();
    event Unpaused();
    event EmitterBlacklisted(address indexed  emitter, bool status);

    /* ============================================================
                              MODIFIERS
       ============================================================ */

    modifier onlyDAOorOwner() {
        if (daoActivated) {
            require(msg.sender == dao, "MIMHO: DAO only");
        } else {
            require(msg.sender == owner, "MIMHO: owner only");
        }
        _;
    }

    modifier whenNotPaused() {
        require(!_paused, "MIMHO: paused");
        _;
    }

    /// ✅ Guarantee #1: blocks EOAs and enforces ecosystem-only emission
    /// ✅ Guarantee #2: explicitly allows Registry itself even if not whitelisted
    modifier onlyEcosystemEmitter() {
        require(msg.sender.code.length > 0, "MIMHO: EOA blocked");
        require(!blacklistedEmitters[msg.sender], "MIMHO: emitter blacklisted");

        require(
            msg.sender == address(registry) || registry.isEcosystemContract(msg.sender),
            "MIMHO: NOT_ECOSYSTEM"
        );
        _;
    }

    /* ============================================================
                             CONSTRUCTOR
       ============================================================ */

    constructor(address founderSafeOwner, address registryAddress) {
        require(founderSafeOwner != address(0), "MIMHO: zero owner");
        require(registryAddress != address(0), "MIMHO: zero registry");

        owner = founderSafeOwner;
        registry = IMIMHORegistry(registryAddress);
        deployedAt = block.timestamp;

        emit OwnerSet(founderSafeOwner);
        emit RegistryUpdated(address(0), registryAddress);
    }

    /* ============================================================
                      INTERNAL: CLIP CALLDATA (GAS GUARD)
       ============================================================ */

    function _clipCalldata(bytes calldata input, uint256 maxLen)
        internal
        pure
        returns (bytes memory out, uint256 originalLen, bool clipped)
    {
        originalLen = input.length;
        if (originalLen <= maxLen) {
            // Return a copy (event needs bytes memory anyway)
            out = input;
            return (out, originalLen, false);
        }

        clipped = true;
        out = new bytes(maxLen);

        // Copy only the first maxLen bytes from calldata -> memory
        assembly {
            calldatacopy(add(out, 32), input.offset, maxLen)
        }
    }

    /* ============================================================
                     CORE FUNCTION (CANONICAL SIGNATURE)
       ============================================================ */

    /// ✅ Guarantee #3: signature matches your Registry interface exactly
    function emitEvent(
        bytes32 module,
        bytes32 action,
        address caller,
        uint256 value,
        bytes calldata data
    )
        external
        whenNotPaused
        onlyEcosystemEmitter
    {
        require(module != bytes32(0), "MIMHO: invalid module");
        require(action != bytes32(0), "MIMHO: invalid action");
        require(caller != address(0), "MIMHO: invalid caller");

        // ✅ GAS GUARD: truncate payload if too large
        (bytes memory safeData, uint256 originalLen, bool wasClipped) =
            _clipCalldata(data, MAX_EVENT_DATA_BYTES);

        if (wasClipped) {
            emit PayloadTruncated(
                block.timestamp,
                block.chainid,
                module,
                action,
                msg.sender,
                caller,
                value,
                originalLen,
                MAX_EVENT_DATA_BYTES
            );
        }

        emit HubEvent(
            block.timestamp,
            block.chainid,
            module,
            action,
            msg.sender,
            caller,
            value,
            safeData
        );
    }

    /* ============================================================
                          ADMIN / GOVERNANCE (NO EMIT)
       ============================================================ */

    function setDAO(address _dao) external onlyDAOorOwner {
        require(_dao != address(0), "MIMHO: zero dao");
        require(dao == address(0), "MIMHO: dao already set");
        dao = _dao;
        emit DAOSet(_dao);
    }

    function activateDAO() external onlyDAOorOwner {
        require(dao != address(0), "MIMHO: dao not set");
        require(!daoActivated, "MIMHO: dao already active");
        daoActivated = true;
        emit DAOActivated(dao);
    }

    function pauseEmergencial() external onlyDAOorOwner {
        _paused = true;
        emit Paused();
    }

    function unpause() external onlyDAOorOwner {
        _paused = false;
        emit Unpaused();
    }

    function updateRegistry(address newRegistry) external onlyDAOorOwner {
        require(newRegistry != address(0), "MIMHO: zero registry");
        address old = address(registry);
        registry = IMIMHORegistry(newRegistry);
        emit RegistryUpdated(old, newRegistry);
    }

    function blacklistEmitter(address emitter, bool status) external onlyDAOorOwner {
        require(emitter != address(0), "MIMHO: zero emitter");
        blacklistedEmitters[emitter] = status;
        emit EmitterBlacklisted(emitter, status);
    }

    /* ============================================================
                          VIEW BUTTONS
       ============================================================ */

    function paused() external view override returns (bool) {
        return _paused;
    }

    function canEmit(address emitter) external view returns (bool) {
        if (_paused) return false;
        if (emitter.code.length == 0) return false;
        if (blacklistedEmitters[emitter]) return false;

        if (emitter == address(registry)) return true;
        return registry.isEcosystemContract(emitter);
    }

    function hubStatus()
        external
        view
        returns (
            address ownerAddress,
            address daoAddress,
            bool isDAOActive,
            address registryAddress,
            bool isPaused,
            uint256 deployedTimestamp,
            uint256 chainId,
            string memory ver
        )
    {
        return (
            owner,
            dao,
            daoActivated,
            address(registry),
            _paused,
            deployedAt,
            block.chainid,
            HUB_VERSION
        );
    }

    /* ============================================================
                     IMIMHOProtocol — REQUIRED VIEWS
       ============================================================ */

    function contractName() external pure override returns (string memory) {
        return "MIMHO Events Hub";
    }

    function contractType() external pure override returns (bytes32) {
        return CONTRACT_TYPE;
    }

    function version() external pure override returns (string memory) {
        return HUB_VERSION;
    }

    function isObservable() external pure override returns (bool) {
        return true;
    }

    function getActionType() external pure override returns (bytes32) {
        return ACTION_TYPE;
    }

    function getRiskLevel() external pure override returns (uint8) {
        return RISK_LEVEL;
    }

    function isFinalized() external view override returns (bool) {
        return false;
    }

    function getFinancialImpact(address)
        external
        pure
        override
        returns (uint256 volumeIn, uint256 volumeOut, uint256 lockedValue)
    {
        return (0, 0, 0);
    }

    function getBoostValue(address) external pure override returns (uint256) {
        return 0;
    }

    function onExternalAction(address, bytes32) external pure override {
        // no-op (future hook)
    }
}
