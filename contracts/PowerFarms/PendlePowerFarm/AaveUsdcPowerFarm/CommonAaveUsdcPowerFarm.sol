// SPDX-License-Identifier: -- WISE --

pragma solidity =0.8.24;

/**
 * @author René Hochmuth
 * @author Christoph Krpoun
 * @author Vitally Marinchenko
 */

import "../../GenericPowerManager.sol";

error AaveUsdcTooMuchValueLost(
    address farmAsset
);
error NotSupported();
error AaveUsdcDebtRatioTooHigh(
    address farmAsset
);

abstract contract CommonAaveUsdcPowerFarm is GenericPowerManager {

    address public constant NATIVE_USDC_ARBITRUM_ADDRESS = address(
        0xaf88d065e77c8cC2239327C5EDb3A432268e5831
    );

    function _doApprovals(
        address _wiseLendingAddress
    )
        internal
        override
        virtual
    {
        _executeCommonApprovals(
            _wiseLendingAddress
        );

        _safeApprove(
            FARM_ASSET,
            _wiseLendingAddress,
            MAX_AMOUNT
        );

        _safeApprove(
            POOL_ASSET_AAVE,
            _wiseLendingAddress,
            MAX_AMOUNT
        );

        _safeApprove(
            FARM_ASSET,
            address(AAVE_HUB),
            MAX_AMOUNT
        );

        _safeApprove(
            FARM_ASSET,
            address(UNISWAP_V3_ROUTER),
            MAX_AMOUNT
        );

        _safeApprove(
            NATIVE_USDC_ARBITRUM_ADDRESS,
            address(UNISWAP_V3_ROUTER),
            MAX_AMOUNT
        );
    }

    /**
     * @dev Internal function executing the
     * collateral deposit by converting ETH
     * into {ENTRY_ASSET}, adding it as collateral and
     * borrowing the flashloan token to pay
     * back {_totalDebtBalancer}.
     */
    function _logicOpenPosition(
        bool _isAave,
        uint256 _nftId,
        uint256 _depositAmount,
        uint256 _totalDebtBalancer,
        uint256 _allowedSpread
    )
        internal
        override
        virtual
    {
        uint256 reverseAllowedSpread = 2
            * PRECISION_FACTOR_E18
            - _allowedSpread;

        uint256 receiveAmount = _getTokensUniV3(
            _depositAmount,
            _getEthInTokens(
                ENTRY_ASSET,
                _getTokensInETH(
                    FARM_ASSET,
                    _depositAmount
                )
            )
                * reverseAllowedSpread
                / PRECISION_FACTOR_E18,
            FARM_ASSET,
            ENTRY_ASSET
        );

        _executeCommonOpenPosition(
            _isAave,
            _nftId,
            _depositAmount,
            receiveAmount,
            _totalDebtBalancer,
            _allowedSpread
        );
    }

    /**
     * @dev Closes position using balancer flashloans.
     */
    function _logicClosePosition(
        uint256 _nftId,
        uint256 _borrowShares,
        uint256 _lendingShares,
        uint256 _totalDebtBalancer,
        uint256 _allowedSpread,
        address _caller,
        bool,
        bool _isAave
    )
        internal
        override
        virtual
    {
        (
            uint256 tokenOutAmount,
            uint256 ethValueBefore
        ) = _executeCommonClosePositionUntilRedeem(
            _nftId,
            _borrowShares,
            _lendingShares,
            _isAave
        );

        uint256 reverseAllowedSpread = 2
            * PRECISION_FACTOR_E18
            - _allowedSpread;

        uint256 receiveAmount = _getTokensUniV3(
            tokenOutAmount,
            _getEthInTokens(
                FARM_ASSET,
                ethValueBefore
                    * reverseAllowedSpread
                    / PRECISION_FACTOR_E18
                ),
            NATIVE_USDC_ARBITRUM_ADDRESS,
            FARM_ASSET
        );

        _executeCommonClosePositionAfterRedeem(
            receiveAmount,
            _totalDebtBalancer,
            _allowedSpread,
            ethValueBefore,
            _caller
        );
    }

    function _executeCommonClosePositionAfterRedeem(
        uint256 _receivedAmount,
        uint256 _totalDebtBalancer,
        uint256 _allowedSpread,
        uint256 _ethValueBefore,
        address _caller
    )
        internal
    {
        uint256 ethValueAfter = _getTokensInETH(
            NATIVE_USDC_ARBITRUM_ADDRESS,
            _receivedAmount
        )
            * _allowedSpread
            / PRECISION_FACTOR_E18;

        if (ethValueAfter < _ethValueBefore) {
            revert AaveUsdcTooMuchValueLost(
                FARM_ASSET
            );
        }

        _closingRouteToken(
            _receivedAmount,
            _totalDebtBalancer,
            _caller
        );
    }

    function _executeCommonClosePositionUntilRedeem(
        uint256 _nftId,
        uint256 _borrowShares,
        uint256 _lendingShares,
        bool _isAave
    )
        internal
        returns (
            uint256,
            uint256
        )
    {
        _paybackExactShares(
            _isAave,
            _nftId,
            _borrowShares
        );

        uint256 withdrawnLpsAmount = _withdrawPendleLPs(
            _nftId,
            _lendingShares
        );

        uint256 ethValueBefore = _getTokensInETH(
            PENDLE_CHILD,
            withdrawnLpsAmount
        );

        (
            uint256 netSyOut
            ,
        ) = PENDLE_ROUTER.removeLiquiditySingleSy(
            {
                _receiver: address(this),
                _market: address(PENDLE_MARKET),
                _netLpToRemove: withdrawnLpsAmount,
                _minSyOut: 0
            }
        );

        return (
            PENDLE_SY.redeem(
                {
                    _receiver: address(this),
                    _amountSharesToRedeem: netSyOut,
                    _tokenOut: NATIVE_USDC_ARBITRUM_ADDRESS,
                    _minTokenOut: 0,
                    _burnFromInternalBalance: false
                }
            ),
            ethValueBefore
        );
    }

    function _executeCommonOpenPosition(
        bool _isAave,
        uint256 _nftId,
        uint256 _depositAmount,
        uint256 _receiveAmount,
        uint256 _totalDebtBalancer,
        uint256 _allowedSpread
    )
        internal
    {
        uint256 syReceived = PENDLE_SY.deposit(
            {
                _receiver: address(this),
                _tokenIn: ENTRY_ASSET,
                _amountTokenToDeposit: _receiveAmount,
                _minSharesOut: PENDLE_SY.previewDeposit(
                    ENTRY_ASSET,
                    _receiveAmount
                )
            }
        );

        (   ,
            uint256 netPtFromSwap,
            ,
            ,
            ,
        ) = PENDLE_ROUTER_STATIC.addLiquiditySingleSyStatic(
            address(PENDLE_MARKET),
            syReceived
        );

        (
            uint256 netLpOut
            ,
        ) = PENDLE_ROUTER.addLiquiditySingleSy(
            {
                _receiver: address(this),
                _market: address(PENDLE_MARKET),
                _netSyIn: syReceived,
                _minLpOut: 0,
                _guessPtReceivedFromSy: ApproxParams(
                    {
                        guessMin: netPtFromSwap - 100,
                        guessMax: netPtFromSwap + 100,
                        guessOffchain: 0,
                        maxIteration: 50,
                        eps: 1e15
                    }
                )
            }
        );

        uint256 ethValueBefore = _getTokensInETH(
            FARM_ASSET,
            _depositAmount
        );

        (
            uint256 receivedShares
            ,
        ) = IPendleChild(PENDLE_CHILD).depositExactAmount(
            netLpOut
        );

        uint256 ethValueAfter = _getTokensInETH(
            PENDLE_CHILD,
            receivedShares
        )
            * _allowedSpread
            / PRECISION_FACTOR_E18;

        if (ethValueAfter < ethValueBefore) {
            revert AaveUsdcTooMuchValueLost(
                FARM_ASSET
            );
        }

        WISE_LENDING.depositExactAmount(
            _nftId,
            PENDLE_CHILD,
            receivedShares
        );

        _borrowExactAmount(
            _isAave,
            _nftId,
            _totalDebtBalancer
        );

        if (_checkDebtRatio(_nftId) == false) {
            revert AaveUsdcDebtRatioTooHigh(
                FARM_ASSET
            );
        }

        _safeTransfer(
            FARM_ASSET,
            BALANCER_ADDRESS,
            _totalDebtBalancer
        );
    }

    function _executeCommonApprovals(
        address _wiseLendingAddress
    )
        internal
    {
        _safeApprove(
            PENDLE_CHILD,
            _wiseLendingAddress,
            MAX_AMOUNT
        );

        _safeApprove(
            ENTRY_ASSET,
            address(PENDLE_ROUTER),
            MAX_AMOUNT
        );

        _safeApprove(
            address(PENDLE_MARKET),
            PENDLE_CHILD,
            MAX_AMOUNT
        );

        _safeApprove(
            address(PENDLE_MARKET),
            address(PENDLE_ROUTER),
            MAX_AMOUNT
        );

        _safeApprove(
            address(ENTRY_ASSET),
            address(PENDLE_SY),
            MAX_AMOUNT
        );

        _safeApprove(
            address(PENDLE_SY),
            address(PENDLE_ROUTER),
            MAX_AMOUNT
        );
    }

    function enterFarmETH(
        bool,
        uint256,
        uint256
    )
        external
        payable
        override
        isActive
        updatePools
        returns (uint256)
    {
        revert NotSupported();
    }
}