<<<<<<< HEAD
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

abstract contract MIMHO Mart {
    string public constant version = "0.0.0-placeholder";
    function contractType() public pure virtual returns (bytes32) { return keccak256("MIMHO_MART"); }
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
abstract contract MIMHO Mart {
    /// @notice Human readable version for repository tracking (not on-chain guarantee).
    string public constant version = "0.0.0-placeholder";

    /// @notice Contract module type identifier (used by HUD/Events Hub in final builds).
    function contractType() public pure virtual returns (bytes32) {
        return CONTRACT_TYPE;
    }
}
=======
/// -----------------------------------------------------------------------
/// MIMHO MART
/// Official MIMHO Ecosystem Contract
///
/// Network: BNB Smart Chain
/// Contract Address:
/// 0xDF5aDe7E2018Fc103DCfe75Ca5d185F400C79ccb
///
/// BscScan:
/// https://bscscan.com/address/0xDF5aDe7E2018Fc103DCfe75Ca5d185F400C79ccb
/// -----------------------------------------------------------------------

// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/* ============================================================
   MIMHO MART — v1.0.1
   NFT Minter + Optional Secondary Market (Royalties Split)
   ============================================================

   DESIGN PHILOSOPHY (MIMHO ABSOLUTE STANDARD)

   - One Canonical NFT Hub:
     MIMHO Mart is the official NFT issuance point for the ecosystem.
     Contracts do not mint NFTs directly; they request minting here.

   - Radical Transparency:
     Every meaningful action emits standard events and also broadcasts
     to the MIMHO Events Hub (HUD loudspeaker) using best-effort try/catch.

   - Zero Hidden Privileges:
     Only DAO/Owner and Registry-whitelisted ecosystem contracts can mint,
     and each caller is restricted by "mint type" permissions.

   - Gas & Safety First:
     No unbounded global loops, no dynamic list traversal for user actions.
     Constant-time mappings, strict checks, and defensive patterns.

   - Royalties as Protocol Rule:
     Secondary sales (if using the built-in market) apply 5% royalties,
     split immutably: 20% Founder, 10% Staking, 70% DAO.
     Founder SAFE is hardcoded and immutable by rule.

   - Registry-Coupled, Upgrade-Safe:
     All dependencies are resolved via Registry KEY getters.
     No local keccak256 strings; no brittle hardcoding (except Founder SAFE).

   ============================================================ */

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IMIMHORegistry {
    function getContract(bytes32 key) external view returns (address);

    // Keys MUST be exposed by Registry getters (MIMHO absolute rule)
    // IMPORTANT: declared as VIEW (not pure) to match real Registry behavior.
    function KEY_MIMHO_EVENTS_HUB() external view returns (bytes32);
    function KEY_MIMHO_DAO() external view returns (bytes32);
    function KEY_MIMHO_TOKEN() external view returns (bytes32);
    function KEY_MIMHO_STAKING() external view returns (bytes32);

    // Optional (may not exist in older registries). We will probe via staticcall safely.
    function KEY_MIMHO_DAO_WALLET() external view returns (bytes32);

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

contract MIMHOMart is ERC721, ERC721Burnable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    /* =========================
       VERSION / IDENTIFIERS
       ========================= */

    string public constant VERSION = "1.0.1";

    function contractType() public pure returns (bytes32) {
        return bytes32("MIMHO_MART");
    }

    /* =========================
       IMMUTABLES / CONSTANTS
       ========================= */

    IMIMHORegistry public immutable registry;

    // Absolute MIMHO rule: Founder SAFE must be hardcoded in any contract that pays founder fees.
    address public constant FOUNDER_SAFE =
        0x3b50433D64193923199aAf209eE8222B9c728Fbd;

    // Royalties: 5% total on secondary sales (built-in market), split:
    // 20% Founder, 10% Staking, 70% DAO.
    uint256 public constant ROYALTY_BPS = 500; // 5.00%
    uint256 public constant BPS_DENOM = 10_000;

    uint256 public constant SPLIT_FOUNDER_BPS_OF_ROYALTY = 2000; // 20% of royalty
    uint256 public constant SPLIT_STAKING_BPS_OF_ROYALTY = 1000; // 10% of royalty
    uint256 public constant SPLIT_DAO_BPS_OF_ROYALTY = 7000;     // 70% of royalty

    /* =========================
       DAO / OWNER CONTROL
       ========================= */

    address public owner;
    address public daoContract;
    bool public daoActivated;

    modifier onlyOwner() {
        require(msg.sender == owner, "MART: not owner");
        _;
    }

    modifier onlyDAOorOwner() {
        if (msg.sender == owner) {
            _;
            return;
        }
        require(daoActivated && msg.sender == daoContract, "MART: not DAO/owner");
        _;
    }

    /* =========================
       EVENTS (PUBLIC)
       ========================= */

    event OwnerTransferred(address indexed  oldOwner, address indexed  newOwner);
    event DAOSet(address indexed  dao);
    event DAOActivated(address indexed  dao);

    // Minting
    event MintTypePermissionSet(address indexed  caller, uint256 bitmap);
    event Minted(
        bytes32 indexed mintRequestId,
        address indexed caller,
        address indexed to,
        uint256 tokenId,
        uint8 mintType,
        string tokenURI
    );
    event MintFailed(
        bytes32 indexed mintRequestId,
        address indexed caller,
        address indexed to,
        uint8 mintType,
        uint8 reasonCode
    );

    // Marketplace (optional built-in)
    event Listed(address indexed  seller, uint256 indexed tokenId, uint256 price);
    event ListingCanceled(address indexed  seller, uint256 indexed tokenId);
    event Sold(
        address indexed buyer,
        address indexed seller,
        uint256 indexed tokenId,
        uint256 price,
        uint256 royaltyTotal
    );
    event RoyaltySplit(
        uint256 indexed tokenId,
        uint256 price,
        uint256 royaltyTotal,
        uint256 founderAmount,
        uint256 stakingAmount,
        uint256 daoAmount
    );

    // Base URI
    event BaseURISet(string newBaseURI);

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
        // Best-effort: Hub failures must never break core logic
        IMIMHOEventsHub hub = _eventsHub();
        if (address(hub) == address(0)) return;
        try hub.emitEvent(contractType(), action, caller, value, data) {
            // ok
        } catch {
            // ignore
        }
    }

    /* =========================
       MINT TYPES (WHITELIST BY TYPE)
       ========================= */

    // Bitmap permissions: bit[mintType] = 1 means caller can mint that type.
    mapping(address => uint256) public mintTypeBitmapForCaller;

    function _hasMintTypePermission(address caller, uint8 mintType) internal view returns (bool) {
        uint256 mask = (uint256(1) << uint256(mintType));
        return (mintTypeBitmapForCaller[caller] & mask) != 0;
    }

    function setMintTypePermissions(address caller, uint256 bitmap) external onlyDAOorOwner {
        mintTypeBitmapForCaller[caller] = bitmap;
        emit MintTypePermissionSet(caller, bitmap);
        _emitHubEvent(bytes32("MINT_PERMS_SET"), msg.sender, bitmap, abi.encode(caller, bitmap));
    }

    /* =========================
       TOKEN URI MANAGEMENT
       ========================= */

    string private _baseTokenURI;
    mapping(uint256 => string) private _tokenURIOverride;

    function setBaseURI(string calldata newBaseURI) external onlyDAOorOwner {
        _baseTokenURI = newBaseURI;
        emit BaseURISet(newBaseURI);
        _emitHubEvent(bytes32("BASE_URI_SET"), msg.sender, 0, abi.encode(newBaseURI));
    }

    function setTokenURI(uint256 tokenId, string calldata newTokenURI) external onlyDAOorOwner {
        require(_exists(tokenId), "MART: token !exists");
        _tokenURIOverride[tokenId] = newTokenURI;
        _emitHubEvent(bytes32("TOKEN_URI_SET"), msg.sender, tokenId, abi.encode(tokenId, newTokenURI));
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "MART: token !exists");
        string memory o = _tokenURIOverride[tokenId];
        if (bytes(o).length != 0) return o;
        string memory b = _baseTokenURI;
        if (bytes(b).length == 0) return "";
        return string.concat(b, Strings.toString(tokenId));
    }

    /* =========================
       MINTING CORE
       ========================= */

    uint256 public nextTokenId = 1;

    modifier onlyEcosystemOrDAOorOwner() {
        if (msg.sender == owner) {
            _;
            return;
        }
        if (daoActivated && msg.sender == daoContract) {
            _;
            return;
        }
        require(registry.isEcosystemContract(msg.sender), "MART: caller not ecosystem");
        _;
    }

    /// @dev internal mint logic to allow wrappers without triggering ReentrancyGuard twice.
    function _mintInternal(
        address to,
        uint8 mintType,
        string memory uriOrEmpty,
        address logicalCaller
    ) internal returns (uint256 tokenId, bytes32 mintRequestId) {
        mintRequestId = keccak256(
            abi.encodePacked(address(this), logicalCaller, to, mintType, nextTokenId, block.chainid)
        );

        // Permission by type (DAO/Owner can always mint any type; ecosystem must be allowed)
        if (logicalCaller != owner && !(daoActivated && logicalCaller == daoContract)) {
            if (!_hasMintTypePermission(logicalCaller, mintType)) {
                emit MintFailed(mintRequestId, logicalCaller, to, mintType, 1);
                _emitHubEvent(
                    bytes32("MINT_FAIL"),
                    logicalCaller,
                    1,
                    abi.encode(mintRequestId, to, mintType, uint8(1))
                );
                revert("MART: mintType not allowed");
            }
        }

        tokenId = nextTokenId++;
        _safeMint(to, tokenId);

        if (bytes(uriOrEmpty).length != 0) {
            _tokenURIOverride[tokenId] = uriOrEmpty;
        }

        emit Minted(mintRequestId, logicalCaller, to, tokenId, mintType, tokenURI(tokenId));
        _emitHubEvent(
            bytes32("MINT"),
            logicalCaller,
            tokenId,
            abi.encode(mintRequestId, to, tokenId, mintType, uriOrEmpty)
        );
    }

    /// @notice Mint an NFT to `to` with `mintType`. Only ecosystem/DAO/owner.
    function mint(
        address to,
        uint8 mintType,
        string calldata uriOrEmpty
    ) external whenNotPaused nonReentrant onlyEcosystemOrDAOorOwner returns (uint256 tokenId) {
        (tokenId, ) = _mintInternal(to, mintType, uriOrEmpty, msg.sender);
    }

    /// @notice Shortcut mint expected by Burn Vault.
    /// @dev mintType is forced to 0 (Badges). Parameters are included for compatibility & audit context.
    function mintBurnBadge(
        address to,
        uint256 /*amount*/,
        uint256 /*timestamp*/,
        bytes32 /*contextHash*/,
        string calldata reason
    )
        external
        whenNotPaused
        nonReentrant
        onlyEcosystemOrDAOorOwner
        returns (uint256)
    {
        // mintType = 0 (Badges)
        string memory metadata = string.concat("Burn Badge: ", reason);

        (uint256 tokenId, ) = _mintInternal(to, 0, metadata, msg.sender);
        return tokenId;
    }

    /* =========================
       OPTIONAL BUILT-IN MARKETPLACE (MIMHO TOKEN PAYMENTS)
       ========================= */

    struct Listing {
        address seller;
        uint256 price; // in MIMHO token (or any ERC20 set in Registry key)
    }

    mapping(uint256 => Listing) public listings;

    function paymentToken() public view returns (IERC20) {
        address tokenAddr = registry.getContract(registry.KEY_MIMHO_TOKEN());
        return IERC20(tokenAddr);
    }

    /// @dev Compatibility:
    /// - Prefer DAO_WALLET key if Registry supports it.
    /// - Always fallback to DAO (KEY_MIMHO_DAO) if wallet key doesn't exist or returns 0.
    function daoWallet() public view returns (address) {
        // Attempt to read KEY_MIMHO_DAO_WALLET() via staticcall (may not exist in older registries)
        (bool ok, bytes memory ret) =
            address(registry).staticcall(abi.encodeWithSelector(IMIMHORegistry.KEY_MIMHO_DAO_WALLET.selector));

        if (ok && ret.length >= 32) {
            bytes32 key = abi.decode(ret, (bytes32));
            if (key != bytes32(0)) {
                address w = registry.getContract(key);
                if (w != address(0)) return w;
            }
        }

        // Fallback: DAO contract (canonical key)
        return registry.getContract(registry.KEY_MIMHO_DAO());
    }

    function stakingReceiver() public view returns (address) {
        // You can point this key to a staking contract or a dedicated staking-fee wallet.
        return registry.getContract(registry.KEY_MIMHO_STAKING());
    }

    function list(uint256 tokenId, uint256 price) external whenNotPaused nonReentrant {
        require(ownerOf(tokenId) == msg.sender, "MART: not owner of NFT");
        require(price > 0, "MART: price=0");
        require(
            getApproved(tokenId) == address(this) || isApprovedForAll(msg.sender, address(this)),
            "MART: not approved"
        );

        listings[tokenId] = Listing({seller: msg.sender, price: price});
        emit Listed(msg.sender, tokenId, price);
        _emitHubEvent(bytes32("LIST"), msg.sender, price, abi.encode(tokenId, price));
    }

    function cancelListing(uint256 tokenId) external nonReentrant {
        Listing memory l = listings[tokenId];
        require(l.seller == msg.sender, "MART: not seller");
        delete listings[tokenId];
        emit ListingCanceled(msg.sender, tokenId);
        _emitHubEvent(bytes32("CANCEL_LIST"), msg.sender, tokenId, abi.encode(tokenId));
    }

    function buy(uint256 tokenId) external whenNotPaused nonReentrant {
        // 1. CHECKS (Validações)
        Listing memory l = listings[tokenId];
        require(l.price > 0, "MART: not listed");
        require(l.seller != address(0), "MART: invalid seller");
        require(l.seller != msg.sender, "MART: self buy");
        require(ownerOf(tokenId) == l.seller, "MART: seller not owner");

        IERC20 pay = paymentToken();
        uint256 price = l.price;

        // 2. EFFECTS (Mudança de Estado - O Slither quer isso aqui em cima!)
        // Deletamos o anúncio ANTES de qualquer transferência para evitar reentrada.
        delete listings[tokenId];

        // --- CORREÇÃO ITEM 9: Multiplicar antes de dividir para precisão total ---
        uint256 royaltyTotal = (price * ROYALTY_BPS) / BPS_DENOM;

        // Calculamos as partes usando o preço total como base para evitar perda de precisão
        uint256 founderAmt = (price * ROYALTY_BPS * SPLIT_FOUNDER_BPS_OF_ROYALTY) / (BPS_DENOM * BPS_DENOM);
        uint256 stakingAmt = (price * ROYALTY_BPS * SPLIT_STAKING_BPS_OF_ROYALTY) / (BPS_DENOM * BPS_DENOM);

        uint256 daoAmt = royaltyTotal - founderAmt - stakingAmt;
        uint256 sellerAmt = price - royaltyTotal;

        // 4. INTERACTIONS (Movimentação de valores e tokens)
        
        // Primeiro puxamos o pagamento do comprador
        pay.safeTransferFrom(msg.sender, address(this), price);

        // Distribuição das Royalties
        if (founderAmt != 0) pay.safeTransfer(FOUNDER_SAFE, founderAmt);

        address stakingAddr = stakingReceiver();
        if (stakingAmt != 0) {
            if (stakingAddr == address(0)) {
                pay.safeTransfer(daoWallet(), stakingAmt);
            } else {
                pay.safeTransfer(stakingAddr, stakingAmt);
            }
        }

        address daoAddr = daoWallet();
        if (daoAmt != 0) pay.safeTransfer(daoAddr, daoAmt);

        // Pagamento do Vendedor
        pay.safeTransfer(l.seller, sellerAmt);

        // Transferência do NFT (Sempre por último, pois pode disparar gatilhos externos)
        _safeTransfer(l.seller, msg.sender, tokenId, "");

        // 5. EVENTS & HUB
        emit RoyaltySplit(tokenId, price, royaltyTotal, founderAmt, stakingAmt, daoAmt);
        emit Sold(msg.sender, l.seller, tokenId, price, royaltyTotal);

        _emitHubEvent(bytes32("SOLD"), msg.sender, price, abi.encode(tokenId, l.seller, price, royaltyTotal));
        _emitHubEvent(bytes32("ROYALTY_SPLIT"), msg.sender, royaltyTotal, abi.encode(tokenId, founderAmt, stakingAmt, daoAmt));
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
        require(dao != address(0), "MART: dao=0");
        daoContract = dao;
        emit DAOSet(dao);
        _emitHubEvent(bytes32("DAO_SET"), msg.sender, uint256(uint160(dao)), abi.encode(dao));
    }

    function activateDAO() external onlyOwner {
        require(daoContract != address(0), "MART: dao not set");
        daoActivated = true;
        emit DAOActivated(daoContract);
        _emitHubEvent(bytes32("DAO_ACTIVATED"), msg.sender, 1, abi.encode(daoContract));
    }

    function syncDAOFromRegistry() external onlyDAOorOwner {
        address dao = registry.getContract(registry.KEY_MIMHO_DAO());
        require(dao != address(0), "MART: registry dao=0");
        daoContract = dao;
        _emitHubEvent(bytes32("DAO_SYNC"), msg.sender, uint256(uint160(dao)), abi.encode(dao));
    }

    /* =========================
       OWNER MGMT (NO renounceOwnership)
       ========================= */

    function transferOwner(address newOwner) external onlyOwner {
        require(newOwner != address(0), "MART: owner=0");
        address old = owner;
        owner = newOwner;
        emit OwnerTransferred(old, newOwner);
        _emitHubEvent(bytes32("OWNER_TRANSFER"), msg.sender, uint256(uint160(newOwner)), abi.encode(old, newOwner));
    }

    /* =========================
       READ-ONLY (HUD BUTTONS)
       ========================= */

    function isListed(uint256 tokenId) external view returns (bool) {
        return listings[tokenId].price > 0;
    }

    function getListing(uint256 tokenId) external view returns (address seller, uint256 price) {
        Listing memory l = listings[tokenId];
        return (l.seller, l.price);
    }

    function royaltyPreview(uint256 price)
        external
        pure
        returns (uint256 royaltyTotal, uint256 founderAmt, uint256 stakingAmt, uint256 daoAmt, uint256 sellerAmt)
    {
        royaltyTotal = (price * ROYALTY_BPS) / BPS_DENOM;
        founderAmt = (royaltyTotal * SPLIT_FOUNDER_BPS_OF_ROYALTY) / BPS_DENOM;
        stakingAmt = (royaltyTotal * SPLIT_STAKING_BPS_OF_ROYALTY) / BPS_DENOM;
        daoAmt = royaltyTotal - founderAmt - stakingAmt;
        sellerAmt = price - royaltyTotal;
    }

    /* =========================
       CONSTRUCTOR
       ========================= */

    constructor(address registryAddr, string memory name_, string memory symbol_) ERC721(name_, symbol_) {
        require(registryAddr != address(0), "MART: registry=0");
        registry = IMIMHORegistry(registryAddr);
        owner = msg.sender;

        _emitHubEvent(bytes32("DEPLOY"), msg.sender, 0, abi.encode(VERSION, name_, symbol_));
    }
}
>>>>>>> fe7ced1 (Add official deployed MIMHO contracts with BscScan headers)
