/// -----------------------------------------------------------------------
/// MIMHO VESTING
/// Official MIMHO Ecosystem Contract
///
/// Network: BNB Smart Chain
/// Contract Address:
/// 0x0f9D839E9564bc02a79297f24e6792fb8FEeAc6F
///
/// BscScan:
/// https://bscscan.com/address/0x0f9D839E9564bc02a79297f24e6792fb8FEeAc6F
/// -----------------------------------------------------------------------

// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/* ============================================================
   MIMHO VESTING — v1.0.0
   ============================================================

   DESIGN PHILOSOPHY (MIMHO ABSOLUTE STANDARD)

   EN:
   - Code is Law: vesting rules are immutable and enforced on-chain.
   - Minimalism & Safety: no presale logic, no pricing, no BNB, no liquidity.
   - No privilege: users claim what is mathematically unlocked; no manual overrides.
   - Transparency: every meaningful action emits events (and is mirrored to Events Hub
     via best-effort try/catch so user tx never breaks).
   - Registry-Coupled Integrations: dependencies are resolved via MIMHORegistry keys
     (no local keccak/string duplication).

   PT:
   - Código é Lei: regras imutáveis e executadas on-chain.
   - Minimalismo & Segurança: sem lógica de pré-venda, sem preço, sem BNB, sem liquidez.
   - Sem privilégios: usuários recebem apenas o que está matematicamente liberado.
   - Transparência: tudo emite eventos (e é espelhado no Events Hub via try/catch).
   - Integração via Registry: dependências resolvidas via keys do MIMHORegistry.

   ============================================================ */

interface IERC20Minimal {
    function balanceOf(address a) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
}

interface IMIMHORegistry {
    function getContract(bytes32 key) external view returns (address);

    // Keys MUST be retrieved from the Registry itself (no local keccak/string).
    function KEY_MIMHO_EVENTS_HUB() external view returns (bytes32);
    function KEY_MIMHO_DAO() external view returns (bytes32);
}

interface IMIMHOEventsHub {
    function emitEvent(bytes32 module, bytes32 action, address caller, uint256 value, bytes calldata data) external;
}

/**
 * @dev Minimal Ownable2Step-like pattern (single-file, no OZ import).
 */
abstract contract Ownable2StepLite {
    address public owner;
    address public pendingOwner;

    event OwnershipTransferStarted(address indexed  previousOwner, address indexed  newOwner);
    event OwnershipTransferred(address indexed  previousOwner, address indexed  newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "ONLY_OWNER");
        _;
    }

    constructor() {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "ZERO_ADDR");
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
}

abstract contract ReentrancyGuardLite {
    uint256 private _lock = 1;
    modifier nonReentrant() {
        require(_lock == 1, "REENTRANCY");
        _lock = 2;
        _;
        _lock = 1;
    }
}

