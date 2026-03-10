<<<<<<< HEAD
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

abstract contract MIMHO Registry {
    string public constant version = "0.0.0-placeholder";
    function contractType() public pure virtual returns (bytes32) { return keccak256("MIMHO_REGISTRY"); }
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
abstract contract MIMHO_Registry {
    /// @notice Human readable version for repository tracking (not on-chain guarantee).
    string public constant version = "0.0.0-placeholder";

    /// @notice Contract module type identifier (used by HUD/Events Hub in final builds).
    function contractType() public pure virtual returns (bytes32) {
        return CONTRACT_TYPE;
    }
}
=======
/// -----------------------------------------------------------------------
/// MIMHO REGISTRY
/// Official MIMHO Ecosystem Contract
///
/// Network: BNB Smart Chain
/// Contract Address:
/// 0xc707A83FD152f772cd91A9A6b50FEDaa13454046
///
/// BscScan:
/// https://bscscan.com/address/0xc707A83FD152f772cd91A9A6b50FEDaa13454046
/// -----------------------------------------------------------------------

// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/access/Ownable2Step.sol";

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
    function getContract(bytes32 key) external view returns (address);
    function isEcosystemContract(address a) external view returns (bool);
}

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

contract MIMHORegistry is IMIMHORegistry, IMIMHOProtocol, Ownable2Step {
    bytes32 public constant CONTRACT_TYPE = keccak256("MIMHO_REGISTRY");
    bytes32 public constant ACTION_TYPE   = keccak256("REGISTRY_ACTION");

    bytes32 private constant HUB_MODULE = keccak256("REGISTRY");

    bytes32 private constant ACT_SET_DAO         = keccak256("SET_DAO");
    bytes32 private constant ACT_ACTIVATE_DAO    = keccak256("ACTIVATE_DAO");
    bytes32 private constant ACT_PAUSE           = keccak256("PAUSE");
    bytes32 private constant ACT_UNPAUSE         = keccak256("UNPAUSE");
    bytes32 private constant ACT_SET_ADDRESS     = keccak256("SET_ADDRESS");
    bytes32 private constant ACT_PARTNER_SERVICE = keccak256("PARTNER_SERVICE_SET");

    // Core / modules
    bytes32 public constant KEY_MIMHO_TOKEN                 = keccak256("MIMHO_TOKEN");
    bytes32 public constant KEY_MIMHO_DAO                   = keccak256("MIMHO_DAO");
    bytes32 public constant KEY_MIMHO_EVENTS_HUB            = keccak256("MIMHO_EVENTS_HUB");

    bytes32 public constant KEY_MIMHO_SECURITY_WALLET       = keccak256("MIMHO_SECURITY_WALLET");
    bytes32 public constant KEY_MIMHO_VERITAS               = keccak256("MIMHO_VERITAS");
    bytes32 public constant KEY_MIMHO_AUDIT                 = keccak256("MIMHO_AUDIT");
    bytes32 public constant KEY_MIMHO_GAS_SAVER             = keccak256("MIMHO_GAS_SAVER");
    bytes32 public constant KEY_MIMHO_OBSERVER              = keccak256("MIMHO_OBSERVER");

    bytes32 public constant KEY_MIMHO_STAKING               = keccak256("MIMHO_STAKING");
    bytes32 public constant KEY_MIMHO_PRESALE               = keccak256("MIMHO_PRESALE");
    bytes32 public constant KEY_MIMHO_VESTING               = keccak256("MIMHO_VESTING");
    bytes32 public constant KEY_MIMHO_BURN                  = keccak256("MIMHO_BURN");
    bytes32 public constant KEY_MIMHO_LOCKER                = keccak256("MIMHO_LOCKER");
    bytes32 public constant KEY_MIMHO_AIRDROP               = keccak256("MIMHO_AIRDROP");
    bytes32 public constant KEY_MIMHO_INVOICE               = keccak256("MIMHO_INVOICE");
    bytes32 public constant KEY_MIMHO_INJECT_LIQUIDITY      = keccak256("MIMHO_INJECT_LIQUIDITY");
    bytes32 public constant KEY_MIMHO_TRADING_ACTIVITY      = keccak256("MIMHO_TRADING_ACTIVITY");

    bytes32 public constant KEY_MIMHO_LOANS                 = keccak256("MIMHO_LOANS");
    bytes32 public constant KEY_MIMHO_BET                   = keccak256("MIMHO_BET");
    bytes32 public constant KEY_MIMHO_LOTTERY               = keccak256("MIMHO_LOTTERY");
    bytes32 public constant KEY_MIMHO_RAFFLE                = keccak256("MIMHO_RAFFLE");
    bytes32 public constant KEY_MIMHO_AUCTIONER             = keccak256("MIMHO_AUCTIONER");
    bytes32 public constant KEY_MIMHO_PULSE                 = keccak256("MIMHO_PULSE");
    bytes32 public constant KEY_MIMHO_QUIZ                  = keccak256("MIMHO_QUIZ");

    bytes32 public constant KEY_MIMHO_MART                  = keccak256("MIMHO_MART");
    bytes32 public constant KEY_MIMHO_MARKETPLACE           = keccak256("MIMHO_MARKETPLACE");

    bytes32 public constant KEY_MIMHO_VOTING_CONTROLLER     = keccak256("MIMHO_VOTING_CONTROLLER");
    bytes32 public constant KEY_MIMHO_STRATEGY_HUB          = keccak256("MIMHO_STRATEGY_HUB");
    bytes32 public constant KEY_MIMHO_LIQUIDITY_BOOTSTRAPER = keccak256("MIMHO_LIQUIDITY_BOOTSTRAPER");
    bytes32 public constant KEY_MIMHO_HOLDER_DISTRIBUTION   = keccak256("MIMHO_HOLDER_DISTRIBUTION");

    bytes32 public constant KEY_MIMHO_GATEWAY               = keccak256("MIMHO_GATEWAY");
    bytes32 public constant KEY_MIMHO_DEX                   = keccak256("MIMHO_DEX");
    bytes32 public constant KEY_MIMHO_SCORE                 = keccak256("MIMHO_SCORE");
    bytes32 public constant KEY_MIMHO_PERSONA               = keccak256("MIMHO_PERSONA");
    bytes32 public constant KEY_MIMHO_BANK                  = keccak256("MIMHO_BANK");
    bytes32 public constant KEY_MIMHO_RECEIVE               = keccak256("MIMHO_RECEIVE");
    bytes32 public constant KEY_MIMHO_PIX                   = keccak256("MIMHO_PIX");
    bytes32 public constant KEY_MIMHO_CERTIFY               = keccak256("MIMHO_CERTIFY");

    // Wallet keys
    bytes32 public constant KEY_MIMHO_DAO_WALLET            = keccak256("MIMHO_DAO_WALLET");
    bytes32 public constant KEY_WALLET_MARKETING            = keccak256("WALLET_MARKETING");
    bytes32 public constant KEY_WALLET_TECHNICAL            = keccak256("WALLET_TECHNICAL");
    bytes32 public constant KEY_WALLET_DONATION             = keccak256("WALLET_DONATION");
    bytes32 public constant KEY_WALLET_BURN                 = keccak256("WALLET_BURN");
    bytes32 public constant KEY_WALLET_LP_RESERVE           = keccak256("WALLET_LP_RESERVE");
    bytes32 public constant KEY_WALLET_LIQUIDITY_RESERVE    = keccak256("WALLET_LIQUIDITY_RESERVE");
    bytes32 public constant KEY_WALLET_SECURITY_RESERVE     = keccak256("WALLET_SECURITY_RESERVE");
    bytes32 public constant KEY_WALLET_BANK                 = keccak256("WALLET_BANK");
    bytes32 public constant KEY_WALLET_LOCKER               = keccak256("WALLET_LOCKER");
    bytes32 public constant KEY_WALLET_LABS                 = keccak256("WALLET_LABS");
    bytes32 public constant KEY_WALLET_AIRDROPS             = keccak256("WALLET_AIRDROPS");
    bytes32 public constant KEY_WALLET_GAME                 = keccak256("WALLET_GAME");
    bytes32 public constant KEY_WALLET_MART                 = keccak256("WALLET_MART");

    // Legacy aliases
    bytes32 public constant KEY_LP_INJECTOR                 = keccak256("LP_INJECTOR");
    bytes32 public constant KEY_STAKING_CONTRACT            = keccak256("STAKING_CONTRACT");
    bytes32 public constant KEY_MARKETING_WALLET            = keccak256("MARKETING_WALLET");

    address public immutable ownersafe;
    address public dao;
    bool public daoActivated;
    bool public paused;

    IMIMHOEventsHub public eventsHub;

    struct PartnerService {
        bool allowed;
        uint64 validUntil;
    }

    mapping(bytes32 => address) private _addresses;
    mapping(address => uint256) private _ecosystemRefs;
    mapping(address => mapping(bytes32 => PartnerService)) private partnerServices;

    event OwnerSet(address indexed owner);
    event DAOSet(address indexed dao);
    event DAOActivated();
    event Paused();
    event Unpaused();
    event EventsHubSet(address indexed hub);
    event AddressSet(bytes32 indexed moduleId, address indexed addr);
    event PartnerServiceSet(address indexed partner, bytes32 indexed serviceId, uint64 validUntil, bool allowed);

    modifier onlyDAOorOwner() {
        if (daoActivated) {
            require(msg.sender == dao, "DAO");
        } else {
            require(msg.sender == ownersafe, "OWN");
        }
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "PAUSE");
        _;
    }

    constructor(address founderSafeOwner) {
        require(founderSafeOwner != address(0), "ZERO");
        ownersafe = founderSafeOwner;
        _transferOwnership(founderSafeOwner);
        emit OwnerSet(founderSafeOwner);
    }

    function _emitHubEvent(bytes32 action, uint256 value, bytes memory data) internal {
        address hub = address(eventsHub);
        if (hub == address(0)) return;
        try IMIMHOEventsHub(hub).emitEvent(HUB_MODULE, action, msg.sender, value, data) {
        } catch {
        }
    }

    function _isWalletKey(bytes32 key) internal pure returns (bool) {
        return (
            key == KEY_MIMHO_DAO_WALLET ||
            key == KEY_WALLET_MARKETING ||
            key == KEY_WALLET_TECHNICAL ||
            key == KEY_WALLET_DONATION ||
            key == KEY_WALLET_BURN ||
            key == KEY_WALLET_LP_RESERVE ||
            key == KEY_WALLET_LIQUIDITY_RESERVE ||
            key == KEY_WALLET_SECURITY_RESERVE ||
            key == KEY_WALLET_BANK ||
            key == KEY_WALLET_LOCKER ||
            key == KEY_WALLET_LABS ||
            key == KEY_WALLET_AIRDROPS ||
            key == KEY_WALLET_GAME ||
            key == KEY_WALLET_MART ||
            key == KEY_MARKETING_WALLET
        );
    }

    function _setAddressRaw(bytes32 key, address value, bool ecosystem) internal {
        require(value != address(0), "ZERO");

        address oldValue = _addresses[key];
        if (oldValue == value) return;

        if (ecosystem) {
            if (oldValue != address(0)) {
                unchecked {
                    _ecosystemRefs[oldValue] -= 1;
                }
            }
            _ecosystemRefs[value] += 1;
        }

        _addresses[key] = value;

        emit AddressSet(key, value);
        _emitHubEvent(ACT_SET_ADDRESS, 0, abi.encode(key, value));
    }

    function _setContractAddress(bytes32 key, address value) internal {
        require(!_isWalletKey(key), "WALLET_KEY");
        _setAddressRaw(key, value, true);
    }

    function _setWalletAddress(bytes32 key, address value) internal {
        require(_isWalletKey(key), "CONTRACT_KEY");
        _setAddressRaw(key, value, false);
    }

    // ---------------- Governance ----------------

    function setDAO(address _dao) external onlyOwner whenNotPaused {
        require(_dao != address(0), "ZERO");
        require(dao == address(0), "SET");
        dao = _dao;
        _setContractAddress(KEY_MIMHO_DAO, _dao);
        emit DAOSet(_dao);
        _emitHubEvent(ACT_SET_DAO, 0, abi.encode(_dao));
    }

    function activateDAO() external onlyOwner whenNotPaused {
        require(dao != address(0), "NO_DAO");
        require(!daoActivated, "ACTIVE");
        daoActivated = true;
        emit DAOActivated();
        _emitHubEvent(ACT_ACTIVATE_DAO, 0, abi.encode(dao));
    }

    function pauseEmergencial() external onlyDAOorOwner {
        require(!paused, "ALREADY");
        paused = true;
        emit Paused();
        _emitHubEvent(ACT_PAUSE, 0, "");
    }

    function unpause() external onlyDAOorOwner {
        require(paused, "NOT_PAUSED");
        paused = false;
        emit Unpaused();
        _emitHubEvent(ACT_UNPAUSE, 0, "");
    }

    // ---------------- Core config ----------------

    function setEventsHub(address hub) external onlyDAOorOwner whenNotPaused {
        require(hub != address(0), "ZERO");
        eventsHub = IMIMHOEventsHub(hub);
        emit EventsHubSet(hub);
        _setContractAddress(KEY_MIMHO_EVENTS_HUB, hub);
    }

    function setMIMHOToken(address a) external onlyDAOorOwner whenNotPaused {
        _setContractAddress(KEY_MIMHO_TOKEN, a);
    }

    // ---------------- Generic admin setters ----------------

    function setContract(bytes32 key, address value) external onlyDAOorOwner whenNotPaused {
        require(
            key != KEY_MIMHO_DAO &&
            key != KEY_MIMHO_EVENTS_HUB &&
            key != KEY_MIMHO_TOKEN,
            "USE_SPECIFIC"
        );
        _setContractAddress(key, value);
    }

    function setWallet(bytes32 key, address value) external onlyDAOorOwner whenNotPaused {
        _setWalletAddress(key, value);
    }

    // ---------------- Partner / Labs ----------------

    function setPartnerService(
        address partner,
        bytes32 serviceId,
        bool allowed,
        uint64 validUntil
    ) external onlyDAOorOwner whenNotPaused {
        require(partner != address(0), "ZERO");
        if (allowed) require(validUntil > uint64(block.timestamp), "EXP");

        partnerServices[partner][serviceId] = PartnerService({
            allowed: allowed,
            validUntil: allowed ? validUntil : 0
        });

        emit PartnerServiceSet(partner, serviceId, allowed ? validUntil : 0, allowed);
        _emitHubEvent(ACT_PARTNER_SERVICE, 0, abi.encode(partner, serviceId, allowed, validUntil));
    }

    function isPartnerAuthorized(address partner, bytes32 serviceId) external view returns (bool) {
        PartnerService memory p = partnerServices[partner][serviceId];
        return p.allowed && p.validUntil != 0 && block.timestamp <= p.validUntil;
    }

    function getPartnerService(address partner, bytes32 serviceId) external view returns (bool allowed, uint64 validUntil) {
        PartnerService memory p = partnerServices[partner][serviceId];
        return (p.allowed, p.validUntil);
    }

    // ---------------- Resolver ----------------

    function getContract(bytes32 key) external view returns (address) {
        if (key == KEY_LP_INJECTOR) return _addresses[KEY_MIMHO_INJECT_LIQUIDITY];
        if (key == KEY_STAKING_CONTRACT) return _addresses[KEY_MIMHO_STAKING];
        if (key == KEY_MARKETING_WALLET) return _addresses[KEY_WALLET_MARKETING];
        return _addresses[key];
    }

    function isEcosystemContract(address a) external view returns (bool) {
        return _ecosystemRefs[a] > 0;
    }

