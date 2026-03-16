/// -----------------------------------------------------------------------
/// MIMHO PRESALE
/// Official MIMHO Ecosystem Contract
///
/// Network: BNB Smart Chain
/// Contract Address:
/// 0xED068a9fD46A0099375318bb6923B5E72EeE924a
///
/// BscScan:
/// https://bscscan.com/address/0xED068a9fD46A0099375318bb6923B5E72EeE924a
/// -----------------------------------------------------------------------

// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/* ============================================================
   MIMHO PRESALE — v1.0.0 (MIMHO ABSOLUTE PROTOCOL)
   ============================================================

   DESIGN PHILOSOPHY
   - Disposable & Simple: sells a fixed allocation within a time window or until hard cap.
   - No Soft Cap / No Refunds: sale outcome never blocks token launch.
   - Fair Vesting for All: 20% instant, 80% escrowed in Vesting and released by Vesting rules.
   - Funds Safety (No-Risk Delivery):
       finalize() never depends on external calls (it only closes + burns unsold).
       pushFunds() is retryable and can be re-called after fixing addresses.
   - Dependencies:
       Default: pull from Registry KEYS and cache (syncFromRegistry()).
       Emergency: allow setting Vesting / LiquidityBootstrapper if Registry is wrong,
                  but only under strict conditions (post-finalize, before paid).
   - Radical Transparency:
       All actions emit public events + EventsHub best-effort via try/catch.

   Sale configuration (FINAL, as per Rodrigo):
   - tokensForSale: 100,000,000,000 MIMHO (18 decimals)
   - hardCap: 150 BNB
   - min buy: 0.050 BNB
   - max buy per wallet (cumulative): 5 BNB
   - window: 2026-04-06 16:20 ET to 2026-04-20 16:20 ET
            => UTC timestamps:
               start = 1775506800  (2026-04-06 20:20:00 UTC)
               end   = 1776716400  (2026-04-20 20:20:00 UTC)
   - BNB split:
       10% -> Founder SAFE (hardcoded)
       90% -> Liquidity Bootstrapper (which creates pool and burns LP tokens forever)
   - Unsold tokens: burned to 0x...dEaD (provable on-chain)

   ============================================================ */

