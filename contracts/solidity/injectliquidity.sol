<<<<<<< HEAD
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

abstract contract MIMHO Inject Liquidity {
    string public constant version = "0.0.0-placeholder";
    function contractType() public pure virtual returns (bytes32) { return keccak256("MIMHO_INJECT_LIQUIDITY"); }
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
abstract contract MIMHO Inject Liquidity {
    /// @notice Human readable version for repository tracking (not on-chain guarantee).
    string public constant version = "0.0.0-placeholder";

    /// @notice Contract module type identifier (used by HUD/Events Hub in final builds).
    function contractType() public pure virtual returns (bytes32) {
        return CONTRACT_TYPE;
    }
}
=======
/// -----------------------------------------------------------------------
/// MIMHO INJECT LIQUIDITY
/// Official MIMHO Ecosystem Contract
///
/// Network: BNB Smart Chain
/// Contract Address:
/// 0xa993637732A47fb2AEDfF26bC0909494eCed395e
///
/// BscScan:
/// https://bscscan.com/address/0xa993637732A47fb2AEDfF26bC0909494eCed395e
/// -----------------------------------------------------------------------

// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/* ============================================================
   MIMHO INJECT LIQUIDITY — v1.0.0 (Protocolo Absoluto MIMHO)
   ============================================================

   DESIGN PHILOSOPHY (MIMHO ABSOLUTE STANDARD)
   - Single responsibility: custody MIMHO destined to future liquidity and
     inject LP only when authorized + rate-limited.
   - Governance-light pre-DAO: Voting Controller authorizes (setAutoInject),
     Inject executes with hard brakes (cooldown + 1-shot auto-disable).
   - Fail-safe, not fail-open: no withdrawals of MIMHO, no swaps.
   - HUD-ready: public view endpoints + local events + Events Hub (best-effort).
   - Registry-first: all dependencies resolved via Registry KEY getters.

   SECURITY NOTE
   - This contract NEVER swaps/sells MIMHO.
   - MIMHO can only leave via Router.addLiquidityETH(), minting LP directly to burn.

   ============================================================ */

interface IERC20 {
    function balanceOf(address a) external view returns (uint256);
    function transfer(address to, uint256 v) external returns (bool);
    function transferFrom(address f, address t, uint256 v) external returns (bool);
    function approve(address s, uint256 v) external returns (bool);
    function allowance(address o, address s) external view returns (uint256);
}

interface IUniswapV2Router02 {
    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
        external
        payable
        returns (uint256 amountToken, uint256 amountETH, uint256 liquidity);
}

/* =========================
   REGISTRY + EVENTS HUB
   ========================= */

interface IMIMHORegistry {
    function getContract(bytes32 key) external view returns (address);

    // ✅ Protocolo Absoluto: usar getters KEY_... do próprio Registry
    function KEY_MIMHO_EVENTS_HUB() external view returns (bytes32);
    function KEY_MIMHO_TOKEN() external view returns (bytes32);

    // ✅ FIX: nomes reais do seu Registry
    function KEY_MIMHO_DEX() external view returns (bytes32);
    function KEY_MIMHO_DAO() external view returns (bytes32);
    function KEY_MIMHO_VOTING_CONTROLLER() external view returns (bytes32);
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

/* =========================
   OZ-lite: Ownable2Step-ish
   ========================= */
abstract contract Ownable2StepLite {
    address public owner;
    address public pendingOwner;

    event OwnershipTransferStarted(address indexed  previousOwner, address indexed  newOwner);
    event OwnershipTransferred(address indexed  previousOwner, address indexed  newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "OWN: not owner");
        _;
    }

    constructor(address initialOwner) {
        require(initialOwner != address(0), "OWN: zero");
        owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "OWN: zero");
        pendingOwner = newOwner;
        emit OwnershipTransferStarted(owner, newOwner);
    }

    function acceptOwnership() external {
        require(msg.sender == pendingOwner, "OWN: not pending");
        address old = owner;
        owner = pendingOwner;
        pendingOwner = address(0);
        emit OwnershipTransferred(old, owner);
    }
}

