// SPDX-License-Identifier: -- WISE --

pragma solidity =0.8.24;

interface IGenericPowerFarm {

    function setCollateralFactor(
        uint256 _newCollfactor
    )
        external;

    function getLiveDebtRatio(
        uint256 _nftId
    )
        external
        view
        returns (uint256);

    function farmingKeys(
        uint256 _keyId
    )
        external
        view
        returns (uint256);

    function enterFarm(
        bool _isAave,
        uint256 _amount,
        uint256 _leverage,
        uint256 _allowedSpread
    )
        external
        returns (uint256);

    function enterFarmETH(
        bool _isAave,
        uint256 _leverage,
        uint256 _allowedSpread
    )
        external
        returns (uint256);

    function exitFarm(
        uint256 _keyId,
        uint256 _allowedSpread,
        bool _ethBack
    )
        external;

    function liquidatePartiallyFromToken(
        uint256 _nftId,
        uint256 _nftIdLiquidator,
        uint256 _shareAmountToPay
    )
        external
        returns (
            uint256 paybackAmount,
            uint256 receivingAmount
        );

    function manuallyPaybackShares(
        uint256 _keyId,
        uint256 _paybackShares
    )
        external;

    function manuallyWithdrawShares(
        uint256 _keyId,
        uint256 _withdrawShares
    )
        external;
}