// SPDX-License-Identifier: -- WISE --

pragma solidity =0.8.24;

import "../InterfaceHub/IERC20.sol";
import "../InterfaceHub/IAave.sol";
import "../InterfaceHub/IPendle.sol";
import "../InterfaceHub/IAaveHub.sol";
import "../InterfaceHub/IWiseLending.sol";
import "../InterfaceHub/IStETH.sol";
import "../InterfaceHub/IWiseSecurity.sol";
import "../InterfaceHub/IPositionNFTs.sol";
import "../InterfaceHub/IWiseOracleHub.sol";
import "../InterfaceHub/IBalancerFlashloan.sol";
import "../InterfaceHub/ICurve.sol";
import "../InterfaceHub/IUniswapV3.sol";
import "../InterfaceHub/IOraclePendle.sol";

import "../TransferHub/WrapperHelper.sol";
import "../TransferHub/TransferHelper.sol";
import "../TransferHub/ApprovalHelper.sol";
import "../TransferHub/SendValueHelper.sol";

error GenericDeactivated();
error GenericAccessDenied();
error GenericInvalidParam();
error GenericTooMuchShares();
error GenericAmountTooSmall();
error GenericLevergeTooHigh();
error GenericDebtRatioTooLow();
error GenericNotBalancerVault();
error GenericDebtRatioTooHigh();
error GenericSendingOnGoing();

