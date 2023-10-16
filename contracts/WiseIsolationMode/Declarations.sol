// SPDX-License-Identifier: -- WISE --
pragma solidity =0.8.21;

import '../InterfaceHub/IERC20.sol';
import '../InterfaceHub/IWiseLending.sol';
import '../InterfaceHub/IWiseSecurity.sol';
import '../InterfaceHub/IWiseOracleHub.sol';
import '../InterfaceHub/IWiseLiquidation.sol';

import "../TransferHub/ApprovalHelper.sol";
import './WiseIsolationModeEvents.sol';

error ResultsInBadDebt();
error TargetDebtTooLow();
error TransferFromFailed();
error TransferFailed();
error AlreadySet();

contract Declarations is WiseIsolationModeEvents, ApprovalHelper {

    constructor(
        address _oracleHubAddress,
        address _wiseLendingAddress,
        address _wiseLiquidationAddress,
        address _collateralTokenAddress,
        address _wiseSecurityAddress,
        uint256 _collateralFactor,
        address[] memory _borrowTokenAddresses,
        uint256[] memory _portionTotalBorrow
    )
    {
        if (_borrowTokenAddresses.length != _portionTotalBorrow.length) {
            revert("WiseIsolation: ARGUMENT_MISSMATCH");
        }

        COLLATERAL_TOKEN_ADDRESS = _collateralTokenAddress;

        ORACLE_HUB = IWiseOracleHub(
            _oracleHubAddress
        );

        WISE_LENDING = IWiseLending(
            _wiseLendingAddress
        );

        WISE_LIQUIDATION = IWiseLiquidation(
            _wiseLiquidationAddress
        );

        WISE_SECURITY = IWiseSecurity(
            _wiseSecurityAddress
        );

        borrowTokenNumber = _borrowTokenAddresses.length;

        collateralFactor = _collateralFactor;
        portionTotalBorrow = _portionTotalBorrow;
        borrowTokenAddresses = _borrowTokenAddresses;

        _safeApprove(
            _collateralTokenAddress,
            _wiseLendingAddress,
            0
        );

        _safeApprove(
            _collateralTokenAddress,
            _wiseLendingAddress,
            MAX_AMOUNT
        );

        uint256 i;
        uint256 l = _borrowTokenAddresses.length;

        for (i; i < l;) {

            _safeApprove(
                _borrowTokenAddresses[i],
                _wiseLendingAddress,
                MAX_AMOUNT
            );

            _safeApprove(
                _borrowTokenAddresses[i],
                _wiseLiquidationAddress,
                MAX_AMOUNT
            );

            unchecked {
                ++i;
            }
        }
    }

    IWiseLending public immutable WISE_LENDING;
    IWiseSecurity public immutable WISE_SECURITY;
    IWiseOracleHub public immutable ORACLE_HUB;
    IWiseLiquidation public immutable WISE_LIQUIDATION;

    address public immutable COLLATERAL_TOKEN_ADDRESS;

    uint256 public collateralFactor;
    uint256 public borrowTokenNumber;

    uint256[] public portionTotalBorrow;
    address[] public borrowTokenAddresses;

    mapping(uint256 => uint256) public nftToIndex;

    uint256 internal constant MAX_AMOUNT = type(uint256).max;
    uint256 internal constant PRECISION_FACTOR_E18 = 1 ether;
    uint256 internal constant MIN_DEPOSIT_USD_AMOUNT = 5000 * PRECISION_FACTOR_E18;
    address internal constant ZERO_ADDRESS = address(0x0);
}
