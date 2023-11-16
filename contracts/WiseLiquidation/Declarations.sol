// SPDX-License-Identifier: -- WISE --

pragma solidity =0.8.21;

import "../InterfaceHub/IWiseLending.sol";
import "../InterfaceHub/IWiseSecurity.sol";
import "../InterfaceHub/IWiseOracleHub.sol";

import "../OwnableMaster.sol";

error TooManyShares();
error LiquidationDenied();
error CollateralTooSmall();

contract Declarations is OwnableMaster {

    event LiquidatedPartiallyFromTokens(
        uint256 indexed nftId,
        address indexed liquidator,
        address tokenPayback,
        address tokenReceived,
        uint256 indexed shares,
        uint256 timestamp
    );


    // ---- Variables ----

    // Base reward for liquidator normal liquidation
    uint256 public baseRewardLiquidation;

    // Base reward for liquidator power farm liquidation
    uint256 public baseRewardLiquidationFarm;

    // Max reward USD for liquidator power farm liquidation
    uint256 public maxFeeFarmUSD;

    // Max reward USD for liquidator normal liquidation
    uint256 public maxFeeUSD;


    // Precision factors for computations
    uint256 internal constant PRECISION_FACTOR_E18 = 1E18;
    uint256 internal constant PRECISION_FACTOR_E16 = 1E16;

    // Threshold values
    uint256 internal constant MAX_LIQUIDATION_50 = 50 * PRECISION_FACTOR_E16;
    uint256 internal constant BAD_DEBT_THRESHOLD = 89 * PRECISION_FACTOR_E16;

    // ---- Interfaces ----

    // Interface wiseLending contract
    IWiseLending public immutable WISE_LENDING;

    // Interface wiseSecurity contract
    IWiseSecurity public immutable WISE_SECURITY;

    // Interface oracleHub contract
    IWiseOracleHub public immutable WISE_ORACLE;

    constructor(
        address _master,
        address _wiseLendingAddress,
        address _oracleHubAddress,
        address _wiseSecurityAddress
    )
        OwnableMaster(
            _master
        )
    {
        if (_wiseLendingAddress == ZERO_ADDRESS) {
            revert NoValue();
        }

        if (_oracleHubAddress == ZERO_ADDRESS) {
            revert NoValue();
        }

        if (_wiseSecurityAddress == ZERO_ADDRESS) {
            revert NoValue();
        }

        WISE_ORACLE = IWiseOracleHub(
            _oracleHubAddress
        );

        WISE_LENDING = IWiseLending(
            _wiseLendingAddress
        );

        WISE_SECURITY = IWiseSecurity(
            _wiseSecurityAddress
        );

        baseRewardLiquidation = 10 * PRECISION_FACTOR_E16;
        baseRewardLiquidationFarm = 3 * PRECISION_FACTOR_E16;

        maxFeeUSD = 50000 * PRECISION_FACTOR_E18;
        maxFeeFarmUSD = 50000 * PRECISION_FACTOR_E18;

    }
}
