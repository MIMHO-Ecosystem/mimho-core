/// -----------------------------------------------------------------------
/// MIMHO MARKETPLACE
/// Official MIMHO Ecosystem Contract
///
/// Network: BNB Smart Chain
/// Contract Address:
/// 0x46da5bdc8d69e64D7167C0AD10209ddb202E9458
///
/// BscScan:
/// https://bscscan.com/address/0x46da5bdc8d69e64D7167C0AD10209ddb202E9458
/// -----------------------------------------------------------------------

// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/* ============================================================
   MIMHO MARKETPLACE — v1.0.2 (MIMHO ABSOLUTE PROTOCOL)
   ============================================================

   SLITHER / REENTRANCY HARDENING (YOUR RULE)
   - In buy/claim/list/cancel: ALL state changes happen immediately after require checks.
   - External interactions are pushed to the end of the function.
   - In buyNFT: the payout routine (_payoutOrPend) is executed only after:
       (1) listing is deactivated,
       (2) all accounting is done,
       (3) the NFT is delivered.
   - Hub events are emitted only at the very end of relevant flows (best-effort).

   DESIGN PHILOSOPHY (EN)
   - Trustless NFT settlement with escrow.
   - Minimal & neutral: NO staking/strategy/bonuses.
   - Immutable economics: fee rates & splits are hardcoded.
   - MIMHO NFT identity: nft == MIMHO Mart (resolved from Registry).
   - Royalties: respects ERC-2981 if supported.
   - Founder SAFE is hardcoded & immutable (MIMHO rule).

   ============================================================ */

import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";

/* =========================
   Minimal ERC-2981 interface
   ========================= */
interface IERC2981 {
    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        external
        view
        returns (address receiver, uint256 royaltyAmount);
}

/* =========================
   MIMHO Registry (minimal)
   - MIMHO Absolute Protocol: always pull KEYS from Registry getters.
   ========================= */
interface IMIMHORegistry {
    function getContract(bytes32 key) external view returns (address);
    function isEcosystemContract(address a) external view returns (bool);

    function KEY_MIMHO_EVENTS_HUB() external view returns (bytes32);
    function KEY_MIMHO_MART() external view returns (bytes32);

    function KEY_MIMHO_DAO() external view returns (bytes32);

    function KEY_MARKETING_WALLET() external view returns (bytes32);

    function KEY_MIMHO_INJECT_LIQUIDITY() external view returns (bytes32);
    function KEY_MIMHO_STAKING() external view returns (bytes32);
}

