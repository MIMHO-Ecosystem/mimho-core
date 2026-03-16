/// -----------------------------------------------------------------------
/// MIMHO DAO TREASURY VESTING
/// Official MIMHO Ecosystem Contract
///
/// Network: BNB Smart Chain
/// Contract Address:
/// 0xa4Cf1fB7275cBe054A8fe67b27ca16cF2c4C5285
///
/// BscScan:
/// https://bscscan.com/address/0xa4Cf1fB7275cBe054A8fe67b27ca16cF2c4C5285
/// -----------------------------------------------------------------------

// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// -----------------------------------------------------------------------
/// MIMHO DAO TREASURY VESTING
/// Weekly DAO Treasury release contract
/// - Total: 200B MIMHO
/// - Release: 2.5B per week
/// - Duration: 80 weeks
/// - Starts ONLY after Registry.daoActivated() == true
/// - No retroactive accrual before latch
/// -----------------------------------------------------------------------

interface IERC20Minimal {
    function balanceOf(address a) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
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

interface IMIMHORegistry {
    function getContract(bytes32 key) external view returns (address);

    function KEY_MIMHO_TOKEN() external view returns (bytes32);
    function KEY_MIMHO_EVENTS_HUB() external view returns (bytes32);
    function KEY_MIMHO_DAO_WALLET() external view returns (bytes32);

    function daoActivated() external view returns (bool);
    function dao() external view returns (address);
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

contract MIMHODAOTreasuryVesting is ReentrancyGuardLite {
    string public constant icontratoMimho = "MIMHO_DAO_TREASURY_VESTING";
    string public constant version = "1.0.0";

    uint64 public constant WEEK = 7 days;

    uint256 public constant TOTAL_ALLOCATED = 200_000_000_000 ether;
    uint256 public constant WEEKLY_RELEASE = 2_500_000_000 ether;
    uint256 public constant TOTAL_WEEKS = 80;

    bytes32 public constant MODULE = keccak256("MIMHO_DAO_TREASURY_VESTING");
    bytes32 public constant ACTION_START_LATCHED = keccak256("DAO_TREASURY_START_LATCHED");
    bytes32 public constant ACTION_CLAIM = keccak256("DAO_TREASURY_CLAIM");
    bytes32 public constant ACTION_PAUSED = keccak256("DAO_TREASURY_PAUSED");
    bytes32 public constant ACTION_UNPAUSED = keccak256("DAO_TREASURY_UNPAUSED");
    bytes32 public constant ACTION_RECOVER = keccak256("DAO_TREASURY_RECOVER");

    address public immutable owner;
    IMIMHORegistry public immutable registry;

    bool public paused;
    bool public daoStartLatched;
    uint64 public daoStartTimestamp;
    uint256 public totalClaimed;

    event DAOStartLatched(uint64 indexed startTimestamp);
    event Claimed(address indexed caller, address indexed receiver, uint256 amount, uint256 totalClaimedAfter);
    event PauseChanged(bool paused);
    event RecoveredToken(address indexed token, address indexed to, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "ONLY_OWNER");
        _;
    }

    modifier onlyDAOorOwner() {
        if (registry.daoActivated()) {
            require(msg.sender == registry.dao() || msg.sender == owner, "ONLY_DAO_OR_OWNER");
        } else {
            require(msg.sender == owner, "ONLY_OWNER_PRE_DAO");
        }
        _;
    }

    modifier notPaused() {
        require(!paused, "PAUSED");
        _;
    }

    constructor(address registryAddr) {
        require(registryAddr != address(0), "ZERO_REGISTRY");
        owner = msg.sender;
        registry = IMIMHORegistry(registryAddr);
    }

    function _emitHubEvent(bytes32 action, address caller, uint256 value, bytes memory data) internal {
        address hubAddr = registry.getContract(registry.KEY_MIMHO_EVENTS_HUB());
        if (hubAddr == address(0)) return;

        try IMIMHOEventsHub(hubAddr).emitEvent(MODULE, action, caller, value, data) {
        } catch {
        }
    }

    function _token() internal view returns (IERC20Minimal) {
        address tokenAddr = registry.getContract(registry.KEY_MIMHO_TOKEN());
        require(tokenAddr != address(0), "TOKEN_NOT_SET");
        return IERC20Minimal(tokenAddr);
    }

