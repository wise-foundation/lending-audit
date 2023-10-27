// SPDX-License-Identifier: -- WISE --

pragma solidity =0.8.21;

import "./PendleWstETHManager.sol";

contract PendleWstETHFarmTester is PendleWstETHManager {

    constructor(
        address _wiseLending,
        address _lockContract,
        uint256 _collateralFactor,
        address _powerFarmNFTs
    )
        PendleWstETHManager(
            _wiseLending,
            _lockContract,
            _collateralFactor,
            _powerFarmNFTs
        )
    {}

    function mintTestToken(
        uint256 _amount
    )
        external
    {
        HYBRID_TOKEN.mint(
            msg.sender,
            _amount
        );
    }

    /*
    function claimMarketRewards(
        address _powerFarm
    )
        external
    {
        uint256[] memory pendle = LP_PENDLE.redeemRewards(
            address(this)
        );
    }
    */

    function depositPendleTest(
        address _receiver
    )
        external
        payable
        returns (
            uint256,
            uint256
        )
    {
        uint256 wstETHAmount = _wrapWstETH(
            msg.value
        );

        _increaseOracleValue(
            wstETHAmount
        );

        _getSy(
            wstETHAmount
        );

        uint256 hybridTokens = _getHybridEquivalent(
            wstETHAmount,
            0,
            1
        );

        _handleMintZeroPriceImpact(
            _receiver,
            hybridTokens,
            wstETHAmount
        );

        _updateFarmState();

        return (
            hybridTokens,
            wstETHAmount
        );
    }

    function getLPZeroPriceImpactETH()
        external
        payable
        returns (uint256)
    {
        uint256 wstETHAmount = _wrapWstETH(
            msg.value
        );

        _getSy(
            wstETHAmount
        );

        uint256 amountPt = _getDisassembleTokenAmount(
            wstETHAmount
        );

        _getPY(
            amountPt
        );

        uint256[3] memory results = _getLP(
            wstETHAmount - amountPt,
            amountPt
        );

        _safeTransfer(
            PENDLE_MARKET_ADDRESS,
            msg.sender,
            results[0]
        );

        _safeTransfer(
            YT_PENDLE_ADDRESS,
            msg.sender,
            results[2]
        );

        return results[0];
    }
}
