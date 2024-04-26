// SPDX-License-Identifier: -- WISE --

pragma solidity =0.8.24;

import "./GenericLeverageLogic.sol";

error BadDebt(uint256 amount);

abstract contract GenericPowerFarm is GenericLeverageLogic {

    /**
     * @dev External view function approximating the
     * new resulting net APY for a position setup.
     *
     * Note: Not 100% accurate because no syncPool is performed.
     */
    function getApproxNetAPY(
        uint256 _initialAmount,
        uint256 _leverage,
        uint256 _pendleChildApy
    )
        external
        virtual
        view
        returns (
            uint256,
            bool
        )
    {
        return _getApproxNetAPY(
            _initialAmount,
            _leverage,
            _pendleChildApy
        );
    }

    function getTokenAmountEquivalentInFarmAsset(
        uint256 _nftId
    )
        public
        virtual
        view
        returns (uint256)
    {
        uint256 collateralValueInEth = _getTokensInETH(
            PENDLE_CHILD,
            _getPostionCollateralTokenAmount(
                _nftId
            )
        );

        uint256 borrowValueInEth = getPositionBorrowETH(
            _nftId
        );

        if (collateralValueInEth < borrowValueInEth) {
            revert BadDebt(borrowValueInEth - collateralValueInEth);
        }

        return _getEthInTokens(
            FARM_ASSET,
            collateralValueInEth - borrowValueInEth
        );
    }

    /**
     * @dev External view function approximating the
     * new borrow amount for the pool when {_borrowAmount}
     * is borrowed.
     *
     * Note: Not 100% accurate because no syncPool is performed.
     */
    function getNewBorrowRate(
        uint256 _borrowAmount
    )
        external
        virtual
        view
        returns (uint256)
    {
        return _getNewBorrowRate(
            _borrowAmount
        );
    }

    function isOutOfRange(
        uint256 _nftId
    )
        external
        virtual
        view
        returns (bool)
    {
        return _isOutOfRange(
            _nftId
        );
    }

    function isOutOfRangeAmount(
        uint256 _lpAmount
    )
        external
        virtual
        view
        returns (bool)
    {
        return _isOutOfRangeAmount(
            _lpAmount
        );
    }

    /**
     * @dev View functions returning the current
     * debt ratio of the postion with {_nftId}
     */
    function getLiveDebtRatio(
        uint256 _nftId
    )
        external
        virtual
        view
        returns (uint256)
    {
        uint256 borrowShares = isAave[_nftId]
            ? _getPositionBorrowSharesAave(
                _nftId
            )
            : _getPositionBorrowShares(
                _nftId
            );

        if (borrowShares == 0) {
            return 0;
        }

        uint256 totalCollateral = getTotalWeightedCollateralETH(
            _nftId
        );

        if (totalCollateral == 0) {
            return 0;
        }

        return getPositionBorrowETH(_nftId)
            * PRECISION_FACTOR_E18
            / totalCollateral;
    }

    function setCollateralFactor(
        uint256 _newCollateralFactor
    )
        external
        virtual
    {}

    /**
     * @dev Liquidation function for open power farm
     * postions which have a debtratio greater than 100%.
     */
    function liquidatePartiallyFromToken(
        uint256 _nftId,
        uint256 _nftIdLiquidator,
        uint256 _shareAmountToPay
    )
        external
        virtual
        updatePools
        returns (
            uint256 paybackAmount,
            uint256 receivingAmount
        )
    {
        return _coreLiquidation(
            _nftId,
            _nftIdLiquidator,
            _shareAmountToPay
        );
    }

    /**
     * @dev Manually payback function for users. Takes
     * {_paybackShares} which can be converted
     * into token with {paybackAmount()} or vice verse
     * with {calculateBorrowShares()} from wise lending
     * contract.
     */
    function _manuallyPaybackShares(
        uint256 _nftId,
        uint256 _paybackShares
    )
        internal
        virtual
    {
        address poolAddress = FARM_ASSET;

        if (isAave[_nftId] == true) {
            poolAddress = POOL_ASSET_AAVE;
        }

        uint256 paybackAmount = WISE_LENDING.paybackAmount(
            poolAddress,
            _paybackShares
        );

        _safeTransferFrom(
            poolAddress,
            msg.sender,
            address(this),
            paybackAmount
        );

        WISE_LENDING.paybackExactShares(
            _nftId,
            poolAddress,
            _paybackShares
        );
    }

    /**
     * @dev Manually withdraw function for users. Takes
     * {_withdrawShares} which can be converted
     * into token with {cashoutAmount()} or vice verse
     * with {calculateLendingShares()} from wise lending
     * contract.
     */
    function _manuallyWithdrawShares(
        uint256 _nftId,
        uint256 _withdrawShares
    )
        internal
        virtual
    {
        uint256 withdrawAmount = WISE_LENDING.cashoutAmount(
            PENDLE_CHILD,
            _withdrawShares
        );

        withdrawAmount = WISE_LENDING.withdrawExactShares(
            _nftId,
            PENDLE_CHILD,
            _withdrawShares
        );

        _safeTransfer(
            PENDLE_CHILD,
            msg.sender,
            withdrawAmount
        );
    }

    /**
     * @dev Internal function combining the core
     * logic for {openPosition()}.
     */
    function _openPosition(
        bool _isAave,
        uint256 _nftId,
        uint256 _initialAmount,
        uint256 _leverage,
        uint256 _allowedSpread
    )
        internal
        virtual
    {
        if (_leverage > MAX_LEVERAGE) {
            revert GenericLevergeTooHigh();
        }

        uint256 leveragedAmount = getLeverageAmount(
            _initialAmount,
            _leverage
        );

        if (_notBelowMinDepositAmount(leveragedAmount) == false) {
            revert GenericAmountTooSmall();
        }

        _executeBalancerFlashLoan(
            {
                _nftId: _nftId,
                _flashAmount: leveragedAmount - _initialAmount,
                _initialAmount: _initialAmount,
                _lendingShares: 0,
                _borrowShares: 0,
                _allowedSpread: _allowedSpread,
                _ethBack: ethBack,
                _isAave: _isAave
            }
        );
    }

    /**
     * @dev Internal function combining the core
     * logic for {closingPosition()}.
     *
     * Note: {_allowedSpread} passed through UI by asking user
     * the percentage of acceptable value loss by closing position.
     * Units are in ether where 100% = 1 ether -> 0% loss acceptable
     * 1.01 ether -> 1% loss acceptable and so on.
     */
    function _closingPosition(
        bool _isAave,
        uint256 _nftId,
        uint256 _allowedSpread,
        bool _ethBack
    )
        internal
        virtual
    {
        uint256 borrowShares = _isAave == false
            ? _getPositionBorrowShares(
                _nftId
            )
            : _getPositionBorrowSharesAave(
                _nftId
            );

        uint256 borrowTokenAmount = _isAave == false
            ? _getPositionBorrowTokenAmount(
                _nftId
            )
            : _getPositionBorrowTokenAmountAave(
                _nftId
            );

        _executeBalancerFlashLoan(
            {
                _nftId: _nftId,
                _flashAmount: borrowTokenAmount,
                _initialAmount: 0,
                _lendingShares: _getPositionLendingShares(
                    _nftId
                ),
                _borrowShares: borrowShares,
                _allowedSpread: _allowedSpread,
                _ethBack: _ethBack,
                _isAave: _isAave
            }
        );
    }

    function _registrationFarm(
        uint256 _nftId
    )
        internal
        virtual
    {
        WISE_LENDING.setRegistrationIsolationPool(
            _nftId,
            true
        );


        emit RegistrationFarm(
            _nftId,
            block.timestamp
        );
    }
}
