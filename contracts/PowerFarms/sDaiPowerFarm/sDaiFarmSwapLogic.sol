// SPDX-License-Identifier: -- WISE --

pragma solidity =0.8.21;

import "./sDaiFarmMathLogic.sol";

abstract contract sDaiFarmSwapLogic is sDaiFarmMathLogic {

    /**
     * @dev Internal wrapper function for an unsiwap
     * {exactOutputSingle()} swap from USDC to USDT.
     */
    function _swapUSDCToUSDT(
        uint256 _amountOut,
        uint256 _maxInAmount
    )
        internal
        returns (uint256)
    {
        IUniswapV3.ExactOutputSingleParams memory params =
            IUniswapV3.ExactOutputSingleParams({
                tokenIn: USDC_ADDRESS,
                tokenOut: USDT_ADDRESS,
                fee: uint24(100),
                recipient: address(this),
                deadline: block.timestamp,
                amountOut: _amountOut,
                amountInMaximum: _maxInAmount,
                sqrtPriceLimitX96: 0
            }
        );

        return UNISWAP.exactOutputSingle(
            params
        );
    }

    /**
     * @dev Internal wrapper function for an unsiwap
     * {exactInputSingle()} swap from USDT to USDC.
     */
    function _swapUSDTToUSDC(
        uint256 _amountIn,
        uint256 _minOutAmount
    )
        internal
        returns (uint256)
    {
        IUniswapV3.ExactInputSingleParams memory params =
            IUniswapV3.ExactInputSingleParams({
                tokenIn: USDT_ADDRESS,
                tokenOut: USDC_ADDRESS,
                fee: uint24(100),
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: _amountIn,
                amountOutMinimum: _minOutAmount,
                sqrtPriceLimitX96: 0
            }
        );

        return UNISWAP.exactInputSingle(
            params
        );
    }

    /**
     * @dev Internal wrapper function converting
     * USDC for DAI using DSS-PSM contract.
     */
    function _depositPreparationsUSDC(
        uint256 _flashloanAmount,
        uint256 _initialAmount
    )
        internal
        returns (uint256)
    {
        DSS_PSM.sellGem(
            address(this),
            _flashloanAmount
        );

        return _initialAmount
            + _flashloanAmount
            * PRECISION_FACTOR_E12;
    }

    /**
     * @dev Internal wrapper function swapping
     * USDT for USDC with uniswao and afterwards
     * using DSS-PSM contract to get DAI.
     */
    function _depositPreparationsUSDT(
        uint256 _flashloanAmount,
        uint256 _initialAmount,
        uint256 _minOutAmount
    )
        internal
        returns (uint256)
    {
        uint256 amountOut = _swapUSDTToUSDC(
            _flashloanAmount,
            _minOutAmount
        );

        DSS_PSM.sellGem(
            address(this),
            amountOut
        );

        return amountOut
            * PRECISION_FACTOR_E12
            + _initialAmount;
    }
}
