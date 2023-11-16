// SPDX-License-Identifier: -- WISE --

pragma solidity =0.8.21;

import "./sDaiFarmLeverageLogic.sol";

abstract contract sDaiFarm is sDaiFarmLeverageLogic {

    /**
     * @dev External view function approximating the
     * new resulting net APY for a position setup.
     *
     * Note: Not 100% accurate because no syncPool is performed.
     */
    function getApproxNetAPY(
        uint256 _initialAmount,
        uint256 _leverage,
        uint256 _sDaiAPY,
        address _borrowToken
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
            _sDaiAPY,
            _borrowToken
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
        uint256 _borrowAmount,
        address _borroTokenAdd
    )
        external
        view
        returns (uint256)
    {
        return _getNewBorrowRate(
            _borrowAmount,
            _borroTokenAdd
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

    /* @dev Internal function combining the core
     * logic for {openPosition()}.
     *
     * Note: {_minOutAmount} passed through UI by querring
     * quoteExactInputSingle  with a callStatic
     * from quoterContract [uniswapV3]
     */
    function _openPosition(
        uint256 _nftId,
        uint256 _initialAmount,
        uint256 _leverage,
        uint256 _minOutAmount
    )
        internal
    {
        if (_leverage > MAX_LEVERAGE) {
            revert LeverageTooHigh();
        }

        uint256 index = nftToIndex[
            _nftId
        ];

        uint256 leveragedAmount = getLeverageAmount(
            _initialAmount,
            _leverage
        );

        address borrowToken = borrowTokenAddresses[
            index
        ];

        uint256 flashloanAmount = leveragedAmount
            - _initialAmount;

        if (index != uint256(Token.DAI)) {

            flashloanAmount = _convertIntoOtherStable(
                borrowToken,
                flashloanAmount
            );
        }

        if (_aboveMinDepositAmount(leveragedAmount) == false) {
            revert AmountTooSmall();
        }

        _safeTransferFrom(
            DAI_ADDRESS,
            msg.sender,
            address(this),
            _initialAmount
        );

        _executeBalancerFlashLoan(
            {
                _nftId: _nftId,
                _amount: flashloanAmount,
                _initialAmount: _initialAmount,
                _lendingShares: 0,
                _borrowShares: 0,
                _minMaxAmount: _minOutAmount,
                _flashloanToken: borrowToken
            }
        );
    }

    /**
     * @dev Internal function combining the core
     * logic for {closingPosition()}.
     *
     * Note: {_maxInAmount} passed through UI by querring
     * quoteExactOutputSingle  with a callStatic
     * from quoterContract [uniswapV3]
     */
    function _closingPosition(
        uint256 _nftId,
        uint256 _maxInAmount
    )
        internal
    {
        uint256 index = nftToIndex[
            _nftId
        ];

        address aaveToken = aaveTokenAddresses[
            index
        ];

        uint256 borrowShares = _getPositionBorrowShares(
            _nftId,
            aaveToken
        );

        uint256 lendingShares = _getPositionLendingShares(
            _nftId
        );

        uint256 borrowAmount = WISE_LENDING.paybackAmount(
            aaveToken,
            borrowShares
        );

        _executeBalancerFlashLoan(
            {
                _nftId: _nftId,
                _amount: borrowAmount,
                _initialAmount: 0,
                _lendingShares: lendingShares,
                _borrowShares: borrowShares,
                _minMaxAmount: _maxInAmount,
                _flashloanToken: borrowTokenAddresses[index]
            }
        );
    }

    /**
     * @dev Internal function combining the core
     * logic for {_registrationFarm()}.
     */
    function _registrationFarm(
        uint256 _nftId,
        uint256 _index
    )
        internal
    {
        _checkPositionLocked(
            _nftId
        );

        if (_checkPositionUsed(_nftId) == true) {
            revert PositionNotEmpty();
        }

        if (_index >= borrowTokenAddresses.length) {
            revert OutOfBound();
        }

        WISE_LENDING.setRegistrationIsolationPool(
            _nftId,
            true
        );

        emit RegistrationFarm(
            _nftId,
            _index,
            block.timestamp
        );
    }
}
