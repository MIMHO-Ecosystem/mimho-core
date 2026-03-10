/// -----------------------------------------------------------------------
/// MIMHO AIRDROP
/// Official MIMHO Ecosystem Contract
///
/// Network: BNB Smart Chain
/// Contract Address:
/// 0xe7cf8372F1b433Fe6A7c116fc1653276dF9caCE3
///
/// BscScan:
/// https://bscscan.com/address/0xe7cf8372F1b433Fe6A7c116fc1653276dF9caCE3
/// -----------------------------------------------------------------------

// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/* ============================================================
   MIMHO AIRDROPS — v1.1.0 (Absolute MIMHO Protocol)
   ============================================================

   DESIGN PHILOSOPHY (ENGLISH)

   - Prefunded Treasury (Anti-Draining):
     This contract distributes ONLY what it holds. No transferFrom() from
     external wallets. This removes "arbitrary-send-erc20" concerns.

   - Scalability First:
     Eligibility is defined off-chain by a Merkle tree and verified on-chain
     with MerkleProof.

   - Incentives Stay On-Chain:
     Base entitlement is Merkle-defined, bonuses computed on-chain at claim time.

   - Registry-First:
     Resolve all dependencies via Registry KEY getters and registry.getContract(key).

   - CEI "Ninja":
     State updates immediately after requires, external interactions at the end.

   ============================================================ */

import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

interface IERC20 {
    function balanceOf(address a) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool); // ✅ needed for prefunded payouts
}

interface IMIMHOEventsHub {
    function emitEvent(bytes32 module, bytes32 action, address caller, uint256 value, bytes calldata data) external;
}

interface IMIMHORegistry {
    function getContract(bytes32 key) external view returns (address);
    function isEcosystemContract(address a) external view returns (bool);

    function KEY_MIMHO_TOKEN() external view returns (bytes32);
    function KEY_MIMHO_EVENTS_HUB() external view returns (bytes32);
    function KEY_MIMHO_DAO() external view returns (bytes32);
    function KEY_MIMHO_VERITAS() external view returns (bytes32);
    function KEY_MIMHO_LABS() external view returns (bytes32);
}

interface IMIMHOVeritasPrice {
    function getUSDPrice(address token) external view returns (uint256);
}

interface IMIMHOLabs {
    function isWhitelisted(address requester) external view returns (bool);
    function getConsultaFee() external view returns (uint256);
    function feeCollector() external view returns (address);
}

interface IMIMHOAirdrop {
    function version() external view returns (string memory);
    function startNextCycle(bytes32 merkleRoot) external;
    function claim(uint256 baseAmount, bytes32[] calldata proof) external;
    function getRules()
        external
        view
        returns (
            uint256 minUsdRequired,
            uint256 absoluteCycleCap,
            uint256 maxPercentOfMarketing,
            uint256 cycleDuration,
            uint256 maxRewardPerUser,
            uint256 maxBonusPercent,
            uint256 defaultManualPriceUsd18
        );
}