    function daoWallet() public view returns (address) {
        address w = registry.getContract(registry.KEY_MIMHO_DAO_WALLET());
        require(w != address(0), "DAO_WALLET_NOT_SET");
        return w;
    }

    function pauseEmergencial() external onlyDAOorOwner {
        paused = true;
        emit PauseChanged(true);
        _emitHubEvent(ACTION_PAUSED, msg.sender, 0, "");
    }

    function unpause() external onlyDAOorOwner {
        paused = false;
        emit PauseChanged(false);
        _emitHubEvent(ACTION_UNPAUSED, msg.sender, 0, "");
    }

    function latchDAOStartIfActive() public notPaused {
        require(!daoStartLatched, "DAO_START_ALREADY_LATCHED");
        require(registry.daoActivated(), "DAO_NOT_ACTIVE");

        daoStartLatched = true;
        daoStartTimestamp = uint64(block.timestamp);

        emit DAOStartLatched(daoStartTimestamp);
        _emitHubEvent(ACTION_START_LATCHED, msg.sender, 0, abi.encode(daoStartTimestamp));
    }

    function weeksElapsed() public view returns (uint256) {
        if (!daoStartLatched) return 0;
        if (block.timestamp < daoStartTimestamp) return 0;

        uint256 elapsed = block.timestamp - daoStartTimestamp;
        uint256 w = elapsed / WEEK;

        if (w > TOTAL_WEEKS) return TOTAL_WEEKS;
        return w;
    }

    function vestedAmount() public view returns (uint256) {
        uint256 w = weeksElapsed();
        uint256 vested = w * WEEKLY_RELEASE;
        if (vested > TOTAL_ALLOCATED) vested = TOTAL_ALLOCATED;
        return vested;
    }

    function claimableNow() public view returns (uint256) {
        uint256 vested = vestedAmount();
        if (totalClaimed >= vested) return 0;
        return vested - totalClaimed;
    }

    function remaining() external view returns (uint256) {
        if (totalClaimed >= TOTAL_ALLOCATED) return 0;
        return TOTAL_ALLOCATED - totalClaimed;
    }

    function nextClaimTime() external view returns (uint64) {
        if (!daoStartLatched) return 0;
        if (totalClaimed >= TOTAL_ALLOCATED) return 0;

        uint256 w = weeksElapsed();
        if (w >= TOTAL_WEEKS) return 0;

        return uint64(uint256(daoStartTimestamp) + ((w + 1) * WEEK));
    }

    function claim() external nonReentrant notPaused {
        uint256 amount = claimableNow();
        require(amount > 0, "NOTHING_TO_CLAIM");

        address receiver = daoWallet();

        totalClaimed += amount;
        require(_token().transfer(receiver, amount), "TRANSFER_FAIL");

        emit Claimed(msg.sender, receiver, amount, totalClaimed);
        _emitHubEvent(ACTION_CLAIM, msg.sender, amount, abi.encode(receiver, amount, totalClaimed));
    }

    function balances() external view returns (
        uint256 contractBalance,
        uint256 alreadyClaimed,
        uint256 claimable,
        uint256 vested,
        uint256 weeksCounted
    ) {
        contractBalance = _token().balanceOf(address(this));
        alreadyClaimed = totalClaimed;
        claimable = claimableNow();
        vested = vestedAmount();
        weeksCounted = weeksElapsed();
    }

    function recoverERC20(address token, address to, uint256 amount) external onlyDAOorOwner nonReentrant {
        require(token != address(_token()), "NO_RECOVER_MIMHO");
        require(to != address(0), "ZERO_TO");
        require(amount > 0, "ZERO_AMOUNT");

        (bool ok, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20Minimal.transfer.selector, to, amount)
        );
        require(ok && (data.length == 0 || abi.decode(data, (bool))), "RECOVER_FAIL");

        emit RecoveredToken(token, to, amount);
        _emitHubEvent(ACTION_RECOVER, msg.sender, amount, abi.encode(token, to, amount));
    }

    receive() external payable {}
    fallback() external payable {}
}
