// SPDX-License-Identifier: -- WISE --

pragma solidity =0.8.24;

import "./GenericMathLogic.sol";

abstract contract GenericLeverageLogic is
    GenericMathLogic,
    IFlashLoanRecipient
{
    /**
     * @dev Wrapper function preparing balancer flashloan and
     * loading data to pass into receiver.
     */
    function _executeBalancerFlashLoan(
        uint256 _nftId,
        uint256 _flashAmount,
        uint256 _initialAmount,
        uint256 _lendingShares,
        uint256 _borrowShares,
        uint256 _allowedSpread,
        bool _ethBack,
        bool _isAave
    )
        internal
        virtual
    {
        IERC20[] memory tokens = new IERC20[](1);
        uint256[] memory amount = new uint256[](1);

        address flashAsset = FARM_ASSET;

        tokens[0] = IERC20(flashAsset);
        amount[0] = _flashAmount;

        allowEnter = true;

        BALANCER_VAULT.flashLoan(
            this,
            tokens,
            amount,
            abi.encode(
                _nftId,
                _initialAmount,
                _lendingShares,
                _borrowShares,
                _allowedSpread,
                msg.sender,
                _ethBack,
                _isAave
            )
        );
    }

    /**
     * @dev Receive function from balancer flashloan. Body
     * is called from balancer at the end of their {flashLoan()}
     * logic. Overwritten with opening flows.
     */
    function receiveFlashLoan(
        IERC20[] memory _flashloanToken,
        uint256[] memory _flashloanAmounts,
        uint256[] memory _feeAmounts,
        bytes memory _userData
    )
        external
        virtual
    {
        if (allowEnter == false) {
            revert GenericAccessDenied();
        }

        allowEnter = false;

        if (_flashloanToken.length == 0) {
            revert GenericInvalidParam();
        }

        if (msg.sender != BALANCER_ADDRESS) {
            revert GenericNotBalancerVault();
        }

        uint256 totalDebtBalancer = _flashloanAmounts[0]
            + _feeAmounts[0];

        (
            uint256 nftId,
            uint256 initialAmount,
            uint256 lendingShares,
            uint256 borrowShares,
            uint256 allowedSpread,
            address caller,
            bool ethBack,
            bool isAave
        ) = abi.decode(
            _userData,
            (
                uint256,
                uint256,
                uint256,
                uint256,
                uint256,
                address,
                bool,
                bool
            )
        );

        if (initialAmount > 0) {
            _logicOpenPosition(
                isAave,
                nftId,
                _flashloanAmounts[0] + initialAmount,
                totalDebtBalancer,
                allowedSpread
            );

            return;
        }

        _logicClosePosition(
            nftId,
            borrowShares,
            lendingShares,
            totalDebtBalancer,
            allowedSpread,
            caller,
            ethBack,
            isAave
        );
    }

    function _logicClosePosition(
        uint256 _nftId,
        uint256 _borrowShares,
        uint256 _lendingShares,
        uint256 _totalDebtBalancer,
        uint256 _allowedSpread,
        address _caller,
        bool _ethBack,
        bool _isAave
    )
        internal
        virtual
    {}

    function _getEthBack(
        uint256 _swapAmount,
        uint256 _minOutAmount
    )
        internal
        virtual
        returns (uint256)
    {
        uint256 wethAmount = _getTokensUniV3(
            _swapAmount,
            _minOutAmount,
            ENTRY_ASSET,
            FARM_ASSET
        );

        _unwrapETH(
            wethAmount
        );

        return wethAmount;
    }

    function _getTokensUniV3(
        uint256 _amountIn,
        uint256 _minOutAmount,
        address _tokenIn,
        address _tokenOut
    )
        internal
        virtual
        returns (uint256)
    {
        return UNISWAP_V3_ROUTER.exactInputSingle(
            IUniswapV3.ExactInputSingleParams(
                {
                    tokenIn: _tokenIn,
                    tokenOut: _tokenOut,
                    fee: UNISWAP_V3_FEE,
                    recipient: address(this),
                    deadline: block.timestamp,
                    amountIn: _amountIn,
                    amountOutMinimum: _minOutAmount,
                    sqrtPriceLimitX96: 0
                }
            )
        );
    }

    function _swapStETHintoETH(
        uint256 _swapAmount,
        uint256 _minOutAmount
    )
        internal
        virtual
        returns (uint256)
    {}

    function _withdrawPendleLPs(
        uint256 _nftId,
        uint256 _lendingShares
    )
        internal
        virtual
        returns (uint256 withdrawnLpsAmount)
    {
        return IPendleChild(PENDLE_CHILD).withdrawExactShares(
            WISE_LENDING.withdrawExactShares(
                _nftId,
                PENDLE_CHILD,
                _lendingShares
            )
        );
    }

    function _paybackExactShares(
        bool _isAave,
        uint256 _nftId,
        uint256 _borrowShares
    )
        internal
        virtual
    {
        if (_isAave == true) {
            AAVE_HUB.paybackExactShares(
                _nftId,
                FARM_ASSET,
                _borrowShares
            );

            return;
        }

        WISE_LENDING.paybackExactShares(
            _nftId,
            FARM_ASSET,
            _borrowShares
        );
    }

    /**
     * @dev Internal wrapper function for a closing route
     * which returns {ENTRY_ASSET} to the owner in the end.
     */
    function _closingRouteToken(
        uint256 _tokenAmount,
        uint256 _totalDebtBalancer,
        address _caller
    )
        internal
        virtual
    {
        if (FARM_ASSET == WETH_ADDRESS) {
            _wrapETH(
                _tokenAmount
            );
        }

        _safeTransfer(
            FARM_ASSET,
            msg.sender,
            _totalDebtBalancer
        );

        _safeTransfer(
            FARM_ASSET,
            _caller,
            _tokenAmount - _totalDebtBalancer
        );
    }

    /**
     * @dev Internal wrapper function for a closing route
     * which returns ETH to the owner in the end.
     */
    function _closingRouteETH(
        uint256 _ethAmount,
        uint256 _totalDebtBalancer,
        address _caller
    )
        internal
        virtual
    {
        _wrapETH(
            _totalDebtBalancer
        );

        _safeTransfer(
            FARM_ASSET,
            msg.sender,
            _totalDebtBalancer
        );

        _sendValue(
            _caller,
            _ethAmount - _totalDebtBalancer
        );
    }

    function _logicOpenPosition(
        bool _isAave,
        uint256 _nftId,
        uint256 _depositAmount,
        uint256 _totalDebtBalancer,
        uint256 _allowedSpread
    )
        internal
        virtual
    {}

    function _borrowExactAmount(
        bool _isAave,
        uint256 _nftId,
        uint256 _totalDebtBalancer
    )
        internal
        virtual
    {
        if (_isAave == true) {
            AAVE_HUB.borrowExactAmount(
                _nftId,
                FARM_ASSET,
                _totalDebtBalancer
            );

            return;
        }

        WISE_LENDING.borrowExactAmount(
            _nftId,
            FARM_ASSET,
            _totalDebtBalancer
        );
    }

    /**
     * @dev Internal function summarizing liquidation
     * checks and interface call for core liquidation
     * from wise lending.
     */
    function _coreLiquidation(
        uint256 _nftId,
        uint256 _nftIdLiquidator,
        uint256 _shareAmountToPay
    )
        internal
        virtual
        returns (
            uint256 paybackAmount,
            uint256 receivingAmount
        )
    {
        _checkLiquidatability(
            _nftId
        );

        address paybackToken = isAave[_nftId] == true
            ? POOL_ASSET_AAVE
            : FARM_ASSET;

        paybackAmount = WISE_LENDING.paybackAmount(
            paybackToken,
            _shareAmountToPay
        );

        uint256 cutoffShares = isAave[_nftId] == true
            ? _getPositionBorrowSharesAave(_nftId)
                * FIFTY_PERCENT
                / PRECISION_FACTOR_E18
            : _getPositionBorrowShares(_nftId)
                * FIFTY_PERCENT
                / PRECISION_FACTOR_E18;

        if (_shareAmountToPay > cutoffShares) {
            revert GenericTooMuchShares();
        }

        receivingAmount = WISE_LENDING.coreLiquidationIsolationPools(
            _nftId,
            _nftIdLiquidator,
            msg.sender,
            paybackToken,
            PENDLE_CHILD,
            paybackAmount,
            _shareAmountToPay
        );
    }

    function _checkLiquidatability(
        uint256 _nftId
    )
        internal
        virtual
        view
    {
        if (specialDepegCase == true) {
            return;
        }

        if (_checkDebtRatio(_nftId) == true) {
            revert GenericDebtRatioTooLow();
        }
    }
}
