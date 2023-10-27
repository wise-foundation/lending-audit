// SPDX-License-Identifier: -- WISE --

pragma solidity =0.8.21;

import "../../InterfaceHub/ISDai.sol";
import "../../InterfaceHub/IAave.sol";
import "../../InterfaceHub/IDssPsm.sol";
import "../../InterfaceHub/IAaveHub.sol";
import "../../InterfaceHub/IUniswapV3.sol";
import "../../InterfaceHub/IWiseLending.sol";
import "../../InterfaceHub/IPositionNFTs.sol";
import "../../InterfaceHub/IWiseSecurity.sol";
import "../../InterfaceHub/IWiseOracleHub.sol";
import "../../InterfaceHub/IBalancerFlashloan.sol";

import "../../OwnableMaster.sol";
import "../../TransferHub/TransferHelper.sol";
import "../../TransferHub/ApprovalHelper.sol";

error NotAllowed();
error AlreadySet();
error OutOfBound();
error Deactivated();
error AmountTooSmall();
error LeverageTooHigh();
error ResultsInBadDebt();
error DebtRatioTooHigh();
error PositionNotEmpty();
error NotBalancerVault();
error DebtratioTooHigh();

abstract contract sDaiFarmDeclarations is
    TransferHelper,
    ApprovalHelper,
    OwnableMaster
{
    // Bool indicating that a power farm is deactivated
    bool public isShutdown;

    // Bool for reentrancy guard during leverage
    bool internal allowEnter;

    // Array of ERC20 interfaces for balancer flashloan
    IERC20[] public globalTokens;

    // Array of token amounts for balancer flashloan
    uint256[] public globalAmounts;

    // Array of aave token addresses of borrow tokens
    address[] public aaveTokenAddresses;

    // Array of borrow taken addreses possible to use
    address[] public borrowTokenAddresses;

    // Collateral factor used for sDAI collateral
    uint256 public collateralFactor;

    // Saving the chosen borrow token for opening the position per {_nftId}
    mapping(uint256 => uint256) public nftToIndex;

    ISDai public immutable SDAI;
    IAave public immutable AAVE;
    IDssPsm public immutable DSS_PSM;
    IAaveHub public immutable AAVE_HUB;
    IUniswapV3 public immutable UNISWAP;
    IWiseLending public immutable WISE_LENDING;
    IWiseOracleHub public immutable ORACLE_HUB;
    IPositionNFTs public immutable POSITION_NFT;
    IWiseSecurity public immutable WISE_SECURITY;
    IBalancerVault public immutable BALANCER_VAULT;

    address internal constant DSS_PSM_ADD = 0x89B78CfA322F6C5dE0aBcEecab66Aee45393cC5A;
    address internal constant DAI_ADDRESS = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address internal constant USDC_ADDRESS = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal constant USDT_ADDRESS = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address internal constant SDAI_ADDRESS = 0x83F20F44975D03b1b09e64809B757c47f942BEeA;

    address internal constant AAVE_ADDRESS = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
    address internal constant BLANCER_ADDRESS = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
    address internal constant AAVE_HUB_ADDRESS = 0x4307d8207f2C429f0dCbd9051b5B1d638c3b7fbB;
    address internal constant UNIV3_ROUTER_ADD = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address internal constant PSM_USDC_A_ADD = 0x0A59649758aa4d66E25f08Dd01271e891fe52199;

    // Maximal allowed leverage factor
    uint256 internal constant MAX_LEVERAGE = 15 * PRECISION_FACTOR_E18;

    // Minimal required deposit amount for leveraged postion in USD
    uint256 internal constant MIN_DEPOSIT_USD_AMOUNT = 5000 * PRECISION_FACTOR_E18;

    // Math constant for computations
    uint256 internal constant PRECISION_FACTOR_E12 = 1E12;
    uint256 internal constant PRECISION_FACTOR_E15 = 1E15;
    uint256 internal constant PRECISION_FACTOR_E16 = 1E16;
    uint256 internal constant PRECISION_FACTOR_E18 = 1E18;

    // Max possible amount for uint256
    uint256 internal constant MAX_AMOUNT = type(uint256).max;

    // Enum to indicate token via index
    enum Token {
        DAI,
        USDC,
        USDT
    }

    constructor(
        address _wiseLendingAddress,
        uint256 _collateralFactor
    )
        OwnableMaster(
            msg.sender
        )
    {
        WISE_LENDING = IWiseLending(
            _wiseLendingAddress
        );

        ORACLE_HUB = IWiseOracleHub(
            WISE_LENDING.WISE_ORACLE()
        );

        POSITION_NFT = IPositionNFTs(
            WISE_LENDING.POSITION_NFT()
        );

        WISE_SECURITY = IWiseSecurity(
            WISE_LENDING.WISE_SECURITY()
        );

        BALANCER_VAULT = IBalancerVault(
            BLANCER_ADDRESS
        );

        SDAI = ISDai(
            SDAI_ADDRESS
        );

        AAVE = IAave(
            AAVE_ADDRESS
        );

        AAVE_HUB = IAaveHub(
            AAVE_HUB_ADDRESS
        );

        DSS_PSM = IDssPsm(
            DSS_PSM_ADD
        );

        UNISWAP = IUniswapV3(
            UNIV3_ROUTER_ADD
        );

        collateralFactor = _collateralFactor;

        borrowTokenAddresses.push(
            DAI_ADDRESS
        );

        borrowTokenAddresses.push(
            USDC_ADDRESS
        );

        borrowTokenAddresses.push(
            USDT_ADDRESS
        );

        _doApprovals(
            address(WISE_LENDING)
        );
    }

    function doApprovals()
        external
    {
        _doApprovals(
            address(WISE_LENDING)
        );
    }

    function _doApprovals(
        address _wiseLending
    )
        internal
    {
        uint256 i;
        uint256 l = borrowTokenAddresses.length;

        for (i; i < l;) {

            aaveTokenAddresses.push(
                AAVE_HUB.aaveTokenAddress(
                    borrowTokenAddresses[i]
                )
            );

            _safeApprove(
                borrowTokenAddresses[i],
                AAVE_HUB_ADDRESS,
                MAX_AMOUNT
            );

            _safeApprove(
                aaveTokenAddresses[i],
                _wiseLending,
                MAX_AMOUNT
            );

            unchecked {
                ++i;
            }
        }

        _safeApprove(
            SDAI_ADDRESS,
            _wiseLending,
            MAX_AMOUNT
        );

        _safeApprove(
            DAI_ADDRESS,
            SDAI_ADDRESS,
            MAX_AMOUNT
        );

        _safeApprove(
            USDT_ADDRESS,
            UNIV3_ROUTER_ADD,
            MAX_AMOUNT
        );

        _safeApprove(
            USDC_ADDRESS,
            UNIV3_ROUTER_ADD,
            MAX_AMOUNT
        );

        _safeApprove(
            borrowTokenAddresses[1],
            PSM_USDC_A_ADD,
            MAX_AMOUNT
        );

        _safeApprove(
            DAI_ADDRESS,
            DSS_PSM_ADD,
            MAX_AMOUNT
        );
    }

    modifier isActive() {
        if (isShutdown == true) {
            revert Deactivated();
        }
        _;
    }

    event FarmEntry(
        uint256 indexed keyId,
        uint256 indexed wiseLendingNFT,
        uint256 indexed leverage,
        uint256 amount,
        uint256 minOutAmount,
        uint256 timestamp
    );

    event FarmExit(
        uint256 indexed keyId,
        uint256 indexed wiseLendingNFT,
        uint256 maxInAmount,
        uint256 timestamp
    );

    event RegistrationFarm(
        uint256 indexed nftId,
        uint256 indexed index,
        uint256 timestamp
    );
}