/* =========================
   MIMHO Events Hub (minimal)
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

contract MIMHOMarketplace is
    Ownable2Step,
    ReentrancyGuard,
    Pausable,
    IERC721Receiver,
    IERC1155Receiver
{
    /* ============================================================
                                CONSTANTS
       ============================================================ */

    string public constant name = "MIMHO Marketplace";
    string public constant version = "1.0.2";

    // ✅ Founder SAFE hardcoded & immutable-by-code (MIMHO rule)
    address public constant FOUNDER_SAFE = 0x3b50433D64193923199aAf209eE8222B9c728Fbd;

    // Fee rates are immutable (BPS: 10_000 = 100%)
    uint16 public constant FEE_BPS_EXTERNAL = 100; // 1.00%
    uint16 public constant FEE_BPS_MIMHO = 50;     // 0.50%

    // External NFT fee split (of fee amount)
    // 10% Founder, 10% Marketing, 10% Liquidity(or Staking), 70% DAO
    uint16 public constant EXT_SPLIT_FOUNDER_BPS = 1000;
    uint16 public constant EXT_SPLIT_MARKETING_BPS = 1000;
    uint16 public constant EXT_SPLIT_LIQ_OR_STK_BPS = 1000;
    uint16 public constant EXT_SPLIT_DAO_BPS = 7000;

    // MIMHO NFT fee split (of fee amount)
    // 20% Founder, 10% Liquidity(or Staking), 70% DAO
    uint16 public constant MIMHO_SPLIT_FOUNDER_BPS = 2000;
    uint16 public constant MIMHO_SPLIT_LIQ_OR_STK_BPS = 1000;
    uint16 public constant MIMHO_SPLIT_DAO_BPS = 7000;

    // Ecosystem-sale split (of net sale amount after royalties)
    // 20% Founder, 10% Liquidity(or Staking), 70% DAO
    uint16 public constant ECO_SPLIT_FOUNDER_BPS = 2000;
    uint16 public constant ECO_SPLIT_LIQ_OR_STK_BPS = 1000;
    uint16 public constant ECO_SPLIT_DAO_BPS = 7000;

    // Events Hub identifiers (module/action)
    bytes32 public constant MODULE = keccak256("MIMHO_MARKETPLACE");
    bytes32 public constant ACT_LISTED = bytes32("NFT_LISTED");
    bytes32 public constant ACT_SOLD = bytes32("NFT_SOLD");
    bytes32 public constant ACT_CANCELED = bytes32("LISTING_CANCELED");
    bytes32 public constant ACT_FEES = bytes32("FEES_DISTRIBUTED");
    bytes32 public constant ACT_PENDING = bytes32("PAYOUT_PENDING");
    bytes32 public constant ACT_ECO_SPLIT = bytes32("ECOSYSTEM_SPLIT");

    event DAOSet(address indexed dao);

    /* ============================================================
                                REGISTRY / DAO
       ============================================================ */

    IMIMHORegistry public immutable registry;

    address public DAO_CONTRACT;
    bool public daoActivated;

    modifier onlyDAOorOwner() {
        if (daoActivated) {
            require(msg.sender == DAO_CONTRACT, "MIMHO: only DAO");
        } else {
            require(msg.sender == owner(), "MIMHO: only owner (pre-DAO)");
        }
        _;
    }

    function setDAO(address dao) external onlyOwner {
        require(!daoActivated, "MIMHO: DAO active");
        require(dao != address(0), "MIMHO: dao=0");

        // Efeito
        DAO_CONTRACT = dao;

        // ✅ CORREÇÃO SLITHER: Emissão do evento padrão
        emit DAOSet(dao);

        // Registro no Hub
        _emitHubEvent(bytes32("DAO_SET"), msg.sender, 0, abi.encode(dao));
    }

    function activateDAO() external onlyOwner {
        require(!daoActivated, "MIMHO: already active");
        require(DAO_CONTRACT != address(0), "MIMHO: DAO not set");
        daoActivated = true;
        _emitHubEvent(bytes32("DAO_ACTIVATED"), msg.sender, 0, abi.encode(DAO_CONTRACT));
    }

    /* ============================================================
                                LISTINGS
       ============================================================ */

    enum TokenStandard {
        ERC721,
        ERC1155
    }

    struct Listing {
        address nft;
        uint256 tokenId;
        uint256 amount;      // for ERC1155 (must be 1 in v1)
        address seller;
        uint256 price;       // native coin (BNB)
        TokenStandard std;
        bool isMIMHONFT;
        bool ecosystemSale;  // ecosystem-only listing mode
        bool active;
        uint64 listedAt;
    }

    uint256 public nextListingId = 1;
    mapping(uint256 => Listing) public listings;

    // Duplicate listing guard
    mapping(address => mapping(uint256 => bool)) public isTokenListed;

    /* ============================================================
                           FAIL-SAFE PAYOUTS (PENDING)
       ============================================================ */

    mapping(address => uint256) public pendingNative;

    /* ============================================================
                               METRICS (TRANSPARENCY)
       ============================================================ */

    uint256 public totalVolumeMIMHO;
    uint256 public totalVolumeExternal;
    uint256 public totalFeesDistributed;
    uint256 public totalRoyaltiesPaid;

    /* ============================================================
                               CONSTRUCTOR
       ============================================================ */

    constructor(address registryAddress) {
        require(registryAddress != address(0), "MIMHO: registry=0");
        require(FOUNDER_SAFE != address(0), "MIMHO: founder=0");
        registry = IMIMHORegistry(registryAddress);
    }

    /* ============================================================
                              CORE FUNCTIONS
       ============================================================ */

    /**
     * @notice List an NFT for sale (escrowed).
     * @dev SLITHER RULE: state changes occur immediately after requires.
     */
    function listNFT(
        address nft,
        uint256 tokenId,
        uint256 amount,
        uint256 price,
        TokenStandard std
    ) external whenNotPaused nonReentrant returns (uint256 listingId) {
        require(nft != address(0), "MIMHO: nft=0");
        require(price > 0, "MIMHO: price=0");
        require(!isTokenListed[nft][tokenId], "MIMHO: already listed");
        require(amount == 1, "MIMHO: amount=1");

        bool isMIMHO = _isMIMHONFT(nft);

        // --------- EFFECTS (immediately after require) ----------
        listingId = nextListingId++;
        listings[listingId] = Listing({
            nft: nft,
            tokenId: tokenId,
            amount: amount,
            seller: msg.sender,
            price: price,
            std: std,
            isMIMHONFT: isMIMHO,
            ecosystemSale: false,
            active: true,
            listedAt: uint64(block.timestamp)
        });
        isTokenListed[nft][tokenId] = true;

        // --------- INTERACTIONS (end) ----------
        if (std == TokenStandard.ERC721) {
            IERC721(nft).safeTransferFrom(msg.sender, address(this), tokenId);
        } else {
            IERC1155(nft).safeTransferFrom(msg.sender, address(this), tokenId, amount, "");
        }

        // --------- HUB (last line) ----------
        _emitHubEvent(
            ACT_LISTED,
            msg.sender,
            price,
            abi.encode(listingId, nft, tokenId, amount, uint8(std), isMIMHO, false)
        );
    }

    /**
     * @notice Ecosystem-only primary-sale mode.
     */
    function listEcosystemSale(
        address nft,
        uint256 tokenId,
        uint256 amount,
        uint256 price,
        TokenStandard std
    ) external whenNotPaused nonReentrant returns (uint256 listingId) {
        require(registry.isEcosystemContract(msg.sender), "MIMHO: ecosystem only");
        require(_isMIMHONFT(nft), "MIMHO: only MIMHO NFT");
        require(nft != address(0), "MIMHO: nft=0");
        require(price > 0, "MIMHO: price=0");
        require(!isTokenListed[nft][tokenId], "MIMHO: already listed");
        require(amount == 1, "MIMHO: amount=1");

        // --------- EFFECTS (immediately after require) ----------
        listingId = nextListingId++;
        listings[listingId] = Listing({
            nft: nft,
            tokenId: tokenId,
            amount: amount,
            seller: msg.sender,
            price: price,
            std: std,
            isMIMHONFT: true,
            ecosystemSale: true,
            active: true,
            listedAt: uint64(block.timestamp)
        });
        isTokenListed[nft][tokenId] = true;

        // --------- INTERACTIONS (end) ----------
        if (std == TokenStandard.ERC721) {
            IERC721(nft).safeTransferFrom(msg.sender, address(this), tokenId);
        } else {
            IERC1155(nft).safeTransferFrom(msg.sender, address(this), tokenId, amount, "");
        }

        // --------- HUB (last line) ----------
        _emitHubEvent(
            ACT_LISTED,
            msg.sender,
            price,
            abi.encode(listingId, nft, tokenId, amount, uint8(std), true, true)
        );
    }

    /**
 * @notice Buy a listed NFT with native coin (BNB).
 *
 * ✅ FINAL MIMHO PATCH (Slither reentrancy-eth killer):
 * - buyNFT NEVER sends BNB.
 * - buyNFT ONLY credits pendingNative[...] (pull payments).
 * - NFT delivery stays here.
 * - claimPending is the ONLY place that does call{value:}.
 * - Hub event is the last line.
 */