abstract contract ReentrancyGuardLite {
    uint256 private _status = 1;
    modifier nonReentrant() {
        require(_status == 1, "REENTRANCY");
        _status = 2;
        _;
        _status = 1;
    }
}

abstract contract PausableLite {
    bool public paused;

    event Paused(address indexed  caller);
    event Unpaused(address indexed  caller);

    modifier whenNotPaused() {
        require(!paused, "PAUSED");
        _;
    }

    function _pause() internal {
        if (!paused) {
            paused = true;
            emit Paused(msg.sender);
        }
    }

    function _unpause() internal {
        if (paused) {
            paused = false;
            emit Unpaused(msg.sender);
        }
    }
}

/* ============================================================
   MIMHO Inject Liquidity
   ============================================================ */
contract MIMHOInjectLiquidity is Ownable2StepLite, ReentrancyGuardLite, PausableLite {
    /* -------------------------
       MIMHO Constants
       ------------------------- */
    string public constant NAME = "MIMHO Inject Liquidity";
    string public constant VERSION = "1.0.0";

    // LP burn address (BSC-friendly)
    address public constant LP_BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    uint256 public constant MIN_INJECTION_COOLDOWN = 1 days;
    uint256 public constant MAX_INJECTION_COOLDOWN = 45 days;

    uint256 public constant MIN_FAILSAFE_DELAY = 7 days;
    uint256 public constant MAX_FAILSAFE_DELAY = 365 days;

    /* -------------------------
       Registry / Governance
       ------------------------- */
    IMIMHORegistry public immutable registry;

    // DAO lifecycle (MIMHO pattern)
    address public dao;
    bool public daoActivated;

    /* -------------------------
       Authorization + Rate Limit
       ------------------------- */
    bool public autoInjectEnabled;          // ✅ required by controller
    uint256 public injectionCooldown;       // ✅ required
    uint256 public lastInjectionTimestamp;  // ✅ required

    uint256 public failsafeDelay;           // ✅ required
    uint256 public lastActivityTimestamp;   // ✅ required

    /* -------------------------
       Accounting (HUD)
       ------------------------- */
    uint256 public totalInjectedToken;
    uint256 public totalInjectedBNB;
    uint256 public totalLPBurned;

    /* -------------------------
       Events (local)
       ------------------------- */
    event AutoInjectStatusChanged(bool enabled, address indexed caller);
    event InjectionExecuted(
        uint256 amountToken,
        uint256 amountBNB,
        uint256 lpMinted,
        uint256 timestamp,
        address indexed caller
    );
    event InjectionCooldownChanged(uint256 newCooldown, address indexed caller);
    event FailsafeTriggered(uint256 timestamp, address indexed caller);
    event FailsafeDelayChanged(uint256 newDelay, address indexed caller);
    event LastInjectionUpdated(uint256 timestamp, address indexed caller);

    event TokensDeposited(address indexed  from, uint256 amount);
    event ReceivedBNB(address indexed  from, uint256 amount);

    event DAOSet(address indexed  dao);
    event DAOActivated(address indexed  dao);

    event EmergencyPaused(address indexed  caller);
    event EmergencyUnpaused(address indexed  caller);

    event RecoveredERC20(address indexed  token, address indexed  to, uint256 amount);

    /* -------------------------
       Hub Actions (bytes32)
       ------------------------- */
    bytes32 private constant ACT_AUTO_INJECT_CHANGED = keccak256("AUTO_INJECT_CHANGED");
    bytes32 private constant ACT_INJECTION_EXECUTED = keccak256("INJECTION_EXECUTED");
    bytes32 private constant ACT_COOLDOWN_CHANGED   = keccak256("COOLDOWN_CHANGED");
    bytes32 private constant ACT_FAILSAFE_TRIGGERED = keccak256("FAILSAFE_TRIGGERED");
    bytes32 private constant ACT_FAILSAFE_CHANGED   = keccak256("FAILSAFE_DELAY_CHANGED");
    bytes32 private constant ACT_DEPOSIT            = keccak256("TOKENS_DEPOSITED");
    bytes32 private constant ACT_RECEIVE_BNB        = keccak256("RECEIVED_BNB");
    bytes32 private constant ACT_PAUSE              = keccak256("PAUSE");
    bytes32 private constant ACT_UNPAUSE            = keccak256("UNPAUSE");
    bytes32 private constant ACT_DAO_SET            = keccak256("DAO_SET");
    bytes32 private constant ACT_DAO_ACTIVATED      = keccak256("DAO_ACTIVATED");
    bytes32 private constant ACT_RECOVER_ERC20      = keccak256("RECOVER_ERC20");

    /* -------------------------
       Modifiers
       ------------------------- */
    modifier onlyDAOorOwner() {
        if (daoActivated) {
            require(msg.sender == dao, "AUTH: DAO only");
        } else {
            require(msg.sender == owner, "AUTH: owner only");
        }
        _;
    }

    modifier onlyVotingControllerOrDAOorOwner() {
        address vc = _votingController();
        if (daoActivated) {
            require(msg.sender == dao, "AUTH: DAO only");
        } else {
            require(msg.sender == vc || msg.sender == owner, "AUTH: VC/owner");
        }
        _;
    }

    /* -------------------------
       Constructor
       ------------------------- */
    constructor(address registryAddr, address initialOwner) Ownable2StepLite(initialOwner) {
        require(registryAddr != address(0), "REG: zero");
        registry = IMIMHORegistry(registryAddr);

        // sensible defaults (can be adjusted by DAO/Owner within bounds)
        injectionCooldown = 7 days;
        failsafeDelay = 180 days;

        // Initialize activity to deployment time to avoid immediate failsafe spam
        lastActivityTimestamp = block.timestamp;
    }

    /* -------------------------
       MIMHO Identity Helpers
       ------------------------- */
    function icontratoMimho() external pure returns (string memory) {
        return "icontratoMimho";
    }

    function contractType() public pure returns (bytes32) {
        return keccak256("MIMHO_INJECT_LIQUIDITY");
    }

    function version() external pure returns (string memory) {
        return VERSION;
    }

    /* -------------------------
       Receive BNB
       ------------------------- */
    receive() external payable {
        _touch();
        emit ReceivedBNB(msg.sender, msg.value);
        _emitHubEvent(ACT_RECEIVE_BNB, msg.sender, msg.value, "");
    }

    /* -------------------------
       DAO Lifecycle (MIMHO)
       ------------------------- */
    function setDAO(address daoAddr) external onlyOwner {
        require(daoAddr != address(0), "DAO: zero");
        dao = daoAddr;
        emit DAOSet(daoAddr);
        _emitHubEvent(ACT_DAO_SET, msg.sender, uint256(uint160(daoAddr)), "");
    }

    function activateDAO() external onlyOwner {
        require(dao != address(0), "DAO: not set");
        daoActivated = true;
        emit DAOActivated(dao);
        _emitHubEvent(ACT_DAO_ACTIVATED, msg.sender, uint256(uint160(dao)), "");
    }

    /* -------------------------
       Admin: pauseEmergencial / unpause
       ------------------------- */
    function pauseEmergencial() external onlyDAOorOwner {
        _pause();
        emit EmergencyPaused(msg.sender);
        _emitHubEvent(ACT_PAUSE, msg.sender, 1, "");
    }

    function unpause() external onlyDAOorOwner {
        _unpause();
        emit EmergencyUnpaused(msg.sender);
        _emitHubEvent(ACT_UNPAUSE, msg.sender, 0, "");
    }

    /* -------------------------
       Inject Controller Hooks
       ------------------------- */

    /// ✅ Required by your checklist (Voting Controller calls this)
    function setAutoInject(bool enabled) external onlyVotingControllerOrDAOorOwner {
        autoInjectEnabled = enabled;
        _touch();

        emit AutoInjectStatusChanged(enabled, msg.sender);
        _emitHubEvent(ACT_AUTO_INJECT_CHANGED, msg.sender, enabled ? 1 : 0, "");
    }

    /// ✅ HUD view endpoint already present via public var autoInjectEnabled()

    function setInjectionCooldown(uint256 newCooldown) external onlyDAOorOwner {
        require(newCooldown >= MIN_INJECTION_COOLDOWN, "COOLDOWN: too low");
        require(newCooldown <= MAX_INJECTION_COOLDOWN, "COOLDOWN: too high");
        injectionCooldown = newCooldown;
        _touch();

        emit InjectionCooldownChanged(newCooldown, msg.sender);
        _emitHubEvent(ACT_COOLDOWN_CHANGED, msg.sender, newCooldown, "");
    }

    function setFailsafeDelay(uint256 newDelay) external onlyDAOorOwner {
        require(newDelay >= MIN_FAILSAFE_DELAY, "FAILSAFE: too low");
        require(newDelay <= MAX_FAILSAFE_DELAY, "FAILSAFE: too high");
        failsafeDelay = newDelay;
        _touch();

        emit FailsafeDelayChanged(newDelay, msg.sender);
        _emitHubEvent(ACT_FAILSAFE_CHANGED, msg.sender, newDelay, "");
    }

    /// ✅ Public failsafe trigger (anyone can call)
    function triggerFailsafe() external whenNotPaused {
        require(block.timestamp >= lastActivityTimestamp + failsafeDelay, "FAILSAFE: not available");

        // Authorize one injection. Cooldown still applies at execution level.
        autoInjectEnabled = true;
        _touch();

        emit FailsafeTriggered(block.timestamp, msg.sender);
        _emitHubEvent(ACT_FAILSAFE_TRIGGERED, msg.sender, block.timestamp, "");
    }

    /* -------------------------
       Deposits (tokens)
       ------------------------- */
    function depositTokens(uint256 amount) external whenNotPaused nonReentrant {
        require(amount > 0, "DEPOSIT: zero");
        address token = _mimhoToken();
        require(token != address(0), "TOKEN: missing");

        _touch();

        bool ok = IERC20(token).transferFrom(msg.sender, address(this), amount);
        require(ok, "DEPOSIT: transferFrom failed");

        emit TokensDeposited(msg.sender, amount);
        _emitHubEvent(ACT_DEPOSIT, msg.sender, amount, "");
    }

    /* -------------------------
       Core: injectLiquidity
       ------------------------- */
    function injectLiquidity(
    uint256 tokenAmount,
    uint256 bnbAmount,
    uint256 minToken,
    uint256 minBNB,
    uint256 deadline
) external whenNotPaused nonReentrant {
    require(autoInjectEnabled, "Not authorized");
    require(
    lastInjectionTimestamp == 0 || block.timestamp >= lastInjectionTimestamp + injectionCooldown,
    "Cooldown active"
);

    address token = _mimhoToken();
    address router = _dexRouter();
    require(token != address(0), "TOKEN: missing");
    require(router != address(0), "ROUTER: missing");

    require(tokenAmount > 0 && bnbAmount > 0, "AMOUNT: zero");
    require(IERC20(token).balanceOf(address(this)) >= tokenAmount, "TOKEN: insufficient");
    require(address(this).balance >= bnbAmount, "BNB: insufficient");
    require(deadline >= block.timestamp, "DEADLINE: past");

    // ========= EFFECTS (CEI) =========
    autoInjectEnabled = false;
    lastInjectionTimestamp = block.timestamp;
    _touch();

    // ========= INTERACTIONS =========
    _forceApprove(token, router, tokenAmount);

    (uint256 usedToken, uint256 usedBNB, uint256 liquidity) =
        IUniswapV2Router02(router).addLiquidityETH{value: bnbAmount}(
            token,
            tokenAmount,
            minToken,
            minBNB,
            LP_BURN_ADDRESS,
            deadline
        );

    // ========= EFFECTS (post-call accounting only) =========
    totalInjectedToken += usedToken;
    totalInjectedBNB += usedBNB;
    totalLPBurned += liquidity;

    emit LastInjectionUpdated(block.timestamp, msg.sender);
    emit InjectionExecuted(usedToken, usedBNB, liquidity, block.timestamp, msg.sender);

    // Reset allowance (best practice)
    _forceApprove(token, router, 0);

    // Hub event as last line (best-effort)
    bytes memory data = abi.encode(usedToken, usedBNB, liquidity, deadline);
    _emitHubEvent(ACT_INJECTION_EXECUTED, msg.sender, usedBNB, data);
}

    /* -------------------------
       Recovery (non-MIMHO only)
       ------------------------- */
    function recoverERC20(address token, address to, uint256 amount) external onlyDAOorOwner nonReentrant {
        require(token != address(0) && to != address(0), "RECOVER: zero");
        require(amount > 0, "RECOVER: zero amount");
        require(token != _mimhoToken(), "RECOVER: MIMHO blocked");

        bool ok = IERC20(token).transfer(to, amount);
        require(ok, "RECOVER: transfer failed");

        _touch();
        emit RecoveredERC20(token, to, amount);
        _emitHubEvent(ACT_RECOVER_ERC20, msg.sender, amount, abi.encode(token, to));
    }

    /* -------------------------
       HUD Views (buttons)
       ------------------------- */
    function availableMIMHO() external view returns (uint256) {
        address token = _mimhoToken();
        if (token == address(0)) return 0;
        return IERC20(token).balanceOf(address(this));
    }

    function availableBNB() external view returns (uint256) {
        return address(this).balance;
    }

    function votingController() external view returns (address) {
        return _votingController();
    }

    function canInjectNow() external view returns (bool) {
    if (!autoInjectEnabled) return false;
    if (lastInjectionTimestamp != 0 && block.timestamp < lastInjectionTimestamp + injectionCooldown) return false;
    return true;
}

    /* -------------------------
       Internal helpers
       ------------------------- */
    function _touch() internal {
        lastActivityTimestamp = block.timestamp;
    }

    function _mimhoToken() internal view returns (address) {
        return registry.getContract(registry.KEY_MIMHO_TOKEN());
    }

    function _dexRouter() internal view returns (address) {
        // ✅ FIX: usar KEY_MIMHO_DEX do Registry
        return registry.getContract(registry.KEY_MIMHO_DEX());
    }

    function _votingController() internal view returns (address) {
        // ✅ FIX: usar KEY_MIMHO_VOTING_CONTROLLER do Registry
        return registry.getContract(registry.KEY_MIMHO_VOTING_CONTROLLER());
    }

    function _emitHubEvent(bytes32 action, address caller, uint256 value, bytes memory data) internal {
        address hubAddr = registry.getContract(registry.KEY_MIMHO_EVENTS_HUB());
        if (hubAddr == address(0)) return;

        try IMIMHOEventsHub(hubAddr).emitEvent(contractType(), action, caller, value, data) {
        } catch {
        }
    }

    function _forceApprove(address token, address spender, uint256 amount) internal {
        uint256 cur = IERC20(token).allowance(address(this), spender);
        if (cur != 0) {
            require(IERC20(token).approve(spender, 0), "APPROVE: reset failed");
        }
        require(IERC20(token).approve(spender, amount), "APPROVE: set failed");
    }
}
>>>>>>> fe7ced1 (Add official deployed MIMHO contracts with BscScan headers)
