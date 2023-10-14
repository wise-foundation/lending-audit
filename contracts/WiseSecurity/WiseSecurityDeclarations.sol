// SPDX-License-Identifier: -- WISE --

pragma solidity =0.8.21;

import "../InterfaceHub/IERC20.sol";
import "../InterfaceHub/ICurve.sol";
import "../InterfaceHub/IPositionNFTs.sol";
import "../InterfaceHub/IWiseOracleHub.sol";
import "../InterfaceHub/IFeeManager.sol";
import "../InterfaceHub/IWiseLending.sol";
import "../InterfaceHub/IWiseLiquidation.sol";
import "../InterfaceHub/IAaveHub.sol";

import "../FeeManager/FeeManager.sol";
import "../OwnableMaster.sol";

error NotAllowedWiseSecurity();
error ChainlinkDead();
error PositionLocked();
error ResultsInBadDebt();
error DepositCapReached();
error NotEnoughCollateral();
error NotAllowedToBorrow();
error OpenBorrowPosition();
error NonVerifiedPool();
error NotOwner();
error LiquidationDenied();
error TooManyShares();
error NotRegistered();
error Blacklisted();
error SecuritySwapFailed();

contract WiseSecurityDeclarations is OwnableMaster {

    constructor(
        address _master,
        address _wiseLendingAddress,
        address _aaveHubAddress,
        uint256 _borrowPercentageCap
    )
        OwnableMaster(
            _master
        )
    {
        WISE_LENDING = IWiseLending(
            _wiseLendingAddress
        );

        AAVE_HUB = _aaveHubAddress;

        address master = WISE_LENDING.master();
        address oracleHubAddress = WISE_LENDING.WISE_ORACLE();
        address positionNFTAddress = WISE_LENDING.POSITION_NFT();

        FeeManager feeManagerContract = new FeeManager(
            master,
            IAaveHub(AAVE_HUB).AAVE_ADDRESS(),
            _wiseLendingAddress,
            oracleHubAddress,
            address(this),
            positionNFTAddress
        );

        WISE_ORACLE = IWiseOracleHub(
            oracleHubAddress
        );

        FEE_MANAGER = IFeeManager(
            address(feeManagerContract)
        );

        WISE_LIQUIDATION = IWiseLiquidation(
            _wiseLendingAddress
        );

        POSITION_NFTS = IPositionNFTs(
            positionNFTAddress
        );

        borrowPercentageCap = _borrowPercentageCap;

        baseRewardLiquidation = 10 * PRECISION_FACTOR_E16;
        baseRewardLiquidationFarm = 3 * PRECISION_FACTOR_E16;

        maxFeeUSD = 50000 * PRECISION_FACTOR_E18;
        maxFeeFarmUSD = 50000 * PRECISION_FACTOR_E18;
    }

    // ---- Variables ----

    uint256 public borrowPercentageCap;
    address public immutable AAVE_HUB;

    // ---- Interfaces ----

    // Interface feeManager contract
    IFeeManager public immutable FEE_MANAGER;

    // Interface wiseLending contract
    IWiseLending public immutable WISE_LENDING;

    // Interface position NFT contract
    IPositionNFTs public immutable POSITION_NFTS;

    // Interface oracleHub contract
    IWiseOracleHub public immutable WISE_ORACLE;

    // Interface wiseLiquidation contract
    IWiseLiquidation public immutable WISE_LIQUIDATION;

    // Threshold values
    uint256 internal constant MAX_LIQUIDATION_50 = 50E16;
    uint256 internal constant BAD_DEBT_THRESHOLD = 89E16;

    uint256 internal constant TARGET_DEC = 18;
    uint256 internal constant UINT256_MAX = type(uint256).max;
    uint256 internal constant ONE_YEAR = 52 weeks;

    // Precision factors for computations
    uint256 internal constant PRECISION_FACTOR_E16 = 1E16;
    uint256 internal constant PRECISION_FACTOR_E18 = 1E18;
    uint256 internal constant PRECISION_FACTOR_E36 = PRECISION_FACTOR_E18 * PRECISION_FACTOR_E18;


    // ---- Mappings ----

    // Mapping pool token to blacklist bool
    mapping(address => bool) public wasBlacklisted;

    // Mapping basic swap data for s curve swaps to pool token
    mapping(address => CurveSwapStructData) public curveSwapInfoData;

    // Mapping swap info of swap token for reentrency guard to pool token
    mapping(address => CurveSwapStructToken) public curveSwapInfoToken;

    // ---- Liquidation Variables ----

    // @TODO - store all 4 in a struct:

    // Max reward USD for liquidator power farm liquidation
    uint256 public maxFeeUSD;

    // Max reward USD for liquidator normal liquidation
    uint256 public maxFeeFarmUSD;

    // Base reward for liquidator normal liquidation
    uint256 public baseRewardLiquidation;

    // Base reward for liquidator power farm liquidation
    uint256 public baseRewardLiquidationFarm;
}
