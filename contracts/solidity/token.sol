/// -----------------------------------------------------------------------
/// MIMHO TOKEN
/// Official MIMHO Ecosystem Contract
///
/// Network: BNB Smart Chain
/// Contract Address:
/// 0xe6FF9A0Dcf6593f48732C79e53457e367232fD48
///
/// BscScan:
/// https://bscscan.com/address/0xe6FF9A0Dcf6593f48732C79e53457e367232fD48
/// -----------------------------------------------------------------------

// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/*
========================================================
MIMHO TOKEN — DESIGN PHILOSOPHY
========================================================

The MIMHO token is intentionally designed to be minimal,
immutable, secure, and future-proof.

The token is NOT the ecosystem.
The token is the foundation.

--------------------------------------------------------
CORE PRINCIPLES
--------------------------------------------------------

1. Minimalism
The token contract must remain lightweight.
All complex logic (staking, vesting, buyback, burn,
liquidity management, governance extensions, reputation
systems) must live in auxiliary contracts.

2. Immutability
All token fees are immutable by design.
There are no functions that allow fee increases,
hidden updates, or future manipulation.

3. Security First
- Emergency pause for extreme scenarios only
- Safe ownership and DAO transition
- No renounceOwnership traps
- Explicit, auditable logic

4. Transparency
All relevant actions emit public events.
The token is fully observable by dashboards (HUD),
indexers, and monitoring systems.

5. Trust by Architecture
Liquidity reinforcement, burns, buybacks, and staking
rewards are handled externally through dedicated
contracts, keeping the token clean and auditable.

6. Exchange Compatibility
- Wallet-to-wallet transfers are fee-free
- Fees apply only on DEX trades (AMMs)
- Fully compatible with centralized exchanges (CEX)

7. DAO-Ready
The token supports a secure transition from founder
control to DAO governance without irreversible risks.

--------------------------------------------------------
The token is not a playground.
The token is infrastructure.
========================================================
*/

/*//////////////////////////////////////////////////////////////
                            INTERFACES
//////////////////////////////////////////////////////////////*/