function buyNFT(uint256 listingId) external payable whenNotPaused nonReentrant {
    Listing storage L = listings[listingId];
    require(L.active, "MIMHO: inactive");
    require(msg.value == L.price, "MIMHO: bad payment");

    // --------- EFFECTS (state first) ----------
    L.active = false;
    delete isTokenListed[L.nft][L.tokenId];

    if (L.isMIMHONFT) {
        totalVolumeMIMHO += L.price;
    } else {
        totalVolumeExternal += L.price;
    }

    uint256 royaltyAmount = 0;
    address royaltyReceiver = address(0);
    if (_supportsERC2981(L.nft)) {
        (royaltyReceiver, royaltyAmount) = IERC2981(L.nft).royaltyInfo(L.tokenId, L.price);
        if (royaltyReceiver != address(0) && royaltyAmount > 0) {
            require(royaltyAmount <= L.price, "MIMHO: royalty > price");
            totalRoyaltiesPaid += royaltyAmount;
        } else {
            royaltyReceiver = address(0);
            royaltyAmount = 0;
        }
    }

    uint256 remaining = L.price - royaltyAmount;

    uint256 toSeller = 0;

    uint256 feeAmount = 0;
    uint256 feeToFounder = 0;
    uint256 feeToMarketing = 0;
    uint256 feeToLiqOrStk = 0;
    uint256 feeToDao = 0;

    uint256 ecoToFounder = 0;
    uint256 ecoToLiqOrStk = 0;
    uint256 ecoToDao = 0;

    if (L.ecosystemSale) {
        ecoToFounder = (remaining * ECO_SPLIT_FOUNDER_BPS) / 10_000;
        ecoToLiqOrStk = (remaining * ECO_SPLIT_LIQ_OR_STK_BPS) / 10_000;
        ecoToDao = remaining - ecoToFounder - ecoToLiqOrStk;
    } else {
        uint16 currentFeeBps = L.isMIMHONFT ? FEE_BPS_MIMHO : FEE_BPS_EXTERNAL;
        feeAmount = (remaining * currentFeeBps) / 10_000;

        if (feeAmount > 0) {
            if (L.isMIMHONFT) {
                feeToFounder = (remaining * currentFeeBps * MIMHO_SPLIT_FOUNDER_BPS) / 100_000_000;
                feeToLiqOrStk = (remaining * currentFeeBps * MIMHO_SPLIT_LIQ_OR_STK_BPS) / 100_000_000;
                feeToDao = feeAmount - feeToFounder - feeToLiqOrStk;
            } else {
                feeToFounder = (remaining * currentFeeBps * EXT_SPLIT_FOUNDER_BPS) / 100_000_000;
                feeToMarketing = (remaining * currentFeeBps * EXT_SPLIT_MARKETING_BPS) / 100_000_000;
                feeToLiqOrStk = (remaining * currentFeeBps * EXT_SPLIT_LIQ_OR_STK_BPS) / 100_000_000;
                feeToDao = feeAmount - feeToFounder - feeToMarketing - feeToLiqOrStk;
            }
            totalFeesDistributed += feeAmount;
        }
        toSeller = remaining - feeAmount;
    }

    // --------- CACHE ADDRESSES (avoid external reads later) ----------
    address daoWallet_ = _daoWallet();
    address marketing_ = _marketing();
    address liqOrStk_ = _liquidityOrStaking();

    // --------- EFFECTS: credit pending (NO BNB SEND HERE) ----------
    if (royaltyAmount > 0 && royaltyReceiver != address(0)) {
        pendingNative[royaltyReceiver] += royaltyAmount;
    }

    if (L.ecosystemSale) {
        if (ecoToFounder > 0) pendingNative[FOUNDER_SAFE] += ecoToFounder;
        if (ecoToLiqOrStk > 0) pendingNative[liqOrStk_] += ecoToLiqOrStk;
        if (ecoToDao > 0) pendingNative[daoWallet_] += ecoToDao;
    } else {
        if (feeToFounder > 0) pendingNative[FOUNDER_SAFE] += feeToFounder;
        if (feeToMarketing > 0) pendingNative[marketing_] += feeToMarketing;
        if (feeToLiqOrStk > 0) pendingNative[liqOrStk_] += feeToLiqOrStk;
        if (feeToDao > 0) pendingNative[daoWallet_] += feeToDao;
        if (toSeller > 0) pendingNative[L.seller] += toSeller;
    }

    // --------- INTERACTIONS: deliver NFT (external call) ----------
    if (L.std == TokenStandard.ERC721) {
        IERC721(L.nft).safeTransferFrom(address(this), msg.sender, L.tokenId);
    } else {
        IERC1155(L.nft).safeTransferFrom(address(this), msg.sender, L.tokenId, L.amount, "");
    }

    // --------- HUB (last line) ----------
    _emitHubEvent(
        ACT_SOLD,
        msg.sender,
        L.price,
        abi.encode(
            listingId,
            L.nft,
            L.tokenId,
            L.amount,
            uint8(L.std),
            L.isMIMHONFT,
            L.ecosystemSale,
            L.seller,
            msg.sender,
            royaltyReceiver,
            royaltyAmount,
            L.isMIMHONFT,
            feeAmount,
            feeToFounder,
            feeToMarketing,
            feeToLiqOrStk,
            feeToDao,
            ecoToFounder,
            ecoToLiqOrStk,
            ecoToDao
        )
    );
}
    /**
     * @notice Cancel an active listing and retrieve the NFT.
     * @dev State changes after require; external calls at end; hub last line.
     */
    function cancelListing(uint256 listingId) external nonReentrant {
        Listing storage L = listings[listingId];
        require(L.active, "MIMHO: inactive");
        require(L.seller == msg.sender, "MIMHO: not seller");

        // --------- EFFECTS ----------
        L.active = false;
        isTokenListed[L.nft][L.tokenId] = false;

        // --------- INTERACTIONS ----------
        if (L.std == TokenStandard.ERC721) {
            IERC721(L.nft).safeTransferFrom(address(this), msg.sender, L.tokenId);
        } else {
            IERC1155(L.nft).safeTransferFrom(address(this), msg.sender, L.tokenId, L.amount, "");
        }

        // --------- HUB (last line) ----------
        _emitHubEvent(
            ACT_CANCELED,
            msg.sender,
            0,
            abi.encode(listingId, L.nft, L.tokenId, L.amount, uint8(L.std), L.isMIMHONFT, L.ecosystemSale)
        );
    }

    /* ============================================================
                            PENDING CLAIM / PAYOUT
       ============================================================ */

    function claimPending() external nonReentrant {
    uint256 amt = pendingNative[msg.sender];
    require(amt > 0, "MIMHO: nothing pending");

    // --------- EFFECTS ----------
    pendingNative[msg.sender] = 0;

    // --------- INTERACTIONS (last interaction) ----------
    (bool ok, ) = payable(msg.sender).call{value: amt}("");
    require(ok, "MIMHO: claim failed");

    // --------- HUB (last line) ----------
    _emitHubEvent(keccak256("CLAIM_PENDING"), msg.sender, amt, "");
}

    /* ============================================================
                             PAUSE / UNPAUSE
       ============================================================ */

    function pauseEmergencial() external onlyDAOorOwner {
        _pause();
        _emitHubEvent(bytes32("PAUSED"), msg.sender, 0, "");
    }

    function unpause() external onlyDAOorOwner {
        _unpause();
        _emitHubEvent(bytes32("UNPAUSED"), msg.sender, 0, "");
    }

    /* ============================================================
                         REGISTRY RESOLUTION HELPERS
       ============================================================ */

    function _eventsHubAddr() internal view returns (address) {
        return registry.getContract(registry.KEY_MIMHO_EVENTS_HUB());
    }

    function _mimhoMart() internal view returns (address) {
        return registry.getContract(registry.KEY_MIMHO_MART());
    }

    function _daoWallet() internal view returns (address) {
        address dao = registry.getContract(registry.KEY_MIMHO_DAO());
        if (dao == address(0) && DAO_CONTRACT != address(0)) return DAO_CONTRACT;
        return dao;
    }

    function _marketing() internal view returns (address) {
        return registry.getContract(registry.KEY_MARKETING_WALLET());
    }

    function _injectLiquidity() internal view returns (address) {
        return registry.getContract(registry.KEY_MIMHO_INJECT_LIQUIDITY());
    }

    function _staking() internal view returns (address) {
        return registry.getContract(registry.KEY_MIMHO_STAKING());
    }

    function _liquidityOrStaking() internal view returns (address) {
        address inj = _injectLiquidity();
        if (inj != address(0)) {
            (bool ok, bytes memory ret) = inj.staticcall(abi.encodeWithSignature("paused()"));
            if (ok && ret.length >= 32) {
                bool p = abi.decode(ret, (bool));
                if (p) return _staking();
            }
            return inj;
        }
        return _staking();
    }

    function _isMIMHONFT(address nft) internal view returns (bool) {
        return nft != address(0) && nft == _mimhoMart();
    }

    function _supportsERC2981(address nft) internal view returns (bool) {
        (bool ok, bytes memory data) =
            nft.staticcall(abi.encodeWithSelector(IERC165.supportsInterface.selector, 0x2a55205a));
        return ok && data.length >= 32 && abi.decode(data, (bool));
    }

    /* ============================================================
                           EVENTS HUB (BEST-EFFORT)
       ============================================================ */

    function _emitHubEvent(bytes32 action, address caller, uint256 value, bytes memory data) internal {
        address hubAddr = _eventsHubAddr();
        if (hubAddr == address(0)) return;

        try IMIMHOEventsHub(hubAddr).emitEvent(MODULE, action, caller, value, data) {
        } catch {
        }
    }

    /* ============================================================
                          RECEIVERS (ERC721 / ERC1155)
       ============================================================ */

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function onERC1155Received(address, address, uint256, uint256, bytes calldata)
        external
        pure
        returns (bytes4)
    {
        return IERC1155Receiver.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata)
        external
        pure
        returns (bytes4)
    {
        return IERC1155Receiver.onERC1155BatchReceived.selector;
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return
            interfaceId == type(IERC1155Receiver).interfaceId ||
            interfaceId == type(IERC721Receiver).interfaceId;
    }

    receive() external payable {}
}