import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IMIMHORegistry {
    function getContract(bytes32 key) external view returns (address);

    // Absolute Protocol: keys must be taken from Registry getters
    function KEY_MIMHO_EVENTS_HUB() external view returns (bytes32);
    function KEY_MIMHO_TOKEN() external view returns (bytes32);
    function KEY_MIMHO_VESTING() external view returns (bytes32);
    function KEY_MIMHO_LIQUIDITY_BOOTSTRAPER() external view returns (bytes32);
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

interface IMIMHOVesting {
    /// @notice Register a presale position.
    /// @dev Vesting must enforce: 20% already delivered, 5% weekly thereafter.
    function registerPresaleVesting(
        address beneficiary,
        uint256 totalPurchasedTokens,
        uint16 tgeBps,
        uint16 weeklyBps,
        uint64 startTimestamp
    ) external;
}

interface IMIMHOLiquidityBootstrapper {
    /// @notice Receives presale BNB. This contract must create the pool and burn LP tokens forever.
    function receivePresaleBNB() external payable;
}

contract MIMHOPresale is Ownable2Step, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /* =========================
       MIMHO ABSOLUTE CONSTANTS
       ========================= */

    string public constant version = "1.0.0";

    // Rule: Founder SAFE must be hardcoded in contracts with founder fees.
    address public constant FOUNDER_SAFE =
        0x3b50433D64193923199aAf209eE8222B9c728Fbd;

    // Burn to 0x...dEaD for public proof on explorers.
    address public constant DEAD_BURN =
        0x000000000000000000000000000000000000dEaD;

    // Optional: DAO SAFE / Security Reserve SAFE as ultimate rescue targets
    address public constant DAO_SAFE =
        0x63dd2eB7250612Ef7Dc24193ABbf7856fDaB7882;

    address public constant SECURITY_RESERVE_SAFE =
        0xc7B097384fe490B88D2d6EB032B1db702374C5eE;

    bytes32 public constant MODULE = keccak256("MIMHO_PRESALE");

    bytes32 private constant ACT_SYNC = keccak256("SYNC_FROM_REGISTRY");
    bytes32 private constant ACT_SET_LB = keccak256("SET_LIQUIDITY_BOOTSTRAPER");
    bytes32 private constant ACT_SET_VEST = keccak256("SET_VESTING");
    bytes32 private constant ACT_BUY = keccak256("BUY");
    bytes32 private constant ACT_FINALIZE = keccak256("FINALIZE");
    bytes32 private constant ACT_PUSH = keccak256("PUSH_FUNDS");
    bytes32 private constant ACT_PAUSE = keccak256("PAUSE");
    bytes32 private constant ACT_UNPAUSE = keccak256("UNPAUSE");
    bytes32 private constant ACT_SET_DAO = keccak256("SET_DAO");
    bytes32 private constant ACT_ACTIVATE_DAO = keccak256("ACTIVATE_DAO");
    bytes32 private constant ACT_RESCUE = keccak256("RESCUE_BNB");

    /* =========================
       CORE CONFIG (FINAL)
       ========================= */

    IMIMHORegistry public immutable registry;
    IERC20 public immutable mimhoToken;

    // 100B tokens for sale
    uint256 public constant TOKENS_FOR_SALE = 100_000_000_000 * 1e18;

    // Caps & limits
    uint256 public constant HARD_CAP_WEI = 150 ether;
    uint256 public constant MIN_BUY_WEI = 0.050 ether;
    uint256 public constant MAX_BUY_PER_WALLET_WEI = 5 ether;

    // Window (ET 16:20 => UTC 20:20)
    uint64 public constant SALE_START = 1775480400; // 2026-04-06 13:00:00 UTC = 06/04/2026 10:00 Brasil
    uint64 public constant SALE_END   = 1776690000; // 2026-04-20 13:00:00 UTC = 20/04/2026 10:00 Brasil

    // Vesting parameters
    uint16 public constant TGE_BPS = 2000;   // 20%
    uint16 public constant WEEKLY_BPS = 500; // 5% weekly

    // BNB split
    uint16 public constant FOUNDER_BPS = 1000; // 10%
    uint16 public constant LP_BPS = 9000;      // 90%

    // Price: tokensPerBNB is computed deterministically from allocation + hard cap.
    // tokensOut = bnbInWei * TOKENS_PER_BNB / 1e18
    // TOKENS_PER_BNB = floor(TOKENS_FOR_SALE * 1e18 / HARD_CAP_WEI)
    uint256 public constant TOKENS_PER_BNB =
        (TOKENS_FOR_SALE * 1e18) / HARD_CAP_WEI;

    /* =========================
       DAO TAKEOVER (STANDARD)
       ========================= */

    address public dao;
    bool public daoActivated;

    modifier onlyDAOorOwner() {
        if (daoActivated) {
            require(msg.sender == dao, "ONLY_DAO");
        } else {
            require(msg.sender == owner(), "ONLY_OWNER");
        }
        _;
    }

    /* =========================
       CACHED DEPENDENCIES
       ========================= */

    address public cachedVesting;                 // IMIMHOVesting
    address public cachedLiquidityBootstrapper;   // IMIMHOLiquidityBootstrapper

    /* =========================
       SALE STATE
       ========================= */

    bool public finalized;
    uint256 public totalRaisedWei;
    uint256 public totalSoldTokens;

    mapping(address => uint256) public spentWei;        // BNB cumulative per wallet
    mapping(address => uint256) public purchasedTokens; // total tokens per wallet (full amount)
    mapping(address => uint256) public pendingNative;

    // Retryable payouts
    bool public founderPaid;
    bool public liquidityPaid;

    /* =========================
       EVENTS (PUBLIC)
       ========================= */

    event SyncedFromRegistry(address indexed vesting, address indexed liquidityBootstrapper);

    event LiquidityBootstrapperSet(address indexed newAddr, bool forced, address indexed registryValue);
    event VestingSet(address indexed newAddr, bool forced, address indexed registryValue);

    event Purchase(
        address indexed buyer,
        uint256 bnbInWei,
        uint256 tokensTotal,
        uint256 tokensInstant,
        uint256 tokensVested
    );

    event Finalized(
        uint256 totalRaisedWei,
        uint256 totalSoldTokens,
        uint256 unsoldBurned,
        bool hardCapHit
    );

    event FundsPushed(
        bool founderPaidNow,
        bool liquidityPaidNow,
        uint256 founderAmount,
        uint256 liquidityAmount,
        address indexed liquidityBootstrapper
    );

    event RescueBNB(address indexed to, uint256 amount);

    event DAOSet(address indexed dao);
    event DAOActivated(address indexed dao);

    /* =========================
       CONSTRUCTOR
       ========================= */

    constructor(address registryAddress) {
        require(registryAddress != address(0), "REGISTRY_0");
        registry = IMIMHORegistry(registryAddress);

        address tokenAddr = registry.getContract(registry.KEY_MIMHO_TOKEN());
        require(tokenAddr != address(0), "TOKEN_NOT_SET");
        mimhoToken = IERC20(tokenAddr);

        _syncFromRegistry();
    }

    /* =========================
       VIEW BUTTONS (HUD)
       ========================= */

    function getDesignPhilosophy() external pure returns (string memory) {
        return
            "MIMHO Presale is simple and disposable: fixed window or hard cap, "
            "no soft cap, no refunds, same vesting for everyone (20% instant + 5% weekly), "
            "unsold burned to 0xdead, BNB split 10% founder SAFE hardcoded and 90% "
            "to LiquidityBootstrapper (pool creation + LP burn). "
            "Finalize never depends on external calls; fund push is retryable. "
            "Dependencies pulled from Registry KEYS and can be emergency-overridden post-finalize.";
    }

    function contractType() external pure returns (bytes32) {
        return MODULE;
    }

    function timeNow() external view returns (uint256) {
        return block.timestamp;
    }

    function saleActive() public view returns (bool) {
        if (finalized) return false;
        if (paused()) return false;
        if (block.timestamp < SALE_START) return false;
        if (block.timestamp >= SALE_END) return false;
        if (totalRaisedWei >= HARD_CAP_WEI) return false;
        if (totalSoldTokens >= TOKENS_FOR_SALE) return false;
        return true;
    }

    function remainingCapWei() external view returns (uint256) {
        if (totalRaisedWei >= HARD_CAP_WEI) return 0;
        return HARD_CAP_WEI - totalRaisedWei;
    }

    function remainingTokens() external view returns (uint256) {
        if (totalSoldTokens >= TOKENS_FOR_SALE) return 0;
        return TOKENS_FOR_SALE - totalSoldTokens;
    }

    function quoteTokens(uint256 bnbInWei) public pure returns (uint256) {
        return (bnbInWei * TOKENS_PER_BNB) / 1e18;
    }

    /// @notice Presale unit price in wei per 1 token (1e18 units).
    /// @dev Deterministic and derived from TOKENS_FOR_SALE / HARD_CAP.
    ///      Used by LiquidityBootstrapper to validate constructor config.
    function presalePriceWeiPerToken() external pure returns (uint256) {
        // Because token has 18 decimals:
        // tokensOut = bnbWei * TOKENS_PER_BNB / 1e18
        // => priceWeiPerToken = 1e36 / TOKENS_PER_BNB
        return (1e36) / TOKENS_PER_BNB;
    }

    function requiredTokenDeposit() external pure returns (uint256) {
        return TOKENS_FOR_SALE;
    }

    /* =========================
       REGISTRY SYNC
       ========================= */

    function syncFromRegistry() external onlyDAOorOwner {
        _syncFromRegistry();
        _emitHubEvent(ACT_SYNC, msg.sender, 0, abi.encode(cachedVesting, cachedLiquidityBootstrapper));
    }

    function _syncFromRegistry() internal {
        address vest = registry.getContract(registry.KEY_MIMHO_VESTING());
        address lb = registry.getContract(registry.KEY_MIMHO_LIQUIDITY_BOOTSTRAPER());

        cachedVesting = vest;
        cachedLiquidityBootstrapper = lb;

        emit SyncedFromRegistry(vest, lb);
    }

    /* =========================
       EMERGENCY SETTERS (SAFE)
       ========================= */

    /// @notice Set Liquidity Bootstrapper address.
    /// @dev Normal mode: must match Registry value (if Registry has one).
    ///      Forced mode: only allowed AFTER finalize and BEFORE liquidityPaid.
    function setLiquidityBootstrapper(address newAddr, bool force) external onlyDAOorOwner {
        require(newAddr != address(0), "LB_0");

        address reg = registry.getContract(registry.KEY_MIMHO_LIQUIDITY_BOOTSTRAPER());

        if (!force) {
            // Safer default: only accept if matches registry OR registry is unset (0)
            require(reg == address(0) || reg == newAddr, "LB_MUST_MATCH_REGISTRY");
        } else {
            require(finalized, "FORCE_ONLY_AFTER_FINALIZE");
            require(!liquidityPaid, "LB_ALREADY_PAID");
        }

        cachedLiquidityBootstrapper = newAddr;
        emit LiquidityBootstrapperSet(newAddr, force, reg);

        _emitHubEvent(ACT_SET_LB, msg.sender, 0, abi.encode(newAddr, force, reg));
    }

    /// @notice Set Vesting address.
    /// @dev Normal mode: must match Registry value (if Registry has one).
    ///      Forced mode: only allowed BEFORE sale starts OR AFTER finalize (to avoid mid-sale changes).
    function setVesting(address newAddr, bool force) external onlyDAOorOwner {
        require(newAddr != address(0), "VEST_0");

        address reg = registry.getContract(registry.KEY_MIMHO_VESTING());

        if (!force) {
            require(reg == address(0) || reg == newAddr, "VEST_MUST_MATCH_REGISTRY");
        } else {
            // Strict: do not allow forced changes during the active sale.
            bool beforeStart = block.timestamp < SALE_START;
            bool afterFinalize = finalized;
            require(beforeStart || afterFinalize, "FORCE_NOT_DURING_SALE");
        }

        cachedVesting = newAddr;
        emit VestingSet(newAddr, force, reg);

        _emitHubEvent(ACT_SET_VEST, msg.sender, 0, abi.encode(newAddr, force, reg));
    }

    /* =========================
       BUY
       ========================= */

    receive() external payable {
    // During sale: treat direct BNB as a buy (auto-buy).
    if (saleActive()) {
        buy();
        return;
    }

    // Outside sale: ONLY allow BNB from LiquidityBootstrapper (refund/excess),
    // or from Owner (manual administrative funding if ever needed).
    address lb = cachedLiquidityBootstrapper;

    require(
        msg.sender == lb || msg.sender == owner(),
        "BNB_BLOCKED"
    );
}

    function buy() public payable nonReentrant whenNotPaused {
        require(saleActive(), "SALE_NOT_ACTIVE");
        require(msg.value >= MIN_BUY_WEI, "BELOW_MIN");

        uint256 newSpent = spentWei[msg.sender] + msg.value;
        require(newSpent <= MAX_BUY_PER_WALLET_WEI, "ABOVE_MAX_WALLET");
        require(totalRaisedWei + msg.value <= HARD_CAP_WEI, "ABOVE_HARD_CAP");

        // Ensure token deposit is present (never sell what you don't have)
        // Must hold enough tokens to cover remaining sale allocation.
        // totalSoldTokens includes both instant + vested.
        require(mimhoToken.balanceOf(address(this)) >= (TOKENS_FOR_SALE - totalSoldTokens), "INSUFFICIENT_TOKEN_DEPOSIT");

        address vestingAddr = cachedVesting;
        require(vestingAddr != address(0), "VESTING_NOT_SET");

        uint256 tokensTotal = quoteTokens(msg.value);
        require(tokensTotal > 0, "TOKENS_0");

        uint256 newTotalSold = totalSoldTokens + tokensTotal;
        require(newTotalSold <= TOKENS_FOR_SALE, "SOLD_OUT");

        // Effects
        spentWei[msg.sender] = newSpent;
        totalRaisedWei += msg.value;
        purchasedTokens[msg.sender] += tokensTotal;
        totalSoldTokens = newTotalSold;

        // Interactions
        uint256 tokensInstant = (tokensTotal * TGE_BPS) / 10_000;
        uint256 tokensVested = tokensTotal - tokensInstant;

        if (tokensInstant > 0) {
            mimhoToken.safeTransfer(msg.sender, tokensInstant);
        }

        if (tokensVested > 0) {
            mimhoToken.safeTransfer(vestingAddr, tokensVested);
            IMIMHOVesting(vestingAddr).registerPresaleVesting(
                msg.sender,
                tokensTotal,                 // total purchased
                TGE_BPS,                     // already delivered by presale
                WEEKLY_BPS,                  // 5% weekly
                uint64(block.timestamp)      // vest start at purchase time
            );
        }

        emit Purchase(msg.sender, msg.value, tokensTotal, tokensInstant, tokensVested);
        _emitHubEvent(ACT_BUY, msg.sender, msg.value, abi.encode(tokensTotal, tokensInstant, tokensVested));
    }

    /* =========================
       FINALIZE (NO EXTERNAL RISK)
       ========================= */

    function finalize() external nonReentrant {
        require(!finalized, "FINALIZED");

        bool hardCapHit = totalRaisedWei >= HARD_CAP_WEI;
        bool timeEnded = block.timestamp >= SALE_END;
        bool soldOut = totalSoldTokens >= TOKENS_FOR_SALE;

        require(hardCapHit || timeEnded || soldOut, "NOT_END");

        finalized = true;

        // Burn unsold tokens to 0x...dEaD (provable on-chain)
        uint256 unsold = TOKENS_FOR_SALE - totalSoldTokens;
        if (unsold > 0) {
            mimhoToken.safeTransfer(DEAD_BURN, unsold);
        }

        emit Finalized(totalRaisedWei, totalSoldTokens, unsold, hardCapHit);
        _emitHubEvent(ACT_FINALIZE, msg.sender, totalRaisedWei, abi.encode(totalSoldTokens, unsold, hardCapHit, timeEnded, soldOut));
    }

    /* =========================
       PUSH FUNDS (RETRYABLE, SAFE)
       ========================= */

    /// @notice Push BNB split: 10% founder + 90% liquidity bootstrapper.
    /// @dev Retryable: if LB call fails, fix address then call again.
    function pushFunds() external nonReentrant {
    require(finalized, "NOT_FINALIZED");

    uint256 founderAmount = (totalRaisedWei * FOUNDER_BPS) / 10_000;
    uint256 liquidityAmount = totalRaisedWei - founderAmount;

    bool founderPaidNow = false;
    bool founderQueuedNow = false;

    bool liquidityPaidNow = false;
    bool liquidityQueuedNow = false;

    // ---------- EFFECTS FIRST ----------
    // Mark intent via flags only when we successfully pay OR queue.
    // (We do NOT set founderPaid/liquidityPaid until after each path completes)

    // ---------- FOUNDER PAYOUT ----------
    if (!founderPaid && founderAmount > 0) {
        // Try immediate push
        (bool ok, ) = payable(FOUNDER_SAFE).call{value: founderAmount}("");
        if (ok) {
            founderPaid = true;
            founderPaidNow = true;
        } else {
            // Fallback to pending
            pendingNative[FOUNDER_SAFE] += founderAmount;
            founderPaid = true;
            founderQueuedNow = true;
        }
    }

    // ---------- LIQUIDITY BOOTSTRAPPER PAYOUT ----------
    if (!liquidityPaid && liquidityAmount > 0) {
        address lb = cachedLiquidityBootstrapper;
        require(lb != address(0), "LB_NOT_SET");

        // Try to push to LB handler (preferred)
        try IMIMHOLiquidityBootstrapper(lb).receivePresaleBNB{value: liquidityAmount}() {
            liquidityPaid = true;
            liquidityPaidNow = true;
        } catch {
            // Fallback to pending
            pendingNative[lb] += liquidityAmount;
            liquidityPaid = true;
            liquidityQueuedNow = true;
        }
    }

    emit FundsPushed(
        founderPaidNow || founderQueuedNow,
        liquidityPaidNow || liquidityQueuedNow,
        founderAmount,
        liquidityAmount,
        cachedLiquidityBootstrapper
    );

    _emitHubEvent(
        ACT_PUSH,
        msg.sender,
        address(this).balance,
        abi.encode(
            founderPaidNow,
            founderQueuedNow,
            liquidityPaidNow,
            liquidityQueuedNow,
            founderAmount,
            liquidityAmount,
            cachedLiquidityBootstrapper
        )
    );
}

function claimPendingNative() external nonReentrant {
    uint256 amt = pendingNative[msg.sender];
    require(amt > 0, "NOTHING_PENDING");
    require(address(this).balance >= amt, "INSUFFICIENT_BAL");

    pendingNative[msg.sender] = 0;

    (bool ok, ) = payable(msg.sender).call{value: amt}("");
    require(ok, "NATIVE_SEND_FAIL");
}

    /* =========================
       EMERGENCY RESCUE (ULTIMATE)
       ========================= */

    /// @notice Ultimate rescue in case LB is unrecoverable.
    /// @dev Only after finalize and only if liquidity not paid. Destination restricted to SAFE wallets.
    function rescueBNB(address to, uint256 amount) external onlyDAOorOwner nonReentrant {
        require(finalized, "NOT_FINALIZED");
        require(!liquidityPaid, "LIQ_ALREADY_PAID");
        require(to == DAO_SAFE || to == SECURITY_RESERVE_SAFE, "TO_NOT_ALLOWED");
        require(amount > 0 && amount <= address(this).balance, "BAD_AMOUNT");

        (bool ok, ) = payable(to).call{value: amount}("");
        require(ok, "RESCUE_FAIL");

        emit RescueBNB(to, amount);
        _emitHubEvent(ACT_RESCUE, msg.sender, amount, abi.encode(to));
    }

    /* =========================
       PAUSE (STANDARD)
       ========================= */

    function pauseEmergencial() external onlyDAOorOwner {
        _pause();
        _emitHubEvent(ACT_PAUSE, msg.sender, 0, "");
    }

    function unpause() external onlyDAOorOwner {
        _unpause();
        _emitHubEvent(ACT_UNPAUSE, msg.sender, 0, "");
    }

    /* =========================
       DAO TAKEOVER (STANDARD)
       ========================= */

    function setDAO(address dao_) external onlyOwner {
        require(dao_ != address(0), "DAO_0");
        dao = dao_;
        emit DAOSet(dao_);
        _emitHubEvent(ACT_SET_DAO, msg.sender, 0, abi.encode(dao_));
    }

    function activateDAO() external onlyOwner {
        require(dao != address(0), "DAO_NOT_SET");
        daoActivated = true;
        emit DAOActivated(dao);
        _emitHubEvent(ACT_ACTIVATE_DAO, msg.sender, 0, abi.encode(dao));
    }

    /* =========================
       EVENTS HUB (BEST-EFFORT)
       ========================= */

    function _emitHubEvent(
        bytes32 action,
        address caller,
        uint256 value,
        bytes memory data
    ) internal {
        address hubAddr = registry.getContract(registry.KEY_MIMHO_EVENTS_HUB());
        if (hubAddr == address(0)) return;

        try IMIMHOEventsHub(hubAddr).emitEvent(MODULE, action, caller, value, data) {
            // best-effort ok
        } catch {
            // never block main logic
        }
    }
}
