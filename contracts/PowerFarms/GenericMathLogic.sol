// SPDX-License-Identifier: -- WISE --

pragma solidity =0.8.24;

import "./GenericDeclarations.sol";

abstract contract GenericMathLogic is GenericDeclarations {

    modifier updatePools() {
        _checkReentrancy();
        _updatePools();
        _;
    }

    /**
     * @dev Update logic for pools via wise lending
     * interfaces
     */
    function _updatePools()
        internal
        virtual
    {
        WISE_LENDING.syncManually(
            FARM_ASSET
        );

        WISE_LENDING.syncManually(
            POOL_ASSET_AAVE
        );

        WISE_LENDING.syncManually(
            PENDLE_CHILD
        );
    }

    function _checkReentrancy()
        internal
        virtual
        view
    {
        if (sendingProgress == true) {
            revert GenericAccessDenied();
        }

        if (WISE_LENDING.sendingProgress() == true) {
            revert GenericAccessDenied();
        }

        if (AAVE_HUB.sendingProgressAaveHub() == true) {
            revert GenericAccessDenied();
        }
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
        virtual
        view
        returns (uint256)
    {
        return WISE_LENDING.getPositionBorrowShares(
            _nftId,
            FARM_ASSET
        );
    }

    /**
     * @dev Internal function getting the
     * borrow shares of aave from position {_nftId}
     * with token {_borrowToken}
     */
    function _getPositionBorrowSharesAave(
        uint256 _nftId
    )
        internal
        virtual
        view
        returns (uint256)
    {
        return WISE_LENDING.getPositionBorrowShares(
            _nftId,
            POOL_ASSET_AAVE
        );
    }

    /**
     * @dev Internal function converting
     * borrow shares into tokens.
     */
    function _getPositionBorrowTokenAmount(
        uint256 _nftId
    )
        internal
        virtual
        view
        returns (uint256 tokenAmount)
    {
        uint256 positionBorrowShares = _getPositionBorrowShares(
            _nftId
        );

        if (positionBorrowShares > 0) {
            tokenAmount = WISE_LENDING.paybackAmount(
                FARM_ASSET,
                positionBorrowShares
            );
        }
    }

    function _getPositionBorrowTokenAmountAave(
        uint256 _nftId
    )
        internal
        virtual
        view
        returns (uint256 tokenAmountAave)
    {
        uint256 positionBorrowSharesAave = _getPositionBorrowSharesAave(
            _nftId
        );

        if (positionBorrowSharesAave == 0) {
            return 0;
        }

        tokenAmountAave = WISE_LENDING.paybackAmount(
            POOL_ASSET_AAVE,
            positionBorrowSharesAave
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
        virtual
        view
        returns (uint256)
    {
        return WISE_LENDING.getPositionLendingShares(
            _nftId,
            PENDLE_CHILD
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
        virtual
        view
        returns (uint256)
    {
        return WISE_LENDING.cashoutAmount(
            {
                _poolToken: PENDLE_CHILD,
                _shares: _getPositionLendingShares(
                    _nftId
                )
            }
        );
    }

    /**
     * @dev Read function returning the total
     * borrow amount in ETH from postion {_nftId}
     */
    function getPositionBorrowETH(
        uint256 _nftId
    )
        public
        virtual
        view
        returns (uint256)
    {
        uint256 borrowTokenAmount;
        uint256 borrowShares = _getPositionBorrowShares(
            _nftId
        );

        if (borrowShares > 0) {
            borrowTokenAmount = _getPositionBorrowTokenAmount(
                _nftId
            );
        }

        uint256 borrowSharesAave = _getPositionBorrowSharesAave(
            _nftId
        );

        uint256 borrowTokenAmountAave;

        if (borrowSharesAave > 0) {
            borrowTokenAmountAave = _getPositionBorrowTokenAmountAave(
                _nftId
            );
        }

        uint256 tokenValueEth;

        if (borrowShares > 0) {
            tokenValueEth = _getTokensInETH(
                FARM_ASSET,
                borrowTokenAmount
            );
        }

        if (borrowTokenAmountAave == 0) {
            return tokenValueEth;
        }

        uint256 tokenValueAaveEth = _getTokensInETH(
            POOL_ASSET_AAVE,
            borrowTokenAmountAave
        );

        return tokenValueEth + tokenValueAaveEth;
    }

    /**
     * @dev Read function returning the total
     * lending amount in ETH from postion {_nftId}
     */
    function getTotalWeightedCollateralETH(
        uint256 _nftId
    )
        public
        virtual
        view
        returns (uint256)
    {
        return _getTokensInETH(
            PENDLE_CHILD,
            _getPostionCollateralTokenAmount(_nftId)
        )
            * collateralFactor
            / PRECISION_FACTOR_E18;
    }

    function _getTokensInETH(
        address _tokenAddress,
        uint256 _tokenAmount
    )
        internal
        virtual
        view
        returns (uint256)
    {
        return ORACLE_HUB.getTokensInETH(
            _tokenAddress,
            _tokenAmount
        );
    }

    function _getEthInTokens(
        address _tokenAddress,
        uint256 _ethAmount
    )
        internal
        virtual
        view
        returns (uint256)
    {
        return ORACLE_HUB.getTokensFromETH(
            _tokenAddress,
            _ethAmount
        );
    }

    function getLeverageAmount(
        uint256 _initialAmount,
        uint256 _leverage
    )
        public
        pure
        virtual
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
        uint256 _wstETHAPY
    )
        internal
        virtual
        view
        returns (
            uint256,
            bool
        )
    {
        if (_leverage < PRECISION_FACTOR_E18) {
            return (
                0,
                false
            );
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

        uint256 leveragedPositivAPY = _wstETHAPY
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

    function _isOutOfRangeAmount(
        uint256 _lpWithdrawAmount
    )
        internal
        virtual
        view
        returns (bool)
    {
        MarketState memory marketState = PENDLE_MARKET.readState(
            address(PENDLE_MARKET)
        );

        (
            ,
            uint256 userSy,
            uint256 userPt
        )
            = _getUserAssetInfo(
                _lpWithdrawAmount,
                uint256(marketState.totalLp),
                uint256(marketState.totalSy),
                uint256(marketState.totalPt)
        );

        uint256 reducedSy = uint256(marketState.totalSy)
            - userSy
            - (
                PT_ORACLE_PENDLE.getPtToSyRate(
                    address(PENDLE_MARKET),
                    1 seconds
                )
                * userPt
                / PRECISION_FACTOR_E18
        );

        uint256 totalAssetsReduced = (
            PENDLE_SY.exchangeRate()
                * reducedSy
                / PRECISION_FACTOR_E18
            + uint256(marketState.totalPt)
        );

        return uint256(marketState.totalPt)
            * PRECISION_FACTOR_E18
            / totalAssetsReduced
            > MAX_PROPORTION;
    }

    /**
     * @dev Internal function with math logic for detecting
     * if market is out of range.
     */
    function _isOutOfRange(
        uint256 _nftId
    )
        internal
        virtual
        view
        returns (bool)
    {
        return _isOutOfRangeAmount(
            IPendleChild(PENDLE_CHILD).previewAmountWithdrawShares(
                WISE_LENDING.cashoutAmount(
                    PENDLE_CHILD,
                    WISE_LENDING.getPositionLendingShares(
                        _nftId,
                        PENDLE_CHILD
                    )
                ),
                IPendleChild(PENDLE_CHILD).underlyingLpAssetsCurrent()
            )
        );
    }

    function _getUserAssetInfo(
        uint256 _lpToWithdraw,
        uint256 _totalLp,
        uint256 _totalSy,
        uint256 _totalPt
    )
        internal
        virtual
        view
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        uint256 userProportion = _lpToWithdraw
            * PRECISION_FACTOR_E18
            / _totalLp;

        return (
            userProportion,
            userProportion
                * _totalSy
                / PRECISION_FACTOR_E18,
            userProportion
                * _totalPt
                / PRECISION_FACTOR_E18
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
        virtual
        view
        returns (uint256)
    {
        uint256 totalPool = WISE_LENDING.getTotalPool(
            ENTRY_ASSET
        );

        uint256 pseudoPool = WISE_LENDING.getPseudoTotalPool(
            ENTRY_ASSET
        );

        if (totalPool > pseudoPool) {
            return 0;
        }

        uint256 newUtilization = PRECISION_FACTOR_E18 - (PRECISION_FACTOR_E18
            * (totalPool - _borrowAmount)
            / pseudoPool
        );

        uint256 pole = WISE_LENDING.borrowRatesData(
            ENTRY_ASSET
        ).pole;

        uint256 mulFactor = WISE_LENDING.borrowRatesData(
            ENTRY_ASSET
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
        virtual
        view
        returns (bool)
    {
        uint256 borrowShares = isAave[_nftId]
            ? _getPositionBorrowSharesAave(
                _nftId
            )
            : _getPositionBorrowShares(
                _nftId
            );

        if (borrowShares == 0) {
            return true;
        }

        return getTotalWeightedCollateralETH(_nftId)
            >= getPositionBorrowETH(_nftId);
    }

    /**
     * @dev Internal function checking if the leveraged
     * amount not below {minDepositEthAmount} in value.
     */
    function _notBelowMinDepositAmount(
        uint256 _amount
    )
        internal
        virtual
        view
        returns (bool)
    {
        uint256 equivETH = _getTokensInETH(
            ENTRY_ASSET,
            _amount
        );

        return equivETH >= minDepositEthAmount;
    }
}