contract MIMHOAirdrop is IMIMHOAirdrop, Ownable2Step, Pausable, ReentrancyGuard {
    /* ----------------------------- Constants ----------------------------- */

    bytes32 public constant MODULE = keccak256("MIMHO_AIRDROPS");

    uint256 public constant MAX_BONUS_PERCENT = 10;
    uint256 public constant MAX_TASKS = 20;
    uint256 public constant USD_DECIMALS = 1e18;

    /* ------------------------------ Immutables --------------------------- */

    IMIMHORegistry public immutable registry;
    address public immutable marketingWallet;

    uint256 public immutable cycleDuration;
    uint256 public immutable absoluteCycleCap;
    uint256 public immutable minUsdRequired;

    /* ------------------------------ Storage ------------------------------ */

    string public constant override version = "1.1.0";

    address public dao;
    bool public daoActivated;

    uint256 public maxPercentOfMarketing = 5;
    uint256 public maxRewardPerUser = 0;

    uint256 public defaultManualPriceUsd18 = 0;

    uint256 public cycleId;
    uint256 public lastCycleStart;

    mapping(uint256 => mapping(address => bool)) public hasClaimed;
    mapping(address => bool) public systemAddress;

    struct Cycle {
        bytes32 merkleRoot;
        uint256 budget;
        uint256 spent;
        uint256 claims;
        uint256 startTs;
        uint256 priceUsd18;
        bool manualPrice;
    }

    mapping(uint256 => Cycle) internal cycles;

    struct BonusTask {
        bool active;
        uint8 bonusPercent;
        address verifier;
        bytes4 selector;
        bytes32 label;
    }

    bytes32[] public taskIds;
    mapping(bytes32 => BonusTask) public tasks;

    /* --------------------------- Events (local) -------------------------- */

    event NewCycle(uint256 indexed cycleId, uint256 startTs, uint256 budget, bytes32 merkleRoot, uint256 priceUsd18, bool manualPrice);
    event Claimed(uint256 indexed cycleId, address indexed user, uint256 baseAmount, uint256 bonusPercent, uint256 paidAmount);
    event BudgetExhausted(uint256 indexed cycleId, uint256 spent, uint256 budget);

    event SystemAddressSet(address indexed addr, bool isSystem);
    event TaskSet(bytes32 indexed taskId, bool active, uint8 bonusPercent, address verifier, bytes4 selector, bytes32 label);

    event ParamsUpdated(bytes32 indexed param, uint256 oldValue, uint256 newValue);
    event DAOSet(address indexed oldDAO, address indexed newDAO);
    event DAOActivated(address indexed dao);

    event CyclePriceSet(uint256 indexed cycleId, uint256 priceUsd18, bool manual);

    /* ------------------------------- Errors ------------------------------ */

    error NotDAOorOwner();
    error CycleNotReady();
    error InvalidParam();
    error ZeroAddress();
    error NotEligible(bytes32 reason);
    error AlreadyClaimed();
    error BudgetOver();

    /* ------------------------------ Modifiers ---------------------------- */

    modifier onlyDAOorOwner() {
        if (msg.sender != owner() && msg.sender != dao) revert NotDAOorOwner();
        _;
    }

    /* ------------------------------ Constructor -------------------------- */

    constructor(
        address registryAddr,
        address marketingWalletAddr,
        uint256 cycleDurationSeconds,
        uint256 absoluteCycleCapAmount,
        uint256 minUsdRequired18
    ) {
        if (registryAddr == address(0) || marketingWalletAddr == address(0)) revert ZeroAddress();
        if (cycleDurationSeconds < 7 days || cycleDurationSeconds > 180 days) revert InvalidParam();
        if (absoluteCycleCapAmount == 0) revert InvalidParam();
        if (minUsdRequired18 == 0) revert InvalidParam();

        registry = IMIMHORegistry(registryAddr);
        marketingWallet = marketingWalletAddr;

        cycleDuration = cycleDurationSeconds;
        absoluteCycleCap = absoluteCycleCapAmount;
        minUsdRequired = minUsdRequired18;

        lastCycleStart = block.timestamp;
        cycleId = 1;

        _refreshDAO();

        systemAddress[marketingWalletAddr] = true;
        emit SystemAddressSet(marketingWalletAddr, true);

        cycles[cycleId] = Cycle({
            merkleRoot: bytes32(0),
            budget: 0,
            spent: 0,
            claims: 0,
            startTs: lastCycleStart,
            priceUsd18: 0,
            manualPrice: false
        });
    }

    /* ---------------------- Registry / Dependency helpers ---------------- */

    function _refreshDAO() internal {
        address daoAddr = registry.getContract(registry.KEY_MIMHO_DAO());
        if (daoAddr != address(0)) dao = daoAddr;
    }

    function mimhoToken() public view returns (address) {
        return registry.getContract(registry.KEY_MIMHO_TOKEN());
    }

    function veritas() public view returns (address) {
        return registry.getContract(registry.KEY_MIMHO_VERITAS());
    }

    function labs() public view returns (address) {
        return registry.getContract(registry.KEY_MIMHO_LABS());
    }

    /* ------------------------ Events Hub (HUD) hook ---------------------- */

    function _emitHubEvent(bytes32 action, address caller, uint256 value, bytes memory data) internal {
        address hubAddr = registry.getContract(registry.KEY_MIMHO_EVENTS_HUB());
        if (hubAddr == address(0)) return;
        try IMIMHOEventsHub(hubAddr).emitEvent(MODULE, action, caller, value, data) {
        } catch {
        }
    }

    /* -------------------------- Public View “HUD buttons” ---------------- */

    function getRules()
        external
        view
        override
        returns (
            uint256 _minUsdRequired,
            uint256 _absoluteCycleCap,
            uint256 _maxPercentOfMarketing,
            uint256 _cycleDuration,
            uint256 _maxRewardPerUser,
            uint256 _maxBonusPercent,
            uint256 _defaultManualPriceUsd18
        )
    {
        _minUsdRequired = minUsdRequired;
        _absoluteCycleCap = absoluteCycleCap;
        _maxPercentOfMarketing = maxPercentOfMarketing;
        _cycleDuration = cycleDuration;
        _maxRewardPerUser = maxRewardPerUser;
        _maxBonusPercent = MAX_BONUS_PERCENT;
        _defaultManualPriceUsd18 = defaultManualPriceUsd18;
    }

    function getCycle(uint256 cid)
        external
        view
        returns (
            uint256 id,
            uint256 startTs,
            uint256 duration,
            uint256 budget,
            uint256 spent,
            uint256 claims,
            uint256 nextStartTs,
            bytes32 merkleRoot,
            uint256 priceUsd18,
            bool manualPrice
        )
    {
        Cycle memory c = cycles[cid];
        id = cid;
        startTs = c.startTs;
        duration = cycleDuration;
        budget = c.budget;
        spent = c.spent;
        claims = c.claims;
        nextStartTs = c.startTs + cycleDuration;
        merkleRoot = c.merkleRoot;
        priceUsd18 = c.priceUsd18;
        manualPrice = c.manualPrice;
    }

    function isSystem(address a) public view returns (bool) {
        if (a == address(0)) return true;
        if (systemAddress[a]) return true;
        if (a == owner() || a == dao || a == marketingWallet) return true;
        if (a.code.length > 0) return true;
        if (registry.isEcosystemContract(a)) return true;
        return false;
    }

    function getUserUsdValueWithCyclePrice(uint256 cid, address user)
        public
        view
        returns (uint256 usdValue18, uint256 priceUsd18, uint256 balance)
    {
        address token = mimhoToken();
        if (token == address(0)) return (0, 0, 0);

        balance = IERC20(token).balanceOf(user);
        priceUsd18 = cycles[cid].priceUsd18;
        if (priceUsd18 == 0) return (0, 0, balance);

        usdValue18 = (balance * priceUsd18) / 1e18;
    }

    function getUserBonusPercent(address user) public view returns (uint256 totalBonus, uint256 taskCount) {
        require(user != address(0), "ZERO_USER");

        uint256 n = taskIds.length;
        if (n == 0) return (0, 0);

        for (uint256 i = 0; i < n; i++) {
            BonusTask memory t = tasks[taskIds[i]];
            if (!t.active) continue;

            (bool ok, bytes memory ret) = t.verifier.staticcall(abi.encodeWithSelector(t.selector, user));
            if (ok && ret.length >= 32 && abi.decode(ret, (bool))) {
                totalBonus += t.bonusPercent;
                taskCount++;
                if (totalBonus >= MAX_BONUS_PERCENT) {
                    totalBonus = MAX_BONUS_PERCENT;
                    break;
                }
            }
        }
    }

    function leafFor(address user, uint256 baseAmount) public pure returns (bytes32) {
        return keccak256(abi.encode(user, baseAmount));
    }

    function verifyEligibility(uint256 cid, address user, uint256 baseAmount, bytes32[] calldata proof) public view returns (bool) {
        bytes32 root = cycles[cid].merkleRoot;
        if (root == bytes32(0)) return false;
        return MerkleProof.verify(proof, root, leafFor(user, baseAmount));
    }

    function isEligibleView(uint256 cid, address user, uint256 baseAmount, bytes32[] calldata proof)
        external
        view
        returns (bool eligible, bytes32 reason)
    {
        return _isEligible(cid, user, baseAmount, proof, false);
    }

    function _isEligible(uint256 cid, address user, uint256 baseAmount, bytes32[] calldata proof, bool enforceCaller)
        internal
        view
        returns (bool eligible, bytes32 reason)
    {
        if (paused()) return (false, keccak256("PAUSED"));
        if (isSystem(user)) return (false, keccak256("SYSTEM_ADDRESS"));
        if (enforceCaller && msg.sender != user) return (false, keccak256("CALLER_MISMATCH"));
        if (hasClaimed[cid][user]) return (false, keccak256("ALREADY_CLAIMED"));
        if (!verifyEligibility(cid, user, baseAmount, proof)) return (false, keccak256("INVALID_MERKLE_PROOF"));

        (uint256 usdValue18,,) = getUserUsdValueWithCyclePrice(cid, user);
        if (usdValue18 < minUsdRequired) return (false, keccak256("MIN_USD_NOT_MET"));

        return (true, bytes32(0));
    }

    /* ------------------------------ Cycle logic -------------------------- */

    function startNextCycle(bytes32 merkleRoot) external override whenNotPaused {
        if (merkleRoot == bytes32(0)) revert InvalidParam();
        if (block.timestamp < lastCycleStart + cycleDuration) revert CycleNotReady();

        _refreshDAO();

        cycleId += 1;
        lastCycleStart = block.timestamp;

        address token = mimhoToken();
        if (token == address(0)) revert InvalidParam();

        // ✅ Prefunded logic: budget based on THIS CONTRACT balance (treasury)
        uint256 treasuryBal = IERC20(token).balanceOf(address(this));
        uint256 percentCap = (treasuryBal * maxPercentOfMarketing) / 100;
        uint256 budget = percentCap < absoluteCycleCap ? percentCap : absoluteCycleCap;

        uint256 priceUsd18 = 0;
        bool manual = false;

        address v = veritas();
        if (v != address(0)) {
            try IMIMHOVeritasPrice(v).getUSDPrice(token) returns (uint256 p) {
                priceUsd18 = p;
            } catch {
                priceUsd18 = 0;
            }
        }

        if (priceUsd18 == 0) {
            priceUsd18 = defaultManualPriceUsd18;
            manual = true;
        }

        cycles[cycleId] = Cycle({
            merkleRoot: merkleRoot,
            budget: budget,
            spent: 0,
            claims: 0,
            startTs: lastCycleStart,
            priceUsd18: priceUsd18,
            manualPrice: manual
        });

        emit NewCycle(cycleId, lastCycleStart, budget, merkleRoot, priceUsd18, manual);
        _emitHubEvent(keccak256("NEW_CYCLE"), msg.sender, budget, abi.encode(cycleId, lastCycleStart, budget, merkleRoot, priceUsd18, manual));
    }

    function setCycleManualPrice(uint256 cid, uint256 priceUsd18) external onlyDAOorOwner {
        if (cid == 0 || cid > cycleId) revert InvalidParam();
        if (priceUsd18 == 0) revert InvalidParam();

        cycles[cid].priceUsd18 = priceUsd18;
        cycles[cid].manualPrice = true;

        emit CyclePriceSet(cid, priceUsd18, true);
        _emitHubEvent(keccak256("CYCLE_PRICE_SET"), msg.sender, priceUsd18, abi.encode(cid, priceUsd18, true));
    }

    function setDefaultManualPriceUsd18(uint256 priceUsd18) external onlyDAOorOwner {
        if (priceUsd18 == 0) revert InvalidParam();
        emit ParamsUpdated(keccak256("DEFAULT_MANUAL_PRICE_USD18"), defaultManualPriceUsd18, priceUsd18);
        _emitHubEvent(keccak256("PARAM_UPDATE"), msg.sender, priceUsd18, abi.encode("DEFAULT_MANUAL_PRICE_USD18", defaultManualPriceUsd18, priceUsd18));
        defaultManualPriceUsd18 = priceUsd18;
    }

    /* ------------------------------ Claim logic -------------------------- */

    function claim(uint256 baseAmount, bytes32[] calldata proof) external override nonReentrant whenNotPaused {
        Cycle storage c = cycles[cycleId];
        if (c.merkleRoot == bytes32(0)) revert InvalidParam();

        // Checks
        (bool ok, bytes32 reason) = _isEligible(cycleId, msg.sender, baseAmount, proof, true);
        if (!ok) revert NotEligible(reason);
        if (c.priceUsd18 == 0) revert InvalidParam();

        uint256 budget = c.budget;
        if (c.spent >= budget) revert BudgetOver();

        (uint256 bonusPercent,) = getUserBonusPercent(msg.sender);
        if (bonusPercent > MAX_BONUS_PERCENT) bonusPercent = MAX_BONUS_PERCENT;

        uint256 amountToPay = baseAmount + ((baseAmount * bonusPercent) / 100);

        // Cap against absoluteCycleCap BEFORE any transfer attempt
        if (amountToPay > absoluteCycleCap) amountToPay = absoluteCycleCap;

        if (maxRewardPerUser != 0 && amountToPay > maxRewardPerUser) {
            amountToPay = maxRewardPerUser;
        }

        uint256 remaining = budget - c.spent;
        if (amountToPay > remaining) amountToPay = remaining;

        // ✅ Prefunded safety: contract must have enough balance
        address token = mimhoToken();
        require(amountToPay <= IERC20(token).balanceOf(address(this)), "Insufficient airdrop funds");

        // Effects (CEI)
        hasClaimed[cycleId][msg.sender] = true;
        c.claims += 1;
        c.spent += amountToPay;

        // Interaction LAST (pay from contract treasury)
        bool sent = IERC20(token).transfer(msg.sender, amountToPay);
        require(sent, "TRANSFER_FAILED");

        // Events LAST
        emit Claimed(cycleId, msg.sender, baseAmount, bonusPercent, amountToPay);
        _emitHubEvent(keccak256("CLAIM"), msg.sender, amountToPay, abi.encode(cycleId, baseAmount, bonusPercent, amountToPay));
    }

    /* ------------------------ Bonus tasks (expandable) ------------------- */

    function setTask(
        bytes32 taskId,
        bool active,
        uint8 bonusPercent,
        address verifier,
        bytes4 selector,
        bytes32 label
    ) external onlyDAOorOwner {
        if (bonusPercent > MAX_BONUS_PERCENT) revert InvalidParam();
        if (verifier == address(0) || selector == bytes4(0)) revert InvalidParam();

        if (tasks[taskId].verifier == address(0)) {
            require(taskIds.length < MAX_TASKS, "MAX_TASKS");
            taskIds.push(taskId);
        }

        tasks[taskId] = BonusTask({
            active: active,
            bonusPercent: bonusPercent,
            verifier: verifier,
            selector: selector,
            label: label
        });

        emit TaskSet(taskId, active, bonusPercent, verifier, selector, label);
        _emitHubEvent(keccak256("TASK_SET"), msg.sender, bonusPercent, abi.encode(taskId, active, verifier, selector, label));
    }

    function getTaskCount() external view returns (uint256) {
        return taskIds.length;
    }

    function getTaskId(uint256 index) external view returns (bytes32) {
        return taskIds[index];
    }

    function getTask(bytes32 taskId) external view returns (BonusTask memory) {
        return tasks[taskId];
    }

    /* -------------------------- System address admin --------------------- */

    function setSystemAddress(address addr, bool isSys) external onlyDAOorOwner {
        if (addr == address(0)) revert ZeroAddress();
        systemAddress[addr] = isSys;
        emit SystemAddressSet(addr, isSys);
        _emitHubEvent(keccak256("SYSTEM_SET"), msg.sender, isSys ? 1 : 0, abi.encode(addr));
    }

    /* -------------------------- Params / Governance ---------------------- */

    function setDAO(address newDao) external onlyOwner {
        require(newDao != address(0), "ZERO_DAO");

        address old = dao;
        dao = newDao;
        emit DAOSet(old, newDao);

        _emitHubEvent(keccak256("DAO_SET"), msg.sender, 0, abi.encode(old, newDao));
    }

    function activateDAO() external onlyOwner {
        daoActivated = true;
        emit DAOActivated(dao);
        _emitHubEvent(keccak256("DAO_ACTIVATED"), msg.sender, 0, abi.encode(dao));
    }

    function setMaxPercentOfMarketing(uint256 newPercent) external onlyDAOorOwner {
        if (newPercent == 0 || newPercent > 25) revert InvalidParam();

        uint256 old = maxPercentOfMarketing;
        maxPercentOfMarketing = newPercent;

        emit ParamsUpdated(keccak256("MAX_PERCENT_MARKETING"), old, newPercent);
        _emitHubEvent(keccak256("PARAM_UPDATE"), msg.sender, newPercent, abi.encode("MAX_PERCENT_MARKETING", old, newPercent));
    }

    function setMaxRewardPerUser(uint256 newMax) external onlyDAOorOwner {
        uint256 old = maxRewardPerUser;
        maxRewardPerUser = newMax;

        emit ParamsUpdated(keccak256("MAX_REWARD_PER_USER"), old, newMax);
        _emitHubEvent(keccak256("PARAM_UPDATE"), msg.sender, newMax, abi.encode("MAX_REWARD_PER_USER", old, newMax));
    }

    /* ------------------------------- Pause ------------------------------- */

    function pauseEmergencial() external onlyDAOorOwner {
        _pause();
        _emitHubEvent(keccak256("PAUSED"), msg.sender, 0, "");
    }

    function unpause() external onlyDAOorOwner {
        _unpause();
        _emitHubEvent(keccak256("UNPAUSED"), msg.sender, 0, "");
    }

    /* -------------------- MIMHO Labs monetized read API ------------------ */

    function labsConsultaElegibilidade(
        uint256 cid,
        address user,
        uint256 baseAmount,
        bytes32[] calldata proof
    )
        external
        payable
        returns (bool eligible, bytes32 reason, uint256 bonusPercent, uint256 estimatedPay)
    {
        address labsAddr = labs();
        if (labsAddr != address(0)) {
            uint256 fee = IMIMHOLabs(labsAddr).getConsultaFee();
            bool free = IMIMHOLabs(labsAddr).isWhitelisted(msg.sender);
            if (!free) {
                require(msg.value >= fee, "FEE_TOO_LOW");
                address collector = IMIMHOLabs(labsAddr).feeCollector();
                if (collector != address(0)) {
                    (bool ok,) = collector.call{value: msg.value}("");
                    require(ok, "FEE_FORWARD_FAIL");
                }
            }
        }

        (eligible, reason) = _isEligible(cid, user, baseAmount, proof, false);

        if (eligible) {
            (bonusPercent,) = getUserBonusPercent(user);
            if (bonusPercent > MAX_BONUS_PERCENT) bonusPercent = MAX_BONUS_PERCENT;

            estimatedPay = baseAmount + ((baseAmount * bonusPercent) / 100);
            if (estimatedPay > absoluteCycleCap) estimatedPay = absoluteCycleCap;
            if (maxRewardPerUser != 0 && estimatedPay > maxRewardPerUser) estimatedPay = maxRewardPerUser;
        }

        _emitHubEvent(keccak256("LABS_QUERY"), msg.sender, eligible ? 1 : 0, abi.encode(cid, user, reason, baseAmount, bonusPercent, estimatedPay));
    }

    receive() external payable {}
}
