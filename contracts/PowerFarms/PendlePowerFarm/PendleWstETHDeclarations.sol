// SPDX-License-Identifier: -- WISE --

pragma solidity =0.8.21;

import "../../InterfaceHub/IWETH.sol";
import "../../InterfaceHub/IAave.sol";
import "../../InterfaceHub/IStETH.sol";
import "../../InterfaceHub/ICurve.sol";
import "../../InterfaceHub/IWstETH.sol";
import "../../InterfaceHub/IPendle.sol";
import "../../InterfaceHub/IAaveHub.sol";
import "../../InterfaceHub/IWiseLending.sol";
import "../../InterfaceHub/IPositionNFTs.sol";
import "../../InterfaceHub/IWiseOracleHub.sol";
import "../../InterfaceHub/IBalancerFlashloan.sol";
import "../../InterfaceHub/IPendlePowerFarmsLock.sol";

import "../../TransferHub/TransferHelper.sol";
import "../../TransferHub/ApprovalHelper.sol";

import "./HybridToken.sol";
import "../../OwnableMaster.sol";

error NotAuthorized();
error SwapCallFailed();
error OffchainDataWrong();
error DeviationTooBig();
error WrongSelector();
error AmountTooSmall();
error OverhangChanged();
error LeverageTooHigh();
error DebtRatioTooHigh();
error InvalidAction();
error ResultsInBadDebt();
error NotLockerContract();
error WrongMarketOrReceiver();
error OracleUnderflow();
error InvalidToken();