interface IMIMHORegistry {
    function getContract(bytes32 key) external view returns (address);
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
    event Transfer(address indexed  from, address indexed  to, uint256 value);
    event Approval(address indexed  owner, address indexed  spender, uint256 value);

    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);

    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);

    function transfer(address to, uint256 amount) external returns (bool);

    function allowance(address owner_, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

/*//////////////////////////////////////////////////////////////
                            CONTRACT
//////////////////////////////////////////////////////////////*/

contract MIMHO is IERC20 {
    /*//////////////////////////////////////////////////////////////
                                METADATA
    //////////////////////////////////////////////////////////////*/

    string public constant version = "1.0.4"; // bumped for Slither fixes

    string private constant _NAME = "MIMHO";
    string private constant _SYMBOL = "MIMHO";
    uint8 private constant _DECIMALS = 18;

    uint256 public constant TOTAL_SUPPLY = 1_000_000_000_000 * 1e18; // 1T
    uint256 public constant MIN_SUPPLY   =   500_000_000_000 * 1e18; // 500B floor

    // Standard burn address (used to measure floor)
    address public constant DEAD = 0x000000000000000000000000000000000000dEaD;

    /*//////////////////////////////////////////////////////////////
                                GOVERNANCE
    //////////////////////////////////////////////////////////////*/

    address public owner;
    address public daoContract; // ✅ renamed (camelCase)
    bool public daoActivated;

    bool public paused;
    bool public tradingEnabled;

    /*//////////////////////////////////////////////////////////////
                        ANTI-WHALE LAUNCH GUARD (IMMUTABLE)
    //////////////////////////////////////////////////////////////*/

    // Fixed max buy (per transaction) during the first launch window
    uint256 public constant MAX_BUY_AMOUNT = 500_000_000 * 1e18; // 500M tokens
    uint256 public constant MAX_BUY_DURATION = 20 minutes;       // 20 minutes window

    uint256 public tradingEnabledAt; // timestamp when trading was enabled (0 if not enabled yet)

    /*//////////////////////////////////////////////////////////////
                        IMMUTABLE FEES (BASIS POINTS)
    //////////////////////////////////////////////////////////////*/

    uint256 public constant BP_DIVISOR = 10_000;

    // Buy: 1.00% → Founder
    uint256 public constant BUY_FOUNDER_BP = 100;

    // Sell: 1.50% total
    uint256 public constant SELL_FOUNDER_BP = 100; // 1.00% → Founder
    uint256 public constant SELL_LP_BP      = 18;  // 0.18% → LP module
    uint256 public constant SELL_BURN_BP    = 16;  // 0.16% → Burn (or Marketing if floor reached)
    uint256 public constant SELL_STAKE_BP   = 16;  // 0.16% → Staking module

    /*//////////////////////////////////////////////////////////////
                        IMMUTABLE FOUNDER WALLET
    //////////////////////////////////////////////////////////////*/

    // Founder wallet hardcoded (immutable forever)
    address public constant founderWallet =
    0x3b50433D64193923199aAf209eE8222B9c728Fbd;

    address public constant LIQUIDITY_RESERVE_WALLET =
    0xb891C4e94a1F4B7Aa35d21BbA37D245909B6ad95;

    /*//////////////////////////////////////////////////////////////
                            ERC20 STORAGE
    //////////////////////////////////////////////////////////////*/

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    /*//////////////////////////////////////////////////////////////
                        FEE EXEMPTION LIST
    //////////////////////////////////////////////////////////////*/

    mapping(address => bool) public isFeeExempt;
    event FeeExemptSet(address indexed  account, bool status);

    /*//////////////////////////////////////////////////////////////
                            MODULE REGISTRY
    //////////////////////////////////////////////////////////////*/

    IMIMHORegistry public registry;

    // NOTE: these are legacy keys expected by the token;
    // Registry must provide aliases resolving them correctly.
    bytes32 public constant KEY_EVENTS_HUB       = keccak256("MIMHO_EVENTS_HUB");
    bytes32 public constant KEY_LP_INJECTOR      = keccak256("LP_INJECTOR");
    bytes32 public constant KEY_STAKING          = keccak256("STAKING_CONTRACT");
    bytes32 public constant KEY_MARKETING_WALLET = keccak256("MARKETING_WALLET");

    /*//////////////////////////////////////////////////////////////
                            AMM CONTROL
    //////////////////////////////////////////////////////////////*/

    mapping(address => bool) public isAMMPair;

    /*//////////////////////////////////////////////////////////////
                            EVENTS (GOV)
    //////////////////////////////////////////////////////////////*/

    event OwnershipTransferred(address indexed  from, address indexed  to);
    event DAOSet(address indexed  daoContract);
    event DAOActivated(address indexed  daoContract);
    event RegistrySet(address indexed  registry);
    event AMMPairSet(address indexed  pair, bool status);

    /*//////////////////////////////////////////////////////////////
                            HUD CONSTANTS
    //////////////////////////////////////////////////////////////*/

    bytes32 public constant ACT_TRANSFER = keccak256("TRANSFER");
    bytes32 public constant ACT_APPROVE  = keccak256("APPROVE");
    bytes32 public constant ACT_PAUSE    = keccak256("PAUSE");
    bytes32 public constant ACT_UNPAUSE  = keccak256("UNPAUSE");
    bytes32 public constant ACT_TRADING  = keccak256("TRADING_ENABLED");
    bytes32 public constant ACT_FEES     = keccak256("FEES_DISTRIBUTED");
    bytes32 public constant ACT_REGISTRY = keccak256("REGISTRY_SET");
    bytes32 public constant ACT_AMM_PAIR = keccak256("AMM_PAIR_SET");
    bytes32 public constant ACT_DAO_SET  = keccak256("DAO_SET");
    bytes32 public constant ACT_DAO_ACT  = keccak256("DAO_ACTIVATED");

    bytes32 public constant ACT_FEE_EXEMPT = keccak256("FEE_EXEMPT_SET");
    bytes32 public constant ACT_RECOVER    = keccak256("RECOVER_TOKENS");

    bytes32 public constant ACT_RENOUNCE   = keccak256("RENOUNCED");
    bytes32 public constant ACT_MAX_BUY    = keccak256("MAX_BUY_BLOCK");

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyOwner() {
        require(msg.sender == owner, "MIMHO: Not owner");
        _;
    }

    modifier onlyDAOorOwner() {
        require(msg.sender == owner || msg.sender == daoContract, "MIMHO: Not authorized");
        _;
    }

    modifier notPaused() {
        require(!paused, "MIMHO: Paused");
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() {
        owner = msg.sender;

        _balances[msg.sender] = TOTAL_SUPPLY;
        emit Transfer(address(0), msg.sender, TOTAL_SUPPLY);

        emit OwnershipTransferred(address(0), msg.sender);

        // Best-effort HUD emit (registry may not be set yet)
        _emitHubEvent(ACT_TRANSFER, msg.sender, TOTAL_SUPPLY, abi.encode(address(0), msg.sender, TOTAL_SUPPLY));
        _emitHubEvent(ACT_RENOUNCE, msg.sender, 0, abi.encode(bytes32("DEPLOY"), msg.sender));
    }

    /*//////////////////////////////////////////////////////////////
                        IERC20 METADATA
    //////////////////////////////////////////////////////////////*/

    function name() external pure override returns (string memory) { return _NAME; }
    function symbol() external pure override returns (string memory) { return _SYMBOL; }
    function decimals() external pure override returns (uint8) { return _DECIMALS; }

    /*//////////////////////////////////////////////////////////////
                        CONTRACT TYPE (HUD MODULE)
    //////////////////////////////////////////////////////////////*/

    function contractType() public pure returns (bytes32) {
        return keccak256("MIMHO_TOKEN");
    }

    /*//////////////////////////////////////////////////////////////
                            HUD EMITTER
    //////////////////////////////////////////////////////////////*/

    function _eventsHub() internal view returns (IMIMHOEventsHub hub) {
        if (address(registry) == address(0)) return IMIMHOEventsHub(address(0));
        address hubAddr = registry.getContract(KEY_EVENTS_HUB);
        if (hubAddr == address(0)) return IMIMHOEventsHub(address(0));
        return IMIMHOEventsHub(hubAddr);
    }

    function _emitHubEvent(
        bytes32 action,
        address caller,
        uint256 value,
        bytes memory data
    ) internal {
        IMIMHOEventsHub hub = _eventsHub();
        if (address(hub) == address(0)) return;

        // Best-effort (never break main logic)
        try hub.emitEvent(contractType(), action, caller, value, data) {
        } catch {
            // swallow
        }
    }

    /*//////////////////////////////////////////////////////////////
                            ERC20 VIEW
    //////////////////////////////////////////////////////////////*/

    function totalSupply() external pure override returns (uint256) { return TOTAL_SUPPLY; }

    function balanceOf(address account) external view override returns (uint256) { return _balances[account]; }

    function allowance(address owner_, address spender) external view override returns (uint256) {
        return _allowances[owner_][spender];
    }

    function isPaused() external view returns (bool) { return paused; }

    function isTradingEnabled() external view returns (bool) { return tradingEnabled; }

    function getRegistry() external view returns (address) { return address(registry); }

    function circulatingSupply() external view returns (uint256) {
        // Circulating = total minus burned-to-DEAD
        return TOTAL_SUPPLY - _balances[DEAD];
    }

    function burnFloorReached() public view returns (bool) {
        // Floor reached when circulating <= MIN_SUPPLY
        return (TOTAL_SUPPLY - _balances[DEAD]) <= MIN_SUPPLY;
    }

    function maxBuyActive() public view returns (bool) {
        if (!tradingEnabled) return false;
        if (tradingEnabledAt == 0) return false;
        return block.timestamp < (tradingEnabledAt + MAX_BUY_DURATION);
    }

    /*//////////////////////////////////////////////////////////////
                            ERC20 LOGIC
    //////////////////////////////////////////////////////////////*/

    function approve(address spender, uint256 amount) external override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external override notPaused returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external override notPaused returns (bool) {
        uint256 allowed = _allowances[from][msg.sender];
        require(allowed >= amount, "MIMHO: Allowance exceeded");
        unchecked { _allowances[from][msg.sender] = allowed - amount; }
        _transfer(from, to, amount);
        return true;
    }

    function _approve(address from, address spender, uint256 amount) internal {
        require(from != address(0) && spender != address(0), "MIMHO: Zero address");
        _allowances[from][spender] = amount;

        emit Approval(from, spender, amount);

        // HUD after effects (CEI ok)
        _emitHubEvent(ACT_APPROVE, msg.sender, amount, abi.encode(from, spender, amount));
    }

    /*//////////////////////////////////////////////////////////////
                        FEE CALCULATION (REFactor)
    //////////////////////////////////////////////////////////////*/

    function _getFeeValues(
        uint256 amount,
        bool isBuy,
        bool isSell,
        bool takeFee,
        bool registryReady
    )
        private
        view
        returns (
            uint256 founderFee,
            uint256 lpFee,
            uint256 burnFee,
            uint256 stakeFee,
            bool burnRedirectToMarketing
        )
    {
        // ✅ explicit init (Slither)
        founderFee = 0;
        lpFee = 0;
        burnFee = 0;
        stakeFee = 0;
        burnRedirectToMarketing = false;

        if (!takeFee) return (0, 0, 0, 0, false);

        if (isBuy) {
            // BUY: 1% founder
            founderFee = (amount * BUY_FOUNDER_BP) / BP_DIVISOR;
            return (founderFee, 0, 0, 0, false);
        }

        if (isSell) {
            if (isSell) {
    // SELL: founder always
    founderFee = (amount * SELL_FOUNDER_BP) / BP_DIVISOR;

    // ✅ LP fee independe do Registry (vai pra carteira hardcoded no _transfer)
    lpFee = (amount * SELL_LP_BP) / BP_DIVISOR;

    // Module fees that depend on ecosystem modules only if registry is ready
    if (registryReady) {
        burnFee  = (amount * SELL_BURN_BP) / BP_DIVISOR;
        stakeFee = (amount * SELL_STAKE_BP) / BP_DIVISOR;

        // Burn floor rule: if reached, redirect burn portion to marketing
        if (burnFee > 0 && burnFloorReached()) {
            burnRedirectToMarketing = true;
        }
    }

    return (founderFee, lpFee, burnFee, stakeFee, burnRedirectToMarketing);
}
            founderFee = (amount * SELL_FOUNDER_BP) / BP_DIVISOR;

            // Module fees only if registry is ready
            if (registryReady) {
                lpFee    = (amount * SELL_LP_BP) / BP_DIVISOR;
                burnFee  = (amount * SELL_BURN_BP) / BP_DIVISOR;
                stakeFee = (amount * SELL_STAKE_BP) / BP_DIVISOR;

                // Burn floor rule: if reached, redirect burn portion to marketing
                if (burnFee > 0 && burnFloorReached()) {
                    burnRedirectToMarketing = true;
                }
            }

            return (founderFee, lpFee, burnFee, stakeFee, burnRedirectToMarketing);
        }

        // Wallet-to-wallet: fee-free by design
        return (0, 0, 0, 0, false);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL TRANSFER (FEES)
                    ✅ CEI enforced (Slither)
    //////////////////////////////////////////////////////////////*/

    function _transfer(address from, address to, uint256 amount) internal {
    require(from != address(0) && to != address(0), "MIMHO: Zero address");
    require(_balances[from] >= amount, "MIMHO: Balance too low");

    if (!tradingEnabled) {
        require(from == owner || to == owner, "MIMHO: Trading disabled");
    }

    bool isBuy  = isAMMPair[from]; // AMM → wallet
    bool isSell = isAMMPair[to];   // wallet → AMM

    // ✅ Max Buy Guard (first 20 minutes only, per buy tx) — intact
    if (isBuy && maxBuyActive()) {
        if (amount > MAX_BUY_AMOUNT) {
            revert("MIMHO: MaxBuy first 20m");
        }
    }

    bool takeFee = (isBuy || isSell);

    // Fee exemption (bypasses fees only)
    if (takeFee && (isFeeExempt[from] || isFeeExempt[to])) {
        takeFee = false;
    }

    bool registryReady = address(registry) != address(0);

    // ✅ explicit init at declaration (Slither)
    uint256 founderFee = 0;
    uint256 lpFee = 0;
    uint256 burnFee = 0;
    uint256 stakeFee = 0;

    bool burnRedirectToMarketing = false;

    (founderFee, lpFee, burnFee, stakeFee, burnRedirectToMarketing) =
        _getFeeValues(amount, isBuy, isSell, takeFee, registryReady);

    // ✅ FEES: regra explícita anti-bug / anti-Mythril (SWC-101)
    uint256 totalFee = founderFee + lpFee + burnFee + stakeFee;
    require(totalFee <= amount, "MIMHO: Fee > amount");

    // ✅ sem if / sem unchecked aqui (0.8.x já reverte se der ruim)
    uint256 sendAmount = amount - totalFee;

    // Resolve targets (ONLY if needed) — no external calls here except reading registry (view)
address lpTarget = address(0);
address stakeTarget = address(0);
address burnOrMarketingTarget = address(0);

// LP fee vai SEMPRE para carteira hardcoded
if (lpFee > 0) {
    lpTarget = LIQUIDITY_RESERVE_WALLET; // SAFE hardcoded
}

// As demais dependem do registry
if (registryReady) {
    if (stakeFee > 0) {
        stakeTarget = registry.getContract(KEY_STAKING);
        require(stakeTarget != address(0), "MIMHO: Staking target not set");
    }

    if (burnFee > 0) {
        if (!burnRedirectToMarketing) {
            burnOrMarketingTarget = DEAD;
        } else {
            burnOrMarketingTarget = registry.getContract(KEY_MARKETING_WALLET);
            require(burnOrMarketingTarget != address(0), "MIMHO: Marketing target not set");
        }
    }
}

    // ============================================================
    // ✅ EFFECTS FIRST (CEI): update balances BEFORE any HUD calls
    // ============================================================
    _balances[from] -= amount;
    _balances[to] += sendAmount;

    if (founderFee > 0) {
        _balances[founderWallet] += founderFee;
    }

    if (lpFee > 0) {
        _balances[lpTarget] += lpFee;
    }

    if (stakeFee > 0) {
        _balances[stakeTarget] += stakeFee;
    }

    if (burnFee > 0) {
        _balances[burnOrMarketingTarget] += burnFee;
    }

    // ============================================================
    // INTERACTIONS / LOGS AFTER EFFECTS
    // ============================================================

    emit Transfer(from, to, sendAmount);

    if (founderFee > 0) emit Transfer(from, founderWallet, founderFee);
    if (lpFee > 0) emit Transfer(from, lpTarget, lpFee);
    if (stakeFee > 0) emit Transfer(from, stakeTarget, stakeFee);

    if (burnFee > 0) {
        emit Transfer(from, burnOrMarketingTarget, burnFee);
    }

    // HUD events AFTER effects (CEI)
    _emitHubEvent(ACT_TRANSFER, msg.sender, sendAmount, abi.encode(from, to, sendAmount));

    if (totalFee > 0) {
        _emitHubEvent(
            ACT_FEES,
            msg.sender,
            totalFee,
            abi.encode(founderFee, lpFee, burnFee, stakeFee, isBuy, isSell, burnRedirectToMarketing)
        );
    }
}

    /*//////////////////////////////////////////////////////////////
                        ADMIN & GOVERNANCE
    //////////////////////////////////////////////////////////////*/

    function enableTrading() external onlyOwner {
        require(!tradingEnabled, "MIMHO: Trading already enabled");
        tradingEnabled = true;
        tradingEnabledAt = block.timestamp; // Start anti-whale window now

        _emitHubEvent(ACT_TRADING, msg.sender, 0, abi.encode(true, tradingEnabledAt, MAX_BUY_AMOUNT, MAX_BUY_DURATION));
        emit AMMPairSet(address(0), false); // no-op marker (optional)
    }

    function pauseEmergency() external onlyDAOorOwner {
        paused = true;
        _emitHubEvent(ACT_PAUSE, msg.sender, 0, abi.encode(true));
    }

    function unpause() external onlyDAOorOwner {
        paused = false;
        _emitHubEvent(ACT_UNPAUSE, msg.sender, 0, abi.encode(false));
    }

    function setDAO(address _dao) external onlyOwner {
        require(_dao != address(0), "MIMHO: DAO zero");
        require(daoContract == address(0), "MIMHO: DAO already set");
        daoContract = _dao;
        emit DAOSet(_dao);
        _emitHubEvent(ACT_DAO_SET, msg.sender, 0, abi.encode(_dao));
    }

    function activateDAO() external onlyOwner {
        require(daoContract != address(0), "MIMHO: DAO not set");
        require(!daoActivated, "MIMHO: DAO already active");
        daoActivated = true;
        emit DAOActivated(daoContract);
        _emitHubEvent(ACT_DAO_ACT, msg.sender, 0, abi.encode(daoContract));
    }

    function setRegistry(address _registry) external onlyDAOorOwner {
        require(_registry != address(0), "MIMHO: Registry zero");
        registry = IMIMHORegistry(_registry);
        emit RegistrySet(_registry);
        _emitHubEvent(ACT_REGISTRY, msg.sender, 0, abi.encode(_registry));
    }

    function setAMMPair(address pair, bool status) external onlyDAOorOwner {
        require(pair != address(0), "MIMHO: Pair zero");
        isAMMPair[pair] = status;
        emit AMMPairSet(pair, status);
        _emitHubEvent(ACT_AMM_PAIR, msg.sender, 0, abi.encode(pair, status));
    }

    function setFeeExempt(address account, bool status) external onlyDAOorOwner {
        require(account != address(0), "MIMHO: Account zero");
        isFeeExempt[account] = status;
        emit FeeExemptSet(account, status);
        _emitHubEvent(ACT_FEE_EXEMPT, msg.sender, 0, abi.encode(account, status));
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "MIMHO: Owner zero");
        emit OwnershipTransferred(owner, newOwner);
        _emitHubEvent(ACT_TRADING, msg.sender, 0, abi.encode(bytes32("OWNER_TRANSFER"), owner, newOwner));
        owner = newOwner;
    }

    /*//////////////////////////////////////////////////////////////
                        SAFE RENOUNCE (DAO-READY)
    //////////////////////////////////////////////////////////////*/

    /// @notice Renounce ownership ONLY if DAO is set and activated.
    /// @dev Callable by anyone (prevents "lost owner" risk by enforcing conditions).
    function renounceIfReady() external {
        require(owner != address(0), "MIMHO: already renounced");
        require(daoContract != address(0), "MIMHO: DAO not set");
        require(daoActivated, "MIMHO: DAO not activated");

        address oldOwner = owner;
        owner = address(0);

        emit OwnershipTransferred(oldOwner, address(0));
        _emitHubEvent(ACT_RENOUNCE, msg.sender, 0, abi.encode(oldOwner, daoContract, block.timestamp));
    }

    /*//////////////////////////////////////////////////////////////
                    TOKEN RECOVERY
    //////////////////////////////////////////////////////////////*/

    function recoverTokens(address token, address to, uint256 amount) external onlyDAOorOwner {
        require(token != address(0), "MIMHO: Token zero");
        require(to != address(0), "MIMHO: To zero");
        require(token != address(this), "MIMHO: Cannot recover MIMHO");

        bool ok = IERC20(token).transfer(to, amount);
        require(ok, "MIMHO: Recover failed");

        _emitHubEvent(ACT_RECOVER, msg.sender, amount, abi.encode(token, to, amount));
    }

    receive() external payable {}

    function recoverNative(address payable to, uint256 amount) external onlyDAOorOwner {
        require(to != address(0), "MIMHO: To zero");
        (bool ok, ) = to.call{value: amount}("");
        require(ok, "MIMHO: Native recover failed");

        _emitHubEvent(ACT_RECOVER, msg.sender, amount, abi.encode(address(0), to, amount));
    }
}