contract MIMHOVesting is Ownable2StepLite, ReentrancyGuardLite {
    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    string public constant version = "1.0.0";

    // Founder SAFE (immutable requirement across ecosystem when founder-related address is needed)
    address public constant FOUNDER_SAFE = 0x3b50433D64193923199aAf209eE8222B9c728Fbd;

    // Burn address used across the ecosystem
    address public constant BURN_ADDR = 0x000000000000000000000000000000000000dEaD;

    // Time constants
    uint64 public constant WEEK = 7 days;
    uint64 public constant MONTH = 30 days;
    uint64 public constant THREE_MONTHS = 90 days;

    // Supply floor (from token spec). Vesting uses it as a guardrail for internal burns (if used).
    uint256 public constant SUPPLY_MINIMUM_FLOOR = 500_000_000_000 ether;

    // Hub module id (bytes32) for this contract
    bytes32 public constant MODULE = bytes32("MIMHO_VESTING");

    // Hub actions
    bytes32 private constant A_CONFIG_UPDATED   = bytes32("CONFIG_UPDATED");
    bytes32 private constant A_FINALIZED        = bytes32("FINALIZED");
    bytes32 private constant A_PAUSED           = bytes32("PAUSED");
    bytes32 private constant A_UNPAUSED         = bytes32("UNPAUSED");

    bytes32 private constant A_FOUNDER_CLAIM    = bytes32("FOUNDER_CLAIM");
    bytes32 private constant A_PRESALE_REG      = bytes32("PRESALE_REGISTER");
    bytes32 private constant A_PRESALE_CLAIM    = bytes32("PRESALE_CLAIM");

    bytes32 private constant A_MKT_REGISTER     = bytes32("MARKETING_REGISTER");
    bytes32 private constant A_MKT_CLAIM        = bytes32("MARKETING_CLAIM");

    bytes32 private constant A_ECO_INIT         = bytes32("ECOSYSTEM_INIT");
    bytes32 private constant A_ECO_CLAIM        = bytes32("ECOSYSTEM_CLAIM");

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    IERC20Minimal public immutable MIMHO;
    IMIMHORegistry public immutable registry;

    bool public paused;
    bool public finalized;

    address public dao;
    bool public daoActivated;

    // Presale contract allowed to register vesting positions
    address public presaleContract;

    // Ecosystem receiver (wallet or contract) that receives weekly unlocked ecosystem tokens
    address public ecosystemReceiver;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event PauseChanged(bool paused);

    event DAORefreshed(address indexed  dao, bool activated);
    event PresaleContractSet(address indexed  presale);
    event EcosystemReceiverSet(address indexed  receiver);

    // Founder
    event FounderScheduleInitialized(uint64 cliffEnd, uint64 monthlyStart);
    event FounderTokensReleased(address indexed  to, uint256 amount, uint256 totalClaimed);

    // Presale vesting
    event PresaleVestingRegistered(address indexed  beneficiary, uint256 totalPurchased, uint16 tgeBps, uint16 weeklyBps, uint64 startTimestamp);
    event PresaleClaimed(address indexed  beneficiary, uint256 amount, uint256 totalClaimed);

    // Marketing vesting
    event MarketingVestingRegistered(address indexed  beneficiary, uint256 totalAllocated, uint64 startTimestamp);
    event MarketingClaimed(address indexed  beneficiary, uint256 amount, uint256 totalClaimed);

    // Ecosystem vesting
    event EcosystemInitialized(address indexed  receiver, uint64 startTimestamp);
    event EcosystemClaimed(address indexed  receiver, uint256 amount, uint256 totalClaimed);

    // Admin safety
    event RecoveredToken(address indexed  token, address indexed  to, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier notPaused() {
        require(!paused, "PAUSED");
        _;
    }

    modifier onlyDAOorOwner() {
        if (msg.sender == owner) {
            _;
        } else {
            require(daoActivated && msg.sender == dao, "ONLY_DAO_OR_OWNER");
            _;
        }
    }

    modifier onlyConfigMode() {
        require(!finalized, "FINALIZED");
        _;
    }

    modifier onlyPresale() {
        require(msg.sender == presaleContract, "ONLY_PRESALE");
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              EVENTS HUB
    //////////////////////////////////////////////////////////////*/

    function _emitHubEvent(bytes32 action, address caller, uint256 value, bytes memory data) internal {
        // Best-effort. Never break main logic.
        address hubAddr = registry.getContract(registry.KEY_MIMHO_EVENTS_HUB());
        if (hubAddr == address(0)) return;
        try IMIMHOEventsHub(hubAddr).emitEvent(MODULE, action, caller, value, data) {
        } catch {
        }
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address token, address registryAddr) {
        require(token != address(0) && registryAddr != address(0), "ZERO_ADDR");
        MIMHO = IERC20Minimal(token);
        registry = IMIMHORegistry(registryAddr);

        // Initialize founder schedule immediately (fixed by spec)
        // Cliff ends in 3 months from deploy time; monthly vesting begins at cliff end.
        founder.cliffEnd = uint64(block.timestamp) + THREE_MONTHS;
        founder.monthlyStart = founder.cliffEnd;

        emit FounderScheduleInitialized(founder.cliffEnd, founder.monthlyStart);
        _emitHubEvent(bytes32("FOUNDER_INIT"), msg.sender, 0, abi.encode(founder.cliffEnd, founder.monthlyStart));
    }

    /*//////////////////////////////////////////////////////////////
                               PAUSE
    //////////////////////////////////////////////////////////////*/

    function pauseEmergencial() external onlyDAOorOwner {
        paused = true;
        emit PauseChanged(true);
        _emitHubEvent(A_PAUSED, msg.sender, 0, "");
    }

    function unpause() external onlyDAOorOwner {
        paused = false;
        emit PauseChanged(false);
        _emitHubEvent(A_UNPAUSED, msg.sender, 0, "");
    }

    /*//////////////////////////////////////////////////////////////
                             DAO INTEGRATION
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Refresh DAO address from Registry key. Safe even pre-DAO.
     *         Uses Registry keys (no local keccak/string).
     */
    function refreshDAOFromRegistry() external onlyOwner {
        address daoAddr = registry.getContract(registry.KEY_MIMHO_DAO());
        dao = daoAddr;
        emit DAORefreshed(daoAddr, daoActivated);
        _emitHubEvent(bytes32("DAO_REFRESHED"), msg.sender, 0, abi.encode(daoAddr, daoActivated));
    }

    /**
     * @notice Activate DAO control for this contract.
     *         Once activated, DAO address can operate alongside owner via onlyDAOorOwner.
     */
    function activateDAO() external onlyOwner {
        require(dao != address(0), "DAO_NOT_SET");
        daoActivated = true;
        emit DAORefreshed(dao, true);
        _emitHubEvent(bytes32("DAO_ACTIVATED"), msg.sender, 0, abi.encode(dao));
    }

    /*//////////////////////////////////////////////////////////////
                             CONFIG / FINALIZE
    //////////////////////////////////////////////////////////////*/

    function setPresaleContract(address presale) external onlyDAOorOwner onlyConfigMode {
        require(presale != address(0), "ZERO_ADDR");
        presaleContract = presale;
        emit PresaleContractSet(presale);
        _emitHubEvent(A_CONFIG_UPDATED, msg.sender, 0, abi.encode("presale", presale));
    }

    function setEcosystemReceiver(address receiver) external onlyDAOorOwner onlyConfigMode {
        require(receiver != address(0), "ZERO_ADDR");
        ecosystemReceiver = receiver;
        emit EcosystemReceiverSet(receiver);
        _emitHubEvent(A_CONFIG_UPDATED, msg.sender, 0, abi.encode("ecosystemReceiver", receiver));
    }

    /**
     * @notice Irreversibly finalize configuration. After this, config setters are disabled.
     *         Does NOT change vesting rules (they are already immutable); it only prevents
     *         further participant registrations if you choose to restrict them later.
     */
    function finalize() external onlyDAOorOwner onlyConfigMode {
        finalized = true;
        emit PresaleContractSet(presaleContract);
        emit EcosystemReceiverSet(ecosystemReceiver);
        _emitHubEvent(A_FINALIZED, msg.sender, 0, abi.encode(presaleContract, ecosystemReceiver));
    }

    /*//////////////////////////////////////////////////////////////
                              FOUNDER VESTING
    //////////////////////////////////////////////////////////////*/

    struct FounderVestingData {
        uint64 cliffEnd;       // cliff end timestamp
        uint64 monthlyStart;   // start timestamp for monthly periods (== cliffEnd)
        uint256 totalAllocated; // 50B
        uint256 totalClaimed;
        bool initialized;
    }

    FounderVestingData public founder;

    uint256 public constant FOUNDER_TOTAL = 50_000_000_000 ether;
    uint256 public constant FOUNDER_MONTHLY_RELEASE = 5_000_000_000 ether;
    uint256 public constant FOUNDER_MONTHS = 10;

    /**
     * @notice Initializes founder allocation (token deposit expected separately).
     *         Can be called once (owner/DAO). This does not move tokens; it only
     *         locks schedule parameters on-chain for transparency.
     */
    function initFounderAllocation() external onlyDAOorOwner {
        require(!founder.initialized, "FOUNDER_ALREADY_INIT");
        founder.totalAllocated = FOUNDER_TOTAL;
        founder.initialized = true;

        _emitHubEvent(bytes32("FOUNDER_ALLOC_SET"), msg.sender, founder.totalAllocated, abi.encode(FOUNDER_SAFE));
    }

    function founderClaimableNow() public view returns (uint256) {
        if (!founder.initialized) return 0;
        if (block.timestamp < founder.cliffEnd) return 0;

        // Tempo total decorrido desde o início do desbloqueio mensal
        uint256 elapsed = block.timestamp - founder.monthlyStart;

        // Verificação de limite de tempo (Capitulação total)
        if (elapsed / MONTH >= FOUNDER_MONTHS) {
            uint256 maxVested = founder.totalAllocated;
            if (founder.totalClaimed >= maxVested) return 0;
            return maxVested - founder.totalClaimed;
        }

        // --- CORREÇÃO SLITHER: Multiplicar antes de dividir ---
        // Isso garante que o vesting seja linear por segundo, e não por blocos de meses.
        uint256 vested = (FOUNDER_MONTHLY_RELEASE * elapsed) / MONTH;

        if (vested > founder.totalAllocated) vested = founder.totalAllocated;
        if (founder.totalClaimed >= vested) return 0;
        return vested - founder.totalClaimed;
    }

    function founderNextClaimTime() public view returns (uint64) {
        if (!founder.initialized) return 0;
        if (block.timestamp < founder.cliffEnd) return founder.cliffEnd;
        uint256 elapsed = block.timestamp - founder.monthlyStart;
        uint256 monthsElapsed = elapsed / MONTH;
        if (monthsElapsed >= FOUNDER_MONTHS) return 0; // finished
        // next boundary
        return uint64(founder.monthlyStart + uint64((monthsElapsed + 1) * MONTH));
    }

    /**
     * @notice Anyone may trigger the founder claim, but tokens always go to the Founder SAFE.
     */
    function claimFounder() external nonReentrant notPaused {
        uint256 amount = founderClaimableNow();
        require(amount > 0, "NOTHING_TO_CLAIM");
        founder.totalClaimed += amount;
        require(MIMHO.transfer(FOUNDER_SAFE, amount), "TRANSFER_FAIL");

        emit FounderTokensReleased(FOUNDER_SAFE, amount, founder.totalClaimed);
        _emitHubEvent(A_FOUNDER_CLAIM, msg.sender, amount, abi.encode(FOUNDER_SAFE));
    }

    /*//////////////////////////////////////////////////////////////
                              PRESALE VESTING
    //////////////////////////////////////////////////////////////*/

    /**
     * Required minimal structure (as mandated):
     * totalPurchased, totalClaimed, startTimestamp, weeklyBps, lastClaimTimestamp
     *
     * Note:
     * - tgeBps is passed in for auditing/verification purposes (already paid by presale),
     *   and stored separately for view correctness. Vesting covers ONLY the remaining portion.
     */
    struct PresalePosition {
        uint256 totalPurchased;
        uint256 totalClaimed;
        uint64  startTimestamp;
        uint16  weeklyBps;
        uint64  lastClaimTimestamp;
        uint16  tgeBps; // stored for audit/view; not paid by this contract
        bool    exists;
    }

    mapping(address => PresalePosition) private _presale;

    /**
     * @notice Mandatory function called by Presale.
     * @dev Vesting does NOT know price/BNB/hardcap/dates. It only records and unlocks.
     *
     * @param beneficiary user wallet
     * @param totalPurchasedTokens full purchased amount (100%)
     * @param tgeBps TGE already paid by presale (e.g. 2000 for 20%)
     * @param weeklyBps weekly release bps on totalPurchasedTokens (e.g. 500 for 5%)
     * @param startTimestamp when vesting begins (typically purchase timestamp or TGE timestamp)
     */
    function registerPresaleVesting(
    address beneficiary,
    uint256 totalPurchasedTokens,
    uint16 tgeBps,
    uint16 weeklyBps,
    uint64 startTimestamp
) external onlyPresale onlyConfigMode {
    require(beneficiary != address(0), "ZERO_ADDR");
    require(totalPurchasedTokens > 0, "ZERO_AMOUNT");
    require(tgeBps <= 10_000, "BAD_TGE_BPS");
    require(weeklyBps > 0 && weeklyBps <= 10_000, "BAD_WEEKLY_BPS");
    require(startTimestamp > 0, "BAD_START");

    PresalePosition storage p = _presale[beneficiary];

    if (!p.exists) {
        p.exists = true;
        p.totalPurchased = totalPurchasedTokens;
        p.totalClaimed = 0;
        p.startTimestamp = startTimestamp;
        p.weeklyBps = weeklyBps;
        p.lastClaimTimestamp = startTimestamp;
    } else {
        p.totalPurchased += totalPurchasedTokens;
    }

    emit PresaleVestingRegistered(beneficiary, totalPurchasedTokens, tgeBps, weeklyBps, startTimestamp);
    _emitHubEvent(A_PRESALE_REG, msg.sender, totalPurchasedTokens, abi.encode(beneficiary, tgeBps, weeklyBps, startTimestamp));
}

    function getVestingInfo(address user) external view returns (
        uint256 totalPurchased,
        uint256 ClaimedAmount,
        uint64 startTimestamp,
        uint16 weeklyBps,
        uint64 lastClaimTimestamp
    ) {
        PresalePosition memory p = _presale[user];
        return (p.totalPurchased, p.totalClaimed, p.startTimestamp, p.weeklyBps, p.lastClaimTimestamp);
    }

    function totalClaimed(address user) external view returns (uint256) {
        return _presale[user].totalClaimed;
    }

    function remaining(address user) external view returns (uint256) {
        PresalePosition memory p = _presale[user];
        if (!p.exists) return 0;
        // remaining vesting portion is (10000 - tgeBps) of totalPurchased
        uint256 vestingTotal = (p.totalPurchased * (10_000 - p.tgeBps)) / 10_000;
        if (p.totalClaimed >= vestingTotal) return 0;
        return vestingTotal - p.totalClaimed;
    }

    function claimableNow(address user) public view returns (uint256) {
        PresalePosition memory p = _presale[user];
        if (!p.exists) return 0;
        if (block.timestamp < p.startTimestamp) return 0;

        // Tempo decorrido em segundos para precisão total
        uint256 elapsed = block.timestamp - p.startTimestamp;

        // --- CORREÇÃO SLITHER: Multiplicar antes de dividir ---
        // Calculamos o BPS proporcional ao tempo exato decorrido.
        uint256 vestedBps = (elapsed * uint256(p.weeklyBps)) / WEEK;

        uint256 maxVestingBps = 10_000 - uint256(p.tgeBps);
        if (vestedBps > maxVestingBps) vestedBps = maxVestingBps;

        // O valor total liberado (incluindo o que já foi sacado)
        uint256 vestedAmount = (p.totalPurchased * vestedBps) / 10_000;

        if (p.totalClaimed >= vestedAmount) return 0;
        return vestedAmount - p.totalClaimed;
    }

    function nextClaimTime(address user) external view returns (uint64) {
        PresalePosition memory p = _presale[user];
        if (!p.exists) return 0;
        if (block.timestamp < p.startTimestamp) return p.startTimestamp;

        // if fully vested, return 0
        uint256 maxVestingAmount = (p.totalPurchased * (10_000 - p.tgeBps)) / 10_000;
        if (p.totalClaimed >= maxVestingAmount) return 0;

        // next weekly boundary from lastClaimTimestamp
        uint64 next = p.lastClaimTimestamp + WEEK;
        if (next < p.startTimestamp) next = p.startTimestamp;
        return next;
    }

    function claimPresale() external nonReentrant notPaused {
        PresalePosition storage p = _presale[msg.sender];
        require(p.exists, "NO_POSITION");

        uint256 amount = claimableNow(msg.sender);
        require(amount > 0, "NOTHING_TO_CLAIM");

        p.totalClaimed += amount;
        p.lastClaimTimestamp = uint64(block.timestamp);

        require(MIMHO.transfer(msg.sender, amount), "TRANSFER_FAIL");
        emit PresaleClaimed(msg.sender, amount, p.totalClaimed);
        _emitHubEvent(A_PRESALE_CLAIM, msg.sender, amount, "");
    }

    /*//////////////////////////////////////////////////////////////
                              MARKETING VESTING
    //////////////////////////////////////////////////////////////*/

    /**
     * Uniform rule for everyone:
     * - 20% unlocked at startTimestamp (after first post is confirmed by admin/DAO)
     * - +10% per week thereafter
     * - User claims manually
     *
     * NOTE: On-chain cannot verify "first post". So startTimestamp is an on-chain attestation
     * performed by owner/DAO (same rule for everyone).
     */
    struct MarketingPosition {
        uint256 totalAllocated;
        uint256 totalClaimed;
        uint64 startTimestamp;
        uint64 lastClaimTimestamp;
        bool exists;
    }

    mapping(address => MarketingPosition) private _marketing;

    uint16 public constant MARKETING_TGE_BPS = 2_000;  // 20%
    uint16 public constant MARKETING_WEEKLY_BPS = 1_000; // 10%

    function registerMarketingVesting(address beneficiary, uint256 totalAllocated, uint64 startTimestamp)
        external
        onlyDAOorOwner
        onlyConfigMode
    {
        require(beneficiary != address(0), "ZERO_ADDR");
        require(totalAllocated > 0, "ZERO_AMOUNT");
        require(startTimestamp > 0, "BAD_START");

        MarketingPosition storage m = _marketing[beneficiary];
        require(!m.exists, "ALREADY_REGISTERED");

        m.totalAllocated = totalAllocated;
        m.totalClaimed = 0;
        m.startTimestamp = startTimestamp;
        m.lastClaimTimestamp = startTimestamp;
        m.exists = true;

        emit MarketingVestingRegistered(beneficiary, totalAllocated, startTimestamp);
        _emitHubEvent(A_MKT_REGISTER, msg.sender, totalAllocated, abi.encode(beneficiary, startTimestamp));
    }

    function marketingClaimableNow(address user) public view returns (uint256) {
        MarketingPosition memory m = _marketing[user];
        if (!m.exists) return 0;
        if (block.timestamp < m.startTimestamp) return 0;

        // Tempo decorrido em segundos para garantir precisão total
        uint256 elapsed = block.timestamp - m.startTimestamp;

        // --- CORREÇÃO SLITHER: Multiplicar antes de dividir ---
        // Adicionamos o TGE BPS e somamos a parte linear (Weekly BPS calculada por segundo)
        uint256 vestedBps = uint256(MARKETING_TGE_BPS) +
            (elapsed * uint256(MARKETING_WEEKLY_BPS)) / WEEK;

        // Trava em 100% (10.000 BPS)
        if (vestedBps > 10_000) vestedBps = 10_000;

        // Calcula o montante total liberado até o momento
        uint256 vestedAmount = (m.totalAllocated * vestedBps) / 10_000;

        if (m.totalClaimed >= vestedAmount) return 0;
        return vestedAmount - m.totalClaimed;
    }

    function marketingNextClaimTime(address user) external view returns (uint64) {
        MarketingPosition memory m = _marketing[user];
        if (!m.exists) return 0;
        if (block.timestamp < m.startTimestamp) return m.startTimestamp;
        if (m.totalClaimed >= m.totalAllocated) return 0;
        return m.lastClaimTimestamp + WEEK;
    }

    function getMarketingInfo(address user) external view returns (
        uint256 totalAllocated,
        uint256 totalClaimed_,
        uint64 startTimestamp,
        uint64 lastClaimTimestamp
    ) {
        MarketingPosition memory m = _marketing[user];
        return (m.totalAllocated, m.totalClaimed, m.startTimestamp, m.lastClaimTimestamp);
    }

    function claimMarketing() external nonReentrant notPaused {
        MarketingPosition storage m = _marketing[msg.sender];
        require(m.exists, "NO_POSITION");

        uint256 amount = marketingClaimableNow(msg.sender);
        require(amount > 0, "NOTHING_TO_CLAIM");

        m.totalClaimed += amount;
        m.lastClaimTimestamp = uint64(block.timestamp);

        require(MIMHO.transfer(msg.sender, amount), "TRANSFER_FAIL");
        emit MarketingClaimed(msg.sender, amount, m.totalClaimed);
        _emitHubEvent(A_MKT_CLAIM, msg.sender, amount, "");
    }

    /*//////////////////////////////////////////////////////////////
                              ECOSYSTEM VESTING
    //////////////////////////////////////////////////////////////*/

    struct EcosystemState {
        bool initialized;
        uint64 startTimestamp;
        uint256 totalAllocated; // 200B
        uint256 totalClaimed;
    }

    EcosystemState public ecosystem;

    uint256 public constant ECOSYSTEM_TOTAL = 200_000_000_000 ether;
    uint256 public constant ECOSYSTEM_WEEKLY_RELEASE = 2_500_000_000 ether; // 2.5B per 7 days
    uint256 public constant ECOSYSTEM_WEEKS = 80; // 200 / 2.5 = 80

    function initEcosystem(uint64 startTimestamp) external onlyDAOorOwner onlyConfigMode {
        require(!ecosystem.initialized, "ECO_ALREADY_INIT");
        require(ecosystemReceiver != address(0), "ECO_NO_RECEIVER");
        require(startTimestamp > 0, "BAD_START");

        ecosystem.initialized = true;
        ecosystem.startTimestamp = startTimestamp;
        ecosystem.totalAllocated = ECOSYSTEM_TOTAL;
        ecosystem.totalClaimed = 0;

        emit EcosystemInitialized(ecosystemReceiver, startTimestamp);
        _emitHubEvent(A_ECO_INIT, msg.sender, ECOSYSTEM_TOTAL, abi.encode(ecosystemReceiver, startTimestamp));
    }

    function ecosystemClaimableNow() public view returns (uint256) {
        if (!ecosystem.initialized) return 0;
        if (block.timestamp < ecosystem.startTimestamp) return 0;

        uint256 elapsed = block.timestamp - ecosystem.startTimestamp;
        uint256 weeksElapsed = elapsed / WEEK;

        if (weeksElapsed >= ECOSYSTEM_WEEKS) {
            if (ecosystem.totalClaimed >= ecosystem.totalAllocated) return 0;
            return ecosystem.totalAllocated - ecosystem.totalClaimed;
        }

        uint256 vested = ECOSYSTEM_WEEKLY_RELEASE * weeksElapsed;
        if (vested > ecosystem.totalAllocated) vested = ecosystem.totalAllocated;

        if (ecosystem.totalClaimed >= vested) return 0;
        return vested - ecosystem.totalClaimed;
    }

    function ecosystemNextClaimTime() external view returns (uint64) {
        if (!ecosystem.initialized) return 0;
        if (block.timestamp < ecosystem.startTimestamp) return ecosystem.startTimestamp;
        if (ecosystem.totalClaimed >= ecosystem.totalAllocated) return 0;

        uint256 elapsed = block.timestamp - ecosystem.startTimestamp;
        uint256 weeksElapsed = elapsed / WEEK;
        if (weeksElapsed >= ECOSYSTEM_WEEKS) return 0;

        return uint64(ecosystem.startTimestamp + uint64((weeksElapsed + 1) * WEEK));
    }

    function claimEcosystem() external nonReentrant notPaused {
        require(ecosystem.initialized, "ECO_NOT_INIT");
        require(ecosystemReceiver != address(0), "ECO_NO_RECEIVER");

        uint256 amount = ecosystemClaimableNow();
        require(amount > 0, "NOTHING_TO_CLAIM");

        ecosystem.totalClaimed += amount;
        require(MIMHO.transfer(ecosystemReceiver, amount), "TRANSFER_FAIL");

        emit EcosystemClaimed(ecosystemReceiver, amount, ecosystem.totalClaimed);
        _emitHubEvent(A_ECO_CLAIM, msg.sender, amount, abi.encode(ecosystemReceiver));
    }

    /*//////////////////////////////////////////////////////////////
                              VIEW HELPERS
    //////////////////////////////////////////////////////////////*/

    function contractStatus() external view returns (
        string memory v,
        bool isPaused,
        bool isFinalized,
        address token,
        address reg,
        address daoAddr,
        bool daoActive,
        address presale,
        address ecoReceiver
    ) {
        return (version, paused, finalized, address(MIMHO), address(registry), dao, daoActivated, presaleContract, ecosystemReceiver);
    }

    function balances() external view returns (
        uint256 mimhoBalance,
        uint256 founderClaimable,
        uint256 ecosystemClaimable
    ) {
        return (MIMHO.balanceOf(address(this)), founderClaimableNow(), ecosystemClaimableNow());
    }

    /*//////////////////////////////////////////////////////////////
                        SAFETY: RECOVER OTHER TOKENS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Recover tokens accidentally sent to this contract (NOT MIMHO).
     *         Policy: allowed only for non-MIMHO tokens; controlled by DAO/Owner.
     */
    function recoverERC20(address token, address to, uint256 amount) external onlyDAOorOwner nonReentrant {
        require(token != address(MIMHO), "NO_RECOVER_MIMHO");
        require(to != address(0), "ZERO_ADDR");
        require(amount > 0, "ZERO_AMOUNT");

        // Minimal transfer call
        (bool ok, bytes memory data) = token.call(abi.encodeWithSelector(IERC20Minimal.transfer.selector, to, amount));
        require(ok && (data.length == 0 || abi.decode(data, (bool))), "RECOVER_FAIL");

        emit RecoveredToken(token, to, amount);
        _emitHubEvent(bytes32("RECOVER"), msg.sender, amount, abi.encode(token, to));
    }
}