contract GenericDeclarations is
    WrapperHelper,
    TransferHelper,
    ApprovalHelper,
    SendValueHelper
{
    bool public isShutdown;
    bool public allowEnter;
    uint256 public collateralFactor;
    uint256 public minDepositEthAmount;

    uint256 internal constant MAX_PROPORTION = 96
        * PRECISION_FACTOR_E18
        / 100;

    address public immutable aaveTokenAddresses;
    address public immutable borrowTokenAddresses;

    address public FARM_ASSET;
    address public POOL_ASSET_AAVE;

    address public immutable ENTRY_ASSET;
    address public immutable PENDLE_CHILD;

    IAave public immutable AAVE;
    IAaveHub public immutable AAVE_HUB;
    IWiseLending public immutable WISE_LENDING;
    IWiseOracleHub public immutable ORACLE_HUB;
    IWiseSecurity public immutable WISE_SECURITY;
    IBalancerVault public immutable BALANCER_VAULT;
    IPositionNFTs public immutable POSITION_NFT;
    ICurve public immutable CURVE;
    IUniswapV3 public immutable UNISWAP_V3_ROUTER;

    IPendleSy public immutable PENDLE_SY;
    IPendleRouter public immutable PENDLE_ROUTER;
    IPendleMarket public immutable PENDLE_MARKET;
    IPendleRouterStatic public immutable PENDLE_ROUTER_STATIC;
    IOraclePendle public immutable PT_ORACLE_PENDLE;

    address internal immutable WETH_ADDRESS;
    address immutable AAVE_ADDRESS;
    address immutable AAVE_HUB_ADDRESS;
    address immutable AAVE_WETH_ADDRESS;

    address public collateralFactorRole;

    address internal constant PT_ORACLE_ADDRESS_MAINNET = 0x66a1096C6366b2529274dF4f5D8247827fe4CEA8;
    address internal constant PT_ORACLE_ADDRESS_ARBITRUM = 0x1Fd95db7B7C0067De8D45C0cb35D59796adfD187;

    bool public ethBack;
    bool public specialDepegCase;

    struct FarmData {
        uint256 wiseLendingNFT;
        uint256 leverage;
        uint256 amount;
        uint256 amountAfterMintFee;
        uint256 timestamp;
    }

    mapping(uint256 => FarmData) public farmData; //keyId to FarmData
    mapping(uint256 => bool) public isAave; //nftId to bool

    event FarmEntry(
        uint256 indexed keyId,
        uint256 indexed wiseLendingNFT,
        uint256 indexed leverage,
        uint256 amount,
        uint256 amountAfterMintFee,
        uint256 timestamp
    );

    event FarmExit(
        uint256 indexed keyId,
        uint256 indexed wiseLendingNFT,
        uint256 amount,
        uint256 timestamp
    );

    event FarmStatus(
        bool indexed state,
        uint256 timestamp
    );

    event ManualPaybackShares(
        uint256 indexed keyId,
        uint256 indexed wiseLendingNFT,
        uint256 amount,
        uint256 timestamp
    );

    event ManualWithdrawShares(
        uint256 indexed keyId,
        uint256 indexed wiseLendingNFT,
        uint256 amount,
        uint256 timestamp
    );

    event MinDepositChange(
        uint256 minDepositEthAmount,
        uint256 timestamp
    );

    event ETHReceived(
        uint256 amount,
        address from
    );

    event RegistrationFarm(
        uint256 nftId,
        uint256 timestamp
    );

    uint256 internal constant ETH_CHAIN_ID = 1;
    uint256 internal constant ARB_CHAIN_ID = 42161;

    uint256 internal constant FIFTY_PERCENT = 50E16;
    uint256 internal constant PRECISION_FACTOR_E18 = 1E18;
    uint256 internal constant PRECISION_FACTOR_E16 = 1E16;
    uint256 internal constant PRECISION_FACTOR_E18_2X = 2E18;

    uint256 internal constant MAX_AMOUNT = type(uint256).max;
    uint256 internal constant MAX_LEVERAGE = 15 * PRECISION_FACTOR_E18;

    uint24 public constant UNISWAP_V3_FEE = 100;
    address internal constant BALANCER_ADDRESS = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;

    constructor(
        address _wiseLendingAddress,
        address _pendleChildTokenAddress,
        address _pendleRouter,
        address _entryAsset,
        address _pendleSy,
        address _underlyingMarket,
        address _routerStatic,
        address _dexAddress,
        uint256 _collateralFactor
    )
        WrapperHelper(
            IWiseLending(_wiseLendingAddress).WETH_ADDRESS()
        )
    {
        PENDLE_ROUTER_STATIC = IPendleRouterStatic(
            _routerStatic
        );

        PENDLE_MARKET = IPendleMarket(
            _underlyingMarket
        );

        PENDLE_SY = IPendleSy(
            _pendleSy
        );

        PENDLE_ROUTER = IPendleRouter(
            _pendleRouter
        );

        CURVE = ICurve(
            _dexAddress
        );

        UNISWAP_V3_ROUTER = IUniswapV3(
            _dexAddress
        );

        ENTRY_ASSET = _entryAsset;
        PENDLE_CHILD = _pendleChildTokenAddress;

        WISE_LENDING = IWiseLending(
            _wiseLendingAddress
        );

        ORACLE_HUB = IWiseOracleHub(
            WISE_LENDING.WISE_ORACLE()
        );

        BALANCER_VAULT = IBalancerVault(
            BALANCER_ADDRESS
        );

        WISE_SECURITY = IWiseSecurity(
            WISE_LENDING.WISE_SECURITY()
        );

        WETH_ADDRESS = WISE_LENDING.WETH_ADDRESS();

        AAVE_HUB = IAaveHub(
            WISE_SECURITY.AAVE_HUB()
        );

        AAVE_ADDRESS = AAVE_HUB.AAVE_ADDRESS();

        AAVE = IAave(
            AAVE_ADDRESS
        );

        AAVE_HUB_ADDRESS = address(
            AAVE_HUB
        );

        POSITION_NFT = IPositionNFTs(
            WISE_LENDING.POSITION_NFT()
        );

        collateralFactor = _collateralFactor;
        borrowTokenAddresses = AAVE_HUB.WETH_ADDRESS();

        aaveTokenAddresses = AAVE_HUB.aaveTokenAddress(
            borrowTokenAddresses
        );

        AAVE_WETH_ADDRESS = aaveTokenAddresses;

        if (block.chainid == ETH_CHAIN_ID) {
            minDepositEthAmount = 3 ether;
        } else {
            minDepositEthAmount = 0.03 ether;
        }

        address PT_ORACLE_ADDRESS = block.chainid == 1
            ? PT_ORACLE_ADDRESS_MAINNET
            : PT_ORACLE_ADDRESS_ARBITRUM;

        PT_ORACLE_PENDLE = IOraclePendle(
            PT_ORACLE_ADDRESS
        );
    }

    function doApprovals()
        external
        virtual
    {
        _doApprovals(
            address(WISE_LENDING)
        );
    }

    function _doApprovals(
        address _wiseLendingAddress
    )
        internal
        virtual
    {}

    modifier isActive()
    {
        _isActive();
        _;
    }

    function _isActive()
        internal
        virtual
        view
    {
        if (isShutdown == true) {
            revert GenericDeactivated();
        }
    }

    modifier onlyCollateralFactorRole() {
        _onlyCollateralFactorRole();
        _;
    }

    function _onlyCollateralFactorRole()
        internal
        virtual
    {
        if (msg.sender != collateralFactorRole) {
            revert GenericAccessDenied();
        }
    }
}
