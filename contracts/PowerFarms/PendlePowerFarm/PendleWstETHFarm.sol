// SPDX-License-Identifier: -- WISE --

pragma solidity =0.8.21;

import "./PendleWstETHLeverageLogic.sol";

abstract contract PendleWstETHFarm is PendleWstETHLeverageLogic {

    /**
     * @dev External view function approximating the
     * new resulting net APY for a position setup.
     *
     * Note: Not 100% accurate because no syncPool is performed.
     */
    function getApproxNetAPY(
        uint256 _initialAmount,
        uint256 _leverage,
        uint256 _pendleAPY
    )
        external
        view
        returns (
            uint256,
            bool
        )
    {
        return _getApproxNetAPY(
            _initialAmount,
            _leverage,
            _pendleAPY
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
        view
        returns (uint256)
    {
        return _getNewBorrowRate(
            _borrowAmount
        );
    }

    /**
     * @dev View functions returning the current
     * debt ratio of the postion with {_nftId}
     */
    /*
    function getLiveDebtRatio(
        uint256 _nftId
    )
        external
        view
        returns (uint256)
    {
        return _getLiveDebtRatio(
            _nftId
        );
    }
    */

    /**
     * @dev Liquidation function for open power farm
     * postions which have a debtratio greater 100 %.
     *
     * NOTE: The borrow token is defined by the power farm
     * and is always aave wrapped ETH.
     * The receiving token is always .....
     */
    function liquidatePartially(
        uint256 _nftId,
        uint256 _nftIdLiquidator,
        uint256 _shareAmountToPay
    )
        external
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
    /*
    function _manuallyPaybackShares(
        uint256 _nftId,
        uint256 _paybackShares
    )
        internal
    {
        uint256 paybackAmount = WISE_LENDING.paybackAmount(
            AAVE_WETH_ADDRESS,
            _paybackShares
        );

        _safeTransferFrom(
            AAVE_WETH_ADDRESS,
            msg.sender,
            address(this),
            paybackAmount
        );

        WISE_LENDING.paybackExactShares(
            _nftId,
            AAVE_WETH_ADDRESS,
            _paybackShares
        );
    }
    */

    /**
     * @dev Manually withdraw function for users. Takes
     * {_withdrawShares} which can be converted
     * into token with {cashoutAmount()} or vice verse
     * with {calculateLendingShares()} from wise lending
     * contract.
     */
    /*
    function _manuallyWithdrawShares(
        uint256 _nftId,
        uint256 _withdrawShares
    )
        internal
    {
        uint256 withdrawAmount = WISE_LENDING.cashoutAmount(
            {
                _poolToken: AAVE_WETH_ADDRESS,
                _shares: _withdrawShares,
                _maxAmount: false
            }
        );

        if (_checkBorrowLimit(_nftId, withdrawAmount) == false) {
            revert ResultsInBadDebt();
        }

        withdrawAmount = WISE_LENDING.withdrawOnBehalfExactShares(
            _nftId,
            address(HYBRID_TOKEN),
            _withdrawShares
        );

        _safeTransfer(
            address(HYBRID_TOKEN),
            msg.sender,
            withdrawAmount
        );
    }
    */

    /**
     * @dev Internal function combining the core
     * logic for {openPosition()}.
     */
    function _openPosition(
        uint256 _nftId,
        uint256 _initialAmount,
        uint256 _leverage,
        uint256 _overhangFetched,
        bool _ptGreaterFetched,
        bytes calldata _swapDataFetched
    )
        internal
    {
        if (_leverage > MAX_LEVERAGE) {
            revert LeverageTooHigh();
        }

        uint256 leveragedAmount = getLeverageAmount(
            _initialAmount,
            _leverage
        );

        uint256 flashloanAmount = leveragedAmount
            - _initialAmount;

        uint256 equivUSD = ORACLE_HUB.getTokensInUSD(
            WETH_ADDRESS,
            leveragedAmount
        );

        if (equivUSD >= MIN_DEPOSIT_USD_AMOUNT == false) {
            revert AmountTooSmall();
        }

        _executeBalancerFlashLoan(
            {
                _nftId: _nftId,
                _amount: flashloanAmount,
                _initialAmount: _initialAmount,
                _lendingShares: 0,
                _borrowShares: 0,
                _minAmountOut: 0,
                _overhangFetched: _overhangFetched,
                _ptGreaterFetched: _ptGreaterFetched,
                _ethBack: false,
                _swapDataFetched: _swapDataFetched
            }
        );
    }

    /**
     * @dev Internal function combining the core
     * logic for {closingPosition()}.
     *
     * Note: {_minOutAmount} passed through UI by querring
     * {get_dy()} from curve pool contract.
     */
    function _closingPosition(
        uint256 _nftId,
        uint256 _minOutAmount,
        bool _ethBack,
        uint256 _overhangFetched,
        bool _ptGreaterFetched,
        bytes memory _swapDataFetched
    )
        redeemPt
        internal
    {
        // FarmState memory farmStateCache = farmState;

        NftInfo memory nftInfo = NftInfo({
            borrowShares: _getPositionBorrowShares(
                _nftId
            ),
            lendingShares: _getPositionLendingShares(
                _nftId
            ),
            borrowAmount: _getPositionBorrowToken(
                _nftId
            )
        });

        _executeBalancerFlashLoan(
            {
                _nftId: _nftId,
                _amount: nftInfo.borrowAmount,
                _initialAmount: 0,
                _lendingShares: nftInfo.lendingShares,
                _borrowShares: nftInfo.borrowShares,
                _minAmountOut: _minOutAmount,
                _overhangFetched: _overhangFetched,
                _ptGreaterFetched: _ptGreaterFetched,
                _ethBack: _ethBack,
                _swapDataFetched: _swapDataFetched
            }
        );
    }

    /**
     * @dev Internal function combining the core
     * logic for {_registrationFarm()}.
     */
    function _registrationFarm(
        uint256 _nftId
    )
        internal
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
