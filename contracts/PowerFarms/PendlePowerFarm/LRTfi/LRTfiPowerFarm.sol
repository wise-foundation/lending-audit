// SPDX-License-Identifier: -- WISE --

pragma solidity =0.8.24;

/**
 * @author René Hochmuth
 * @author Christoph Krpoun
 * @author Vitally Marinchenko
 */

import "../../GenericPowerManager.sol";

error LRTfi_DebtRatioTooHigh();
error LRTfi_TooMuchValueLost();

contract LRTfiPowerFarm is GenericPowerManager {

    constructor(
        address _wiseLendingAddress,
        address _pendleChildTokenAddress,
        address _pendleRouter,
        address _entryAsset,
        address _pendleSy,
        address _underlyingMarket,
        address _routerStatic,
        address _dexAddress,
        uint256 _collateralFactor,
        address _powerFarmNFTs
    )
        GenericPowerManager(
            _wiseLendingAddress,
            _pendleChildTokenAddress,
            _pendleRouter,
            _entryAsset,
            _pendleSy,
            _underlyingMarket,
            _routerStatic,
            _dexAddress,
            _collateralFactor,
            _powerFarmNFTs
        )
    {
        _doApprovals(
            _wiseLendingAddress
        );

        collateralFactorRole = msg.sender;

        FARM_ASSET = WETH_ADDRESS;
        POOL_ASSET_AAVE = AAVE_WETH_ADDRESS;
    }

    function _doApprovals(
        address _wiseLendingAddress
    )
        internal
        override
    {
        _safeApprove(
            address(ENTRY_ASSET),
            address(UNISWAP_V3_ROUTER),
            MAX_AMOUNT
        );

        _safeApprove(
            AAVE_WETH_ADDRESS,
            _wiseLendingAddress,
            MAX_AMOUNT
        );

        _safeApprove(
            WETH_ADDRESS,
            address(UNISWAP_V3_ROUTER),
            MAX_AMOUNT
        );

        _safeApprove(
            WETH_ADDRESS,
            _wiseLendingAddress,
            MAX_AMOUNT
        );

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

        _safeApprove(
            WETH_ADDRESS,
            address(AAVE_HUB),
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
    {
        uint256 reverseAllowedSpread = PRECISION_FACTOR_E18_2X
            - _allowedSpread;

        uint256 ethValueBefore = _getTokensInETH(
            WETH_ADDRESS,
            _depositAmount
        );

        _depositAmount = _getTokensUniV3(
            _depositAmount,
            _getEthInTokens(
                ENTRY_ASSET,
                _depositAmount
            )
                * reverseAllowedSpread
                / PRECISION_FACTOR_E18,
            WETH_ADDRESS,
            ENTRY_ASSET
        );

        uint256 syReceived = PENDLE_SY.deposit(
            {
                _receiver: address(this),
                _tokenIn: ENTRY_ASSET,
                _amountTokenToDeposit: _depositAmount,
                _minSharesOut: PENDLE_SY.previewDeposit(
                    ENTRY_ASSET,
                    _depositAmount
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
            revert LRTfi_TooMuchValueLost();
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
            revert LRTfi_DebtRatioTooHigh();
        }

        _safeTransfer(
            WETH_ADDRESS,
            BALANCER_ADDRESS,
            _totalDebtBalancer
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
        bool _ethBack,
        bool _isAave
    )
        internal
        override
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

        address tokenOut = ENTRY_ASSET;

        uint256 tokenOutAmount = PENDLE_SY.redeem(
            {
                _receiver: address(this),
                _amountSharesToRedeem: netSyOut,
                _tokenOut: tokenOut,
                _minTokenOut: 0,
                _burnFromInternalBalance: false
            }
        );

        uint256 reverseAllowedSpread = PRECISION_FACTOR_E18_2X
            - _allowedSpread;

        uint256 ethAmount = _getEthBack(
            tokenOutAmount,
            _getTokensInETH(
                WETH_ADDRESS,
                _getTokensInETH(
                    tokenOut,
                    tokenOutAmount
                )
            )
                * reverseAllowedSpread
                / PRECISION_FACTOR_E18
        );

        uint256 ethValueAfter = _getTokensInETH(
            WETH_ADDRESS,
            ethAmount
        )
            * _allowedSpread
            / PRECISION_FACTOR_E18;

        if (ethValueAfter < ethValueBefore) {
            revert LRTfi_TooMuchValueLost();
        }

        if (_ethBack == true) {
            _closingRouteETH(
                ethAmount,
                _totalDebtBalancer,
                _caller
            );

            return;
        }

        _closingRouteToken(
            ethAmount,
            _totalDebtBalancer,
            _caller
        );
    }
}