// ---------------- Compatibility getters ----------------

    function mimhoToken() external view returns (address) {
        return _addresses[KEY_MIMHO_TOKEN];
    }

    function mimhoStaking() external view returns (address) {
        return _addresses[KEY_MIMHO_STAKING];
    }

    function mimhoPresale() external view returns (address) {
        return _addresses[KEY_MIMHO_PRESALE];
    }

    function mimhoVesting() external view returns (address) {
        return _addresses[KEY_MIMHO_VESTING];
    }

    function mimhoBurn() external view returns (address) {
        return _addresses[KEY_MIMHO_BURN];
    }

    function mimhoLocker() external view returns (address) {
        return _addresses[KEY_MIMHO_LOCKER];
    }

    function mimhoAirdrop() external view returns (address) {
        return _addresses[KEY_MIMHO_AIRDROP];
    }

    function mimhoInjectLiquidity() external view returns (address) {
        return _addresses[KEY_MIMHO_INJECT_LIQUIDITY];
    }

    function mimhoTradingActivity() external view returns (address) {
        return _addresses[KEY_MIMHO_TRADING_ACTIVITY];
    }

    function mimhoMart() external view returns (address) {
        return _addresses[KEY_MIMHO_MART];
    }

    function mimhoMarketplace() external view returns (address) {
        return _addresses[KEY_MIMHO_MARKETPLACE];
    }

    function walletDAOTreasury() external view returns (address) {
        return _addresses[KEY_MIMHO_DAO_WALLET];
    }

    function walletMarketing() external view returns (address) {
        return _addresses[KEY_WALLET_MARKETING];
    }

    function walletDonation() external view returns (address) {
        return _addresses[KEY_WALLET_DONATION];
    }

    function walletBurn() external view returns (address) {
        return _addresses[KEY_WALLET_BURN];
    }

    // ---------------- Checks / wallet views ----------------

    function checkWalletsConfigured() external view returns (bool ok) {
        return (
            _addresses[KEY_MIMHO_DAO_WALLET] != address(0) &&
            _addresses[KEY_WALLET_MARKETING] != address(0) &&
            _addresses[KEY_WALLET_DONATION] != address(0) &&
            _addresses[KEY_WALLET_BURN] != address(0)
        );
    }

    function checkCoreConfigured() external view returns (bool ok) {
        return (
            _addresses[KEY_MIMHO_TOKEN] != address(0) &&
            _addresses[KEY_MIMHO_DAO] != address(0) &&
            _addresses[KEY_MIMHO_EVENTS_HUB] != address(0)
        );
    }

    function getWallets()
        external
        view
        returns (
            address daoTreasury,
            address marketing,
            address donation,
            address burn
        )
    {
        return (
            _addresses[KEY_MIMHO_DAO_WALLET],
            _addresses[KEY_WALLET_MARKETING],
            _addresses[KEY_WALLET_DONATION],
            _addresses[KEY_WALLET_BURN]
        );
    }

    // ---------------- IMIMHOProtocol ----------------

    function contractName() external pure override returns (string memory) {
        return "MIMHO Registry";
    }

    function contractType() external pure override returns (bytes32) {
        return CONTRACT_TYPE;
    }

    function version() external pure override returns (string memory) {
        return "2.0.0";
    }

    function isObservable() external pure override returns (bool) {
        return true;
    }

    function getActionType() external pure override returns (bytes32) {
        return ACTION_TYPE;
    }

    function getRiskLevel() external pure override returns (uint8) {
        return 0;
    }

    function isFinalized() external pure override returns (bool) {
        return false;
    }

    function getFinancialImpact(address) external pure override returns (uint256 volumeIn, uint256 volumeOut, uint256 lockedValue) {
        return (0, 0, 0);
    }

    function getBoostValue(address) external pure override returns (uint256) {
        return 0;
    }

    function onExternalAction(address, bytes32) external pure override {
    }
}
>>>>>>> fe7ced1 (Add official deployed MIMHO contracts with BscScan headers)
