// SPDX-License-Identifier: -- WISE --

pragma solidity =0.8.21;

import "./PendleWstETHDeclarations.sol";

abstract contract PendleWstETHMathLogic is PendleWstETHDeclarations {

    /**
     * @dev Wrapper for wrapping
     * ETH call.
     */
    function _wrapETH(
        uint256 _value
    )
        internal
    {
        IWETH(WETH_ADDRESS).deposit{
            value: _value
        }();
    }

    /**
     * @dev Wrapper for unwrapping
     * ETH call.
     */
    function _unwrapETH(
        uint256 _value
    )
        internal
    {
        IWETH(WETH_ADDRESS).withdraw(
            _value
        );
    }

    function _sendValue(
        address _recipient,
        uint256 _amount
    )
        internal
    {
        if (address(this).balance < _amount) {
            revert InvalidAction();
        }

        (bool success, ) = payable(_recipient).call{
            value: _amount
        }("");

        if (success == false) {
            revert InvalidAction();
        }
    }

    function _getLiveDebtRatio(
        uint256 _nftId
    )
        internal
        view
        returns (uint256)
    {
        uint256 totalCollateral = getTotalWeightedCollateralUSD(
            _nftId
        );

        if (totalCollateral == 0) {
            return 0;
        }

        return getPositionBorrowUSD(_nftId)
            * PRECISION_FACTOR_E18
            / totalCollateral;
    }

    /**
     * @dev Modfier for updating used pools.
     * (sDAI + USDC/USDT/DAI)
     */
    modifier updatePools() {
        _updatePools();
        _;
    }

    /**
     * @dev Update logic for pools via wise lending
     * interfaces
     */
    function _updatePools()
        private
    {
        WISE_LENDING.preparePool(
            address(HYBRID_TOKEN)
        );

        WISE_LENDING.preparePool(
            AAVE_WETH_ADDRESS
        );
    }

    /**
     * @dev Internal function getting the
     * borrow shares from position {_nftId}
     * with token {_borrowToken}
     */
    function _getPositionBorrowShares(
        uint256 _nftId
    )
        internal
        view
        returns (uint256)
    {
        return WISE_LENDING.getPositionBorrowShares(
            _nftId,
            AAVE_WETH_ADDRESS
        );
    }

    /**
     * @dev Internal function converting
     * borrow shares into tokens.
     */
    function _getPositionBorrowToken(
        uint256 _nftId
    )
        internal
        view
        returns(uint256)
    {
        return WISE_LENDING.paybackAmount(
            AAVE_WETH_ADDRESS,
            _getPositionBorrowShares(
                _nftId
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
            address(HYBRID_TOKEN)
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
                _poolToken: address(HYBRID_TOKEN),
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
        return ORACLE_HUB.getTokensInUSD(
            AAVE_WETH_ADDRESS,
            _getPositionBorrowToken(
                _nftId
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
            address(HYBRID_TOKEN),
            _getPostionCollateralTokenAmount(_nftId)
        )
            * collateralFactor
            / PRECISION_FACTOR_E18;
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
     * @dev Internal function with math logic for approximating
     * the net APY for the postion aftrer creation.
     */
    function _getApproxNetAPY(
        uint256 _initialAmount,
        uint256 _leverage,
        uint256 _pendleAPY
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

        uint256 newBorrowRate = _getNewBorrowRate(
            flashloanAmount
        );

        uint256 leveragedPositivAPY = _pendleAPY
            * _leverage
            / PRECISION_FACTOR_E18;

        uint256 leveragedNegativeAPY = newBorrowRate
            * (_leverage - PRECISION_FACTOR_E18)
            / PRECISION_FACTOR_E18;

        bool isPositiv = leveragedPositivAPY >= leveragedNegativeAPY;

        uint256 netAPY = isPositiv == true
            ? leveragedPositivAPY - leveragedNegativeAPY
            : leveragedNegativeAPY - leveragedPositivAPY;

        return (
            netAPY,
            isPositiv
        );
    }

    /**
     * @dev Internal function with math logic for approximating
     * the new borrow APY.
     */
    function _getNewBorrowRate(
        uint256 _borrowAmount
    )
        internal
        view
        returns (uint256)
    {
        uint256 totalPool = WISE_LENDING.getTotalPool(
            address(HYBRID_TOKEN)
        );

        uint256 pseudoPool = WISE_LENDING.getPseudoTotalPool(
            address(HYBRID_TOKEN)
        );

        if (totalPool > pseudoPool) {
            return 0;
        }

        uint256 newUtilization;

        unchecked {
            newUtilization = PRECISION_FACTOR_E18 - (PRECISION_FACTOR_E18
                * (totalPool - _borrowAmount)
                / pseudoPool
            );
        }

        uint256 pole = WISE_LENDING.borrowRatesData(
            address(HYBRID_TOKEN)
        ).pole;

        uint256 mulFactor = WISE_LENDING.borrowRatesData(
            address(HYBRID_TOKEN)
        ).multiplicativeFactor;

        uint256 baseDivider = pole
            * (pole - newUtilization);

        return mulFactor
            * PRECISION_FACTOR_E18
            * newUtilization
            / baseDivider;
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
     * @dev Internal function checking if the debt
     * ratio threshold fof 100 % is reached when a
     * manually withdraw is performed.
     */
    function _checkBorrowLimit(
        uint256 _nftId,
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
            address(HYBRID_TOKEN),
            _amount
        )
            * collateralFactor
            / PRECISION_FACTOR_E18;

        return getTotalWeightedCollateralUSD(_nftId) - withdrawValue
            > borrowAmount;
    }

    function _unwrapWstETH(
        uint256 _amount,
        uint256 _minOutAmount
    )
        internal
        returns (uint256)
    {
        uint256 stETHAmount = WST_ETH.unwrap(
            _amount
        );

        return _swapStETHintoETH(
            stETHAmount,
            _minOutAmount
        );
    }

    function _swapStETHintoETH(
        uint256 _swapAmount,
        uint256 _minOutAmount
    )
        internal
        returns (uint256)
    {
        return CURVE.exchange(
            {
                fromIndex: 1,
                toIndex: 0,
                exactAmountFrom: _swapAmount,
                minReceiveAmount: _minOutAmount
            }
        );
    }

    function _wrapWstETH(
        uint256 _depositAmount
    )
        internal
        returns (uint256)
    {
        uint256 stETHShares = ST_ETH.submit{
            value: _depositAmount
        }(
            referralAddress
        );

        uint256 stETHAmount = ST_ETH.getPooledEthByShares(
            stETHShares
        );

        uint256 wstETHAmount = WST_ETH.wrap(
            stETHAmount
        );

        return wstETHAmount;
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

        paybackAmount = WISE_LENDING.paybackAmount(
            AAVE_WETH_ADDRESS,
            _shareAmountToPay
        );

        receivingAmount = WISE_LENDING.coreLiquidationIsolationPools(
            _nftId,
            _nftIdLiquidator,
            msg.sender,
            msg.sender,
            AAVE_WETH_ADDRESS,
            address(HYBRID_TOKEN),
            paybackAmount,
            _shareAmountToPay
        );
    }
}
