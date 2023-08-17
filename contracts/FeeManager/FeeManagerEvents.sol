// SPDX-License-Identifier: -- WISE --

pragma solidity =0.8.21;

contract FeeManagerEvents {

    event PoolTokenAdded(
        address poolToken,
        uint256 timestamp
    );

    event BadDebtIncreasedLiquidation(
        uint256 amount,
        uint256 timestamp
    );

    event TotalBadDebtIncreased(
        uint256 amount,
        uint256 timestamp
    );

    event TotalBadDebtDecreased(
        uint256 amount,
        uint256 timestamp
    );

    event SetBadDebtPosition(
        uint256 nftId,
        uint256 amount,
        uint256 timestamp
    );

    event UpdateBadDebtPosition(
        uint256 nftId,
        uint256 newAmount,
        uint256 timestamp
    );

    event SetBeneficial(
        address user,
        address[] token,
        uint256 timestamp
    );

    event RevokeBeneficial(
        address user,
        address[] token,
        uint256 timestamp
    );

    event ClaimedFeesWise(
        address token,
        uint256 amount,
        uint256 timestamp
    );

    event ClaimedFeesBeneficial(
        address indexed user,
        address indexed token,
        uint256 amount,
        uint256 indexed timestamp
    );

    event PayedBackBadDebt(
        uint256 nftId,
        address indexed sender,
        address paybackToken,
        address receivingToken,
        uint256 indexed paybackAmount,
        uint256 timestamp
    );

    event PayedBackBadDebtFree(
        uint256 nftId,
        address indexed sender,
        address paybackToken,
        uint256 indexed paybackAmount,
        uint256 timestampp
    );
}