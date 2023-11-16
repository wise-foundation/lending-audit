// SPDX-License-Identifier: -- WISE --

pragma solidity =0.8.21;

import "./sDaiFarmDeclarations.sol";

abstract contract sDaiFarmMathLogic is sDaiFarmDeclarations {

    /**
     * @dev Update logic for pools via wise lending
     * (sDAI + USDC / USDT / DAI)
     */
    function _updatePools(
        address _poolToken
    )
        internal
    {
        WISE_LENDING.preparePool(
            _poolToken
        );

        WISE_LENDING.preparePool(
            SDAI_ADDRESS
        );
    }

    /**
     * @dev Internal function checking if {_nftId}
     * is locked from a power farm.
     */
    function _checkPositionLocked(
        uint256 _nftId
    )
        internal
        view
    {
        WISE_LENDING.checkPositionLocked(
            _nftId,
            msg.sender
        );
    }

    /**
     * @dev Internal function getting the
     * borrow shares from position {_nftId}
     * with token {_borrowToken}
     */
    function _getPositionBorrowShares(
        uint256 _nftId,
        address _borrowToken
    )
        internal
        view
        returns (uint256)
    {
        return WISE_LENDING.getPositionBorrowShares(
            _nftId,
            _borrowToken
        );
    }

    /**
     * @dev Internal function converting
     * borrow shares into tokens.
     */
    function _getBorrowAmount(
        uint256 _nftId,
        address _borrowToken
    )
        internal
        view
        returns(uint256)
    {
        return WISE_LENDING.paybackAmount(
            _borrowToken,
            _getPositionBorrowShares(
                _nftId,
                _borrowToken
            )
        );
    }

    /**
     * @dev Internal function getting the
     * lending shares from position {_nftId}
     * with token {_borrowToken}
     */
    function _getPositionLendingShares(
        uint256 _nftId
    )
        internal
        view
        returns (uint256)
    {
        return WISE_LENDING.getPositionLendingShares(
            _nftId,
            SDAI_ADDRESS
        );
    }

    /**
     * @dev Internal function converting
     * lending shares into tokens.
     */
    function _getPostionCollateralTokenAmount(
        uint256 _nftId
    )
        internal
        view
        returns(uint256)
    {
        return WISE_LENDING.cashoutAmount(
            {
                _poolToken: SDAI_ADDRESS,
                _shares: _getPositionLendingShares(
                    _nftId
                )
                // _maxAmount: false
            }
        );
    }

    /**
     * @dev Read function returning the total
     * borrow amount in USD from postion {_nftId}
     */
    function getPositionBorrowUSD(
        uint256 _nftId
    )
        public
        view
        returns (uint256)
    {
        address borrowToken = aaveTokenAddresses[
            nftToIndex[_nftId]
        ];

        return ORACLE_HUB.getTokensInUSD(
            borrowToken,
            _getBorrowAmount(
                _nftId,
                borrowToken
            )
        );
    }

    /**
     * @dev Read function returning the total
     * lending amount in USD from postion {_nftId}
     */
    function getTotalWeightedCollateralUSD(
        uint256 _nftId
    )
        public
        view
        returns (uint256)
    {
        return ORACLE_HUB.getTokensInUSD(
            SDAI_ADDRESS,
            _getPostionCollateralTokenAmount(_nftId)
        )
            * collateralFactor
            / PRECISION_FACTOR_E18;
    }

    /**
     * @dev Internal function summarizing liquidation
     * checks and interface call for core liquidation from
     * wise lending.
     */
    function _coreLiquidation(
        uint256 _nftId,
        uint256 _nftIdLiquidator,
        uint256 _shareAmountToPay
    )
        internal
        returns (
            uint256 paybackAmount,
            uint256 receivingAmount
        )
    {
        if (_checkDebtRatio(_nftId) == true) {
            revert DebtRatioTooHigh();
        }

        address paybackTokenAddress = aaveTokenAddresses[
            nftToIndex[_nftId]
        ];

        paybackAmount = WISE_LENDING.paybackAmount(
            paybackTokenAddress,
            _shareAmountToPay
        );

        receivingAmount = WISE_LENDING.coreLiquidationIsolationPools(
            _nftId,
            _nftIdLiquidator,
            msg.sender,
            msg.sender,
            paybackTokenAddress,
            SDAI_ADDRESS,
            paybackAmount,
            _shareAmountToPay
        );
    }

    /**
     * @dev Internal function checking if the leveraged
     * amount is above 5000 USD in value.
     */
    function _aboveMinDepositAmount(
        uint256 _amount
    )
        internal
        view
        returns (bool)
    {
        uint256 equivUSD = ORACLE_HUB.getTokensInUSD(
            DAI_ADDRESS,
            _amount
        );

        return equivUSD >= MIN_DEPOSIT_USD_AMOUNT;
    }

    /**
     * @dev Internal function checking if a position
     * with {_nftId} has a debt ratio under 100%.
     */
    function _checkDebtRatio(
        uint256 _nftId
    )
        internal
        view
        returns (bool res)
    {
        res = getTotalWeightedCollateralUSD(_nftId)
            > getPositionBorrowUSD(_nftId);
    }

    /**
     * @dev Internal function checking if a position
     * with {_nftId} is still used to lock it for
     * unregister function.
     */
    function _checkPositionUsed(
        uint256 _nftId
    )
        internal
        view
        returns (bool)
    {
        return WISE_SECURITY.overallUSDCollateralsBare(_nftId) > 0;
    }

    /**
     * @dev Internal function checking if a position
     * with {_nftId} is still used to lock it for
     * unregister function.
     */
    function getLeverageAmount(
        uint256 _initialAmount,
        uint256 _leverage
    )
        public
        pure
        returns (uint256)
    {
        return _initialAmount
            * _leverage
            / PRECISION_FACTOR_E18;
    }

    /**
     * @dev Internal math function converting the
     * calculated flashloan amount (in DAI) into a
     * token amount of another stable (USDC or USDT).
     */
    function _convertIntoOtherStable(
        address _borrowToken,
        uint256 _amount
    )
        internal
        view
        returns (uint256)
    {
        return ORACLE_HUB.getTokensFromUSD(
            _borrowToken,
            ORACLE_HUB.getTokensInUSD(
                DAI_ADDRESS,
                _amount
            )
        );
    }

    /**
     * @dev Internal function checking if the debt
     * ratio threshold fof 100 % is reached when a
     * manually withdraw is performed.
     */
    function _checkBorrowLimit(
        uint256 _nftId,
        address _poolToken,
        uint256 _amount
    )
        internal
        view
        returns (bool)
    {
        uint256 borrowAmount = getPositionBorrowUSD(
            _nftId
        );

        if (borrowAmount == 0) {
            return true;
        }

        uint256 withdrawValue = ORACLE_HUB.getTokensInUSD(
            _poolToken,
            _amount
        )
            * collateralFactor
            / PRECISION_FACTOR_E18;

        return getTotalWeightedCollateralUSD(_nftId) - withdrawValue
            > borrowAmount;
    }

    /**
     * @dev Internal function with math logic for approximating
     * the net APY for the postion aftrer creation.
     */
    function _getApproxNetAPY(
        uint256 _initialAmount,
        uint256 _leverage,
        uint256 _sDaiAPY,
        address _borrowToken
    )
        internal
        view
        returns (
            uint256,
            bool
        )
    {
        if (_leverage < PRECISION_FACTOR_E18) {
            return (0, false);
        }

        uint256 leveragedAmount = getLeverageAmount(
            _initialAmount,
            _leverage
        );

        uint256 flashloanAmount = leveragedAmount
            - _initialAmount;

        if (_borrowToken != DAI_ADDRESS) {
            flashloanAmount = _convertIntoOtherStable(
                _borrowToken,
                flashloanAmount
            );
        }

        uint256 newBorrowRate = _getNewBorrowRate(
            flashloanAmount,
            _borrowToken
        );

        uint256 leveragedPositivAPY = _sDaiAPY
            * _leverage
            / PRECISION_FACTOR_E18;

        uint256 leveragedNegativeAPY = newBorrowRate
            * (_leverage - PRECISION_FACTOR_E18)
            / PRECISION_FACTOR_E18;

        bool isPositive = leveragedPositivAPY >= leveragedNegativeAPY;

        uint256 netAPY = isPositive == true
            ? leveragedPositivAPY - leveragedNegativeAPY
            : leveragedNegativeAPY - leveragedPositivAPY;

        return (
            netAPY,
            isPositive
        );
    }

    /**
     * @dev Internal function with math logic for approximating
     * the new borrow APY.
     */
    function _getNewBorrowRate(
        uint256 _borrowAmount,
        address _borroTokenAdd
    )
        internal
        view
        returns (uint256)
    {
        uint256 totalPool = WISE_LENDING.getTotalPool(
            _borroTokenAdd
        );

        uint256 pseudoPool = WISE_LENDING.getPseudoTotalPool(
            _borroTokenAdd
        );

        if (totalPool > pseudoPool) {
            return 0;
        }

        uint256 newUtilization = PRECISION_FACTOR_E18 - (PRECISION_FACTOR_E18
            * (totalPool - _borrowAmount)
            / pseudoPool
        );

        uint256 pole = WISE_LENDING.borrowRatesData(
            _borroTokenAdd
        ).pole;

        uint256 mulFactor = WISE_LENDING.borrowRatesData(
            _borroTokenAdd
        ).multiplicativeFactor;

        uint256 baseDivider = pole
            * (pole - newUtilization);

        return mulFactor
            * PRECISION_FACTOR_E18
            * newUtilization
            / baseDivider;
    }
}