contract PendleWstETHDeclarations is
    TransferHelper,
    ApprovalHelper,
    OwnableMaster
{
    // Bool indicating that a power farm is deactivated
    bool internal isShutdown;

    // Bool for reentrancy guard during leverage
    bool internal allowEnter;

    // Array of ERC20 interfaces for balancer flashloan
    IERC20[] globalTokens;

    // Array of token amounts for balancer flashloan
    uint256[] globalAmounts;

    address referralAddress;

    // Collateral factor used for wstETH collateral
    uint256 public collateralFactor;
    uint256 public compoundSyAmount;

    uint256 immutable USAGE_FEE;
    uint256 public oracleSyAmount;

    uint256 constant SHARED_FLASH_LOAN_SIZE = 214;

    address internal underlyingFarmToken;

    FarmState public farmState;

    struct FarmState {
        bool ptGreater;
        uint256 totalYtAmount;
        uint256 totalSyAmount;
        uint256 totalPtAmount;
        uint256 totalLpAmount;
        uint256 contractPtAmount;
    }

    struct FlashLoanData {
        bool ethBack;
        bool ptGreaterFetched;
        uint256 nftId;
        uint256 initialAmount;
        uint256 lendingShares;
        uint256 borrowShares;
        uint256 minOutAmount;
        uint256 overhangFetched;
        address payable caller;
        bytes swapDataFetched;
    }

    struct NftInfo {
        uint256 borrowShares;
        uint256 lendingShares;
        uint256 borrowAmount;
    }

    struct TokenOutput {
        uint256 minTokenOut;
        address tokenOut;
        address tokenRedeemSy;
        address bulk;
        address pendleSwap;
        SwapData swapData;
    }

    struct SwapData {
        bool needScale;
        SwapType swapType;
        address extRouter;
        bytes extCalldata;
    }

    enum SwapType {
        NONE,
        KYBERSWAP,
        ONE_INCH,
        // ETH_WETH not used in Aggregator
        ETH_WETH
    }

    // Interfaces -----------------------------------------

    IAaveHub immutable AAVE_HUB;
    IWiseOracleHub immutable ORACLE_HUB;
    IPositionNFTs immutable POSITION_NFT;
    IWiseLending public immutable WISE_LENDING;

    IAave immutable AAVE;
    ICurve immutable CURVE;
    IStETH immutable ST_ETH;
    IWstETH immutable WST_ETH;
    HybridToken public immutable HYBRID_TOKEN;

    IBalancerVault immutable public BALANCER_VAULT;

    IPendleYt immutable YT_PENDLE;
    IPendleRouter immutable ROUTER_PENDLE;

    IPendleSy immutable SY_PENDLE;
    IPendleMarket immutable LP_PENDLE;
    IPendlePowerFarmsLock public immutable LOCK_CONTRACT;

    // Constant addresses -----------------------------------------

    address constant ST_ETH_ADDRESS = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
    address constant WST_ETH_ADDRESS = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;

    address constant AAVE_ADDRESS = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
    address constant WETH_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant BALANCER_ADDRESS = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
    address constant AAVE_HUB_ADDRESS = 0x4307d8207f2C429f0dCbd9051b5B1d638c3b7fbB;
    address constant AAVE_WETH_ADDRESS = 0x4d5F47FA6A74757f35C14fD3a6Ef8E3C9BC514E8;
    address constant CURVE_POOL_ADDRESS = 0xDC24316b9AE028F1497c275EB9192a3Ea0f67022;

    address public constant PT_PENDLE_ADDRESS = 0x7758896b6AC966BbABcf143eFA963030f17D3EdF;
    address public constant SY_PENDLE_ADDRESS = 0xcbC72d92b2dc8187414F6734718563898740C0BC;
    address public constant PENDLE_ROUTER_ADDRESS = 0x0000000001E4ef00d069e71d6bA041b0A16F7eA0;

    address public constant YT_PENDLE_ADDRESS = 0xc3863CCcd012f8E45D72Ec87c5A9C4F77e1C7549;
    address public constant PENDLE_MARKET_ADDRESS = 0xD0354D4e7bCf345fB117cabe41aCaDb724eccCa2;

    // Maximal allowed leverage factor
    uint256 internal constant MAX_LEVERAGE = 15 * PRECISION_FACTOR_E18;

    // Minimal required deposit amount for leveraged postion in USD
    uint256 internal constant MIN_DEPOSIT_USD_AMOUNT = 5000 * PRECISION_FACTOR_E18;

    uint256 constant DEVIATION_MINT = 5 * PRECISION_FACTOR_E15;
    uint256 constant DEVIATION_CLOSE = 8 * PRECISION_FACTOR_E15;
    uint256 constant DEVIATION_COMPOUND = 10 * PRECISION_FACTOR_E15;
    uint256 constant OFFSET_INPUT_AMOUNT = 44;
    uint256 constant OFFSET_INPUT_AMOUNT_END = 76;

    // Math constant for computations
    uint256 internal constant PRECISION_FACTOR_E15 = 1E15;
    uint256 internal constant PRECISION_FACTOR_E18 = 1E18;

    // Max possible amount for uint256
    uint256 internal constant MAX_AMOUNT = type(uint256).max;

    bytes4 constant SELECTOR_SY_FOR_EXACT_PT = 0x6b8bdf32;
    bytes4 constant SELECTOR_SY_FOR_EXACT_YT = 0xbf1bd434;
    bytes4 constant SELECTOR_EXACT_SY_FOR_PT = 0x83c71b69;
    bytes4 constant SELECTOR_EXACT_SY_FOR_YT = 0xfdd71f43;

    bytes4 constant SELECTOR_EXACT_PT_FOR_TOKEN = 0xb85f50ba;
    bytes4 constant SELECTOR_EXACT_YT_FOR_TOKEN = 0xd6308fa4;

    modifier isActive() {
        _isActive();
        _;
    }

    modifier checkCaller() {
        _checkCaller();
        _;
    }

    function _checkCaller()
        private
        view
    {
        if (msg.sender != address(this)) {
            revert NotAuthorized();
        }
    }

    function _isActive()
        private
        view
    {
        if (isShutdown == true) {
            revert InvalidAction();
        }
    }

    event ETHReceived(
        uint256 indexed amount,
        address indexed from
    );

    event RegistrationFarm(
        uint256 indexed nftId,
        uint256 indexed timestamp
    );

    constructor(
        address _wiseLending,
        address _lockContract,
        uint256 _collateralFactor
    )
        OwnableMaster(
            msg.sender
        )
    {
        USAGE_FEE = 5 * PRECISION_FACTOR_E15;

        referralAddress = msg.sender;
        collateralFactor = _collateralFactor;

        underlyingFarmToken = WST_ETH_ADDRESS;

        WISE_LENDING = IWiseLending(
            _wiseLending
        );

        ORACLE_HUB = IWiseOracleHub(
            WISE_LENDING.WISE_ORACLE()
        );

        BALANCER_VAULT = IBalancerVault(
            BALANCER_ADDRESS
        );

        POSITION_NFT = IPositionNFTs(
            WISE_LENDING.POSITION_NFT()
        );

        LOCK_CONTRACT = IPendlePowerFarmsLock(
            _lockContract
        );

        AAVE = IAave(
            AAVE_ADDRESS
        );

        ST_ETH = IStETH(
            ST_ETH_ADDRESS
        );

        WST_ETH = IWstETH(
            WST_ETH_ADDRESS
        );

        CURVE = ICurve(
            CURVE_POOL_ADDRESS
        );

        LP_PENDLE = IPendleMarket(
            PENDLE_MARKET_ADDRESS
        );

        SY_PENDLE = IPendleSy(
            SY_PENDLE_ADDRESS
        );

        YT_PENDLE = IPendleYt(
            YT_PENDLE_ADDRESS
        );

        ROUTER_PENDLE = IPendleRouter(
            PENDLE_ROUTER_ADDRESS
        );

        HYBRID_TOKEN = new HybridToken(
            address(this)
        );
    }
}
