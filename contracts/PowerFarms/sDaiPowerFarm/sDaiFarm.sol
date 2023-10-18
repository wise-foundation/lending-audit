// SPDX-License-Identifier: -- WISE --

pragma solidity =0.8.21;

/**
 * @author Christoph Krpoun
 * @author René Hochmuth
 * @author Vitally Marinchenko
 */

import "./sDaiFarmLeverageLogic.sol";

/**
 * @dev The sDai power farm is an automated leverage contract working as a
 * second layer for Wise lending. It needs to be registed inside the latter one
 * to have access to the pools. It uses BALANCER FLASHLOANS as well as UNISWAPV3,
 * the sDAI contract and the DSS-PSM contract for fee-less exchanging of USDC <-> DAI.
 * The corresponding contract addresses can be found in {sDaiFarmDeclarations.sol}.
 *
 * It allows to open leverage positions with different stable borrow tokens, namely
 * USDC, USDT and DAI. For opening a position the user needs to have {_initalAmount}
 * of DAI in the wallet. A maximum of 15x leverage is possible. Once the user
 * registers with its position NFT that NFT is locked for ALL other interactions with
 * wise lending as long as the positon is open!
 *
 * For more infos see {https://wisesoft.gitbook.io/wise/}
 */

contract SDaiFarm is SDaiFarmLeverageLogic {

    constructor(
        address _wiseLendingAddress,
        uint256 _collateralFactor
    )
        SDaiFarmDeclarations(
            _wiseLendingAddress,
            _collateralFactor
        )
    {}

    /**
     * @dev External function deactivating the power farm by
     * disableing the openPosition function. Allowing user
     * to manualy payback and withdraw.
     */
    function shutdownFarm(
        bool _state
    )
        external
        onlyMaster
    {
        isShutdown = _state;
    }

    /**
     * @dev Function to register for sDAI power farms.
     * Needs to be called before open a postion. User
     * can choose used borrow token with {_index}:
     * 0 : DAI
     * 1 : USDC
     * 2 : USDT
     */
    function registrationFarm(
        uint256 _nftId,
        uint256 _index
    )
        external
        checkActivated
        checkOwner(_nftId)
    {
        _registrationFarm(
            _nftId,
            _index
        );
    }

    /**
     * @dev Function to unregister from sDAI power
     * farms to enable the {_nftId} for all other
     * wise lending functions again.
     */
    function unregistrationFarm(
        uint256 _nftId
    )
        external
        checkOwner(_nftId)
    {
        _unregistrationFarm(
            _nftId
        );
    }

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
        uint256 totalCollateral = getTotalWeightedCollateralUSD(_nftId);

        if (totalCollateral == 0) {
            return 0;
        }

        return getPositionBorrowUSD(_nftId)
            * PRECISION_FACTOR_E18
            / totalCollateral;
    }

    /**
     * @dev Function to open a leveraged position. User
     * must be the owner of the used position with {_nftId}.
     * A maximum leverage of 15 (in orders of 1E18) is allowed.
     * The inital amount of DAI defines the position amount by the
     * formula {_initialAmount * _leverage} and needs to
     * have a correspoding USD value of at least 5000 USD.
     * {_minOutAmount} needs to be passed from the UI when USDT
     * is used as borrow token. (querring quoteExactInputSingle
     * with a callStatic from quoterContract [uniswapV3])
     */
    function openPosition(
        uint256 _nftId,
        uint256 _initialAmount,
        uint256 _leverage,
        uint256 _minOutAmount
    )
        external
        checkActivated
        checkOwner(_nftId)
        updatePools(_nftId)
    {
        _openPosition(
            _nftId,
            _initialAmount,
            _leverage,
            _minOutAmount
        );
    }

    /**
     * @dev Wrapper function combining registration
     * and opening of a postion.
     */
    function openPositionRegister(
        uint256 _nftId,
        uint256 _index,
        uint256 _initialAmount,
        uint256 _leverage,
        uint256 _minOutAmount
    )
        external
        checkActivated
        checkOwner(_nftId)
        updatePools(_nftId)
    {
        _registrationFarm(
            _nftId,
            _index
        );

        _openPosition(
            _nftId,
            _initialAmount,
            _leverage,
            _minOutAmount
        );
    }

    /**
     * @dev Function to close a leveraged position. User
     * must be the owner of the used position with {_nftId}.
     * The return token is DAI and gets directly transferd in
     * the owners wallet after closing.
     * {_maxInAmount} needs to be passed from the UI when USDT
     * is used as borrow token. (querring quoteExactOutputSingle
     * with a callStatic from quoterContract [uniswapV3])
     */
    function closingPosition(
        uint256 _nftId,
        uint256 _maxInAmount
    )
        external
        checkOwner(_nftId)
        updatePools(_nftId)
    {
        _closingPosition(
            _nftId,
            _maxInAmount
        );
    }

    /**
     * @dev Wrapper function combining unregistration
     * and closing of a postion.
     */
    function closePositionUnregsiter(
        uint256 _nftId,
        uint256 _maxInAmount
    )
        external
        checkOwner(_nftId)
        updatePools(_nftId)
    {
        _closingPosition(
            _nftId,
            _maxInAmount
        );

        _unregistrationFarm(
            _nftId
        );
    }

    /**
     * @dev Manually payback function for users. Takes
     * {_paybackShares} which can be converted
     * into token with {paybackAmount()} or vice verse
     * with {calculateBorrowShares()} from wise lending
     * contract.
     */
    function manuallyPaybackShares(
        uint256 _nftId,
        uint256 _paybackShares
    )
        external
        updatePools(_nftId)
    {
        address paybackTokenAddress = aaveTokenAddresses[
            nftToIndex[_nftId]
        ];

        uint256 paybackAmount = WISE_LENDING.paybackAmount(
            paybackTokenAddress,
            _paybackShares
        );

        _safeTransferFrom(
            paybackTokenAddress,
            msg.sender,
            address(this),
            paybackAmount
        );

        WISE_LENDING.paybackExactShares(
            _nftId,
            paybackTokenAddress,
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
    function manuallyWithdrawShares(
        uint256 _nftId,
        uint256 _withdrawShares
    )
        external
        updatePools(_nftId)
    {
        uint256 withdrawAmount = WISE_LENDING.cashoutAmount(
            SDAI_ADDRESS,
            _withdrawShares
        );

        if (_checkBorrowLimit(_nftId, SDAI_ADDRESS, withdrawAmount) == false) {
            revert ResultsInBadDebt();
        }

        withdrawAmount = WISE_LENDING.withdrawOnBehalfExactShares(
            _nftId,
            SDAI_ADDRESS,
            _withdrawShares
        );

        _safeTransfer(
            SDAI_ADDRESS,
            msg.sender,
            withdrawAmount
        );
    }

    /**
     * @dev Liquidation function for open power farm
     * postions which have a debtratio greater 100 %.
     *
     * NOTE: The borrow token is defined by the positon
     * and thus cannot be usseted by the liquidator.
     * Since the token are borrwed from an aave pool it
     * is always an aave token derivative!
     * The receiving token is always sDAI.
     */
    function liquidatePartiallyFromToken(
        uint256 _nftId,
        uint256 _nftIdLiquidator,
        uint256 _shareAmountToPay
    )
        external
        updatePools(_nftId)
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
     * @dev Internal function combining the core
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

        uint256 index = nftToIndex[_nftId];

        uint256 leveragedAmount = getLeverageAmount(
            _initialAmount,
            _leverage
        );

        address borrowToken = borrowTokenAddresses[index];

        uint256 flashloanAmount = leveragedAmount
            - _initialAmount;

        if (index != uint256(Token.DAI)) {

            flashloanAmount = _convertIntoOtherStable(
                borrowToken,
                flashloanAmount
            );
        }

        if (_aboveMinDepositAmount(leveragedAmount) == false){
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
        uint256 index = nftToIndex[_nftId];

        address aaveToken = aaveTokenAddresses[index];

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

        nftToIndex[_nftId] = _index;

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

    /**
     * @dev Internal function combining the core
     * logic for {_unregistrationFarm()}.
     */
    function _unregistrationFarm(
        uint256 _nftId
    )
        internal
    {
        if (_checkPositionUsed(_nftId) == true) {
            revert PositionNotEmpty();
        }

        uint256 previousIndex = nftToIndex[_nftId];

        delete nftToIndex[_nftId];

        WISE_LENDING.setRegistrationIsolationPool(
            _nftId,
            false
        );

        emit UnregistrationFarm(
            _nftId,
            previousIndex,
            block.timestamp
        );
    }
}
