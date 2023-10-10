// SPDX-License-Identifier: -- WISE --

pragma solidity =0.8.21;

import "./OpsTaskCreator.sol";

abstract contract LiquidationResolver is OpsTaskCreator {

    function resolverUpdate()
        external
        view
        returns (bool canExec, bytes memory execPayload)
    {
        address token;

        for (uint256 i = 0; i < FEE_MANAGER.getPoolTokenAddressesLength(); ++i) {

            token = FEE_MANAGER.getPoolTokenAdressesByIndex(
                i
            );

            execPayload = abi.encodeWithSelector(
                WISE_LENDING.syncManually.selector,
                token
            );

            canExec = _checkPriceThreshold(
                token
            );

            if (canExec == true) {
                return (true, execPayload);
            }

            canExec = _checkIntervall(
                token
            );

            if (canExec == true) {
                return (true, execPayload);
            }
        }

        return (false, bytes("NO_UPDATE"));
    }

    function resolverLiqudation1()
        external
        view
        returns (bool canExec, bytes memory execPayload)
    {
        uint256 shares;
        address receiveToken;
        address liquidateToken;

        for (uint256 nftID = 0; nftID < BASE_INTERVAL; nftID++) {

            (
                liquidateToken,
                receiveToken,
                shares

            ) = _getLiqudationPosition(
                nftID
            );

            if (liquidateToken == ZERO_ADDRESS) {
                continue;
            }

            execPayload = abi.encodeWithSelector(
                WISE_LIQUIDATION.liquidatePartiallyFromTokens.selector,
                nftID,
                NFT_BOT,
                liquidateToken,
                receiveToken,
                shares
            );

            return (true, execPayload);
        }

        return (false, bytes("NO_POSITION"));
    }

    function resolverLiqudation2()
        external
        view
        returns (bool canExec, bytes memory execPayload)
    {
        uint256 shares;
        address receiveToken;
        address liquidateToken;

        for (uint256 nftID = BASE_INTERVAL; nftID < 2 * BASE_INTERVAL; nftID++) {

            (
                liquidateToken,
                receiveToken,
                shares

            ) = _getLiqudationPosition(
                nftID
            );

            if (liquidateToken == ZERO_ADDRESS) {
                continue;
            }

            execPayload = abi.encodeWithSelector(
                WISE_LIQUIDATION.liquidatePartiallyFromTokens.selector,
                nftID,
                NFT_BOT,
                liquidateToken,
                receiveToken,
                shares
            );

            return (true, execPayload);
        }

        return (false, EMPTY_BYTES);
    }

    function resolverLiqudation3()
        external
        view
        returns (bool canExec, bytes memory execPayload)
    {
        uint256 shares;
        address receiveToken;
        address liquidateToken;

        for (uint256 nftID = 2 * BASE_INTERVAL; nftID < 3 * BASE_INTERVAL; nftID++) {

            (
                liquidateToken,
                receiveToken,
                shares

            ) = _getLiqudationPosition(
                nftID
            );

            if (liquidateToken == ZERO_ADDRESS) {
                continue;
            }

            execPayload = abi.encodeWithSelector(
                WISE_LIQUIDATION.liquidatePartiallyFromTokens.selector,
                nftID,
                NFT_BOT,
                liquidateToken,
                receiveToken,
                shares
            );

            return (true, execPayload);
        }

        return (false, EMPTY_BYTES);
    }

    function resolverLiqudation4()
        external
        view
        returns (bool canExec, bytes memory execPayload)
    {
        uint256 shares;
        address receiveToken;
        address liquidateToken;

        for (uint256 nftID = 3 * BASE_INTERVAL; nftID < 4 * BASE_INTERVAL; nftID++) {

            (
                liquidateToken,
                receiveToken,
                shares

            ) = _getLiqudationPosition(
                nftID
            );

            if (liquidateToken == ZERO_ADDRESS) {
                continue;
            }

            execPayload = abi.encodeWithSelector(
                WISE_LIQUIDATION.liquidatePartiallyFromTokens.selector,
                nftID,
                NFT_BOT,
                liquidateToken,
                receiveToken,
                shares
            );

            return (true, execPayload);
        }

        return (false, EMPTY_BYTES);
    }

    function resolverLiqudation5()
        external
        view
        returns (bool canExec, bytes memory execPayload)
    {
        uint256 shares;
        address receiveToken;
        address liquidateToken;

        for (uint256 nftID = 4 * BASE_INTERVAL; nftID < 5 * BASE_INTERVAL; nftID++) {

            (
                liquidateToken,
                receiveToken,
                shares

            ) = _getLiqudationPosition(
                nftID
            );

            if (liquidateToken == ZERO_ADDRESS) {
                continue;
            }

            execPayload = abi.encodeWithSelector(
                WISE_LIQUIDATION.liquidatePartiallyFromTokens.selector,
                nftID,
                NFT_BOT,
                liquidateToken,
                receiveToken,
                shares
            );

            return (true, execPayload);
        }

        return (false, EMPTY_BYTES);
    }

    function resolverLiqudation6()
        external
        view
        returns (bool canExec, bytes memory execPayload)
    {
        uint256 shares;
        address receiveToken;
        address liquidateToken;

        for (uint256 nftID = 5 * BASE_INTERVAL; nftID < 6 * BASE_INTERVAL; nftID++) {

            (
                liquidateToken,
                receiveToken,
                shares

            ) = _getLiqudationPosition(
                nftID
            );

            if (liquidateToken == ZERO_ADDRESS) {
                continue;
            }

            execPayload = abi.encodeWithSelector(
                WISE_LIQUIDATION.liquidatePartiallyFromTokens.selector,
                nftID,
                NFT_BOT,
                liquidateToken,
                receiveToken,
                shares
            );

            return (true, execPayload);
        }

        return (false, EMPTY_BYTES);
    }

    function resolverLiqudation7()
        external
        view
        returns (bool canExec, bytes memory execPayload)
    {
        uint256 shares;
        address receiveToken;
        address liquidateToken;

        for (uint256 nftID = 6 * BASE_INTERVAL; nftID < 7 * BASE_INTERVAL; nftID++) {

            (
                liquidateToken,
                receiveToken,
                shares

            ) = _getLiqudationPosition(
                nftID
            );

            if (liquidateToken == ZERO_ADDRESS) {
                continue;
            }

            execPayload = abi.encodeWithSelector(
                WISE_LIQUIDATION.liquidatePartiallyFromTokens.selector,
                nftID,
                NFT_BOT,
                liquidateToken,
                receiveToken,
                shares
            );

            return (true, execPayload);
        }

        return (false, EMPTY_BYTES);
    }

    function resolverLiqudation8()
        external
        view
        returns (bool canExec, bytes memory execPayload)
    {
        uint256 shares;
        address receiveToken;
        address liquidateToken;

        for (uint256 nftID = 7 * BASE_INTERVAL; nftID < 8 * BASE_INTERVAL; nftID++) {

            (
                liquidateToken,
                receiveToken,
                shares

            ) = _getLiqudationPosition(
                nftID
            );

            if (liquidateToken == ZERO_ADDRESS) {
                continue;
            }

            execPayload = abi.encodeWithSelector(
                WISE_LIQUIDATION.liquidatePartiallyFromTokens.selector,
                nftID,
                NFT_BOT,
                liquidateToken,
                receiveToken,
                shares
            );

            return (true, execPayload);
        }

        return (false, EMPTY_BYTES);
    }

    function resolverLiqudation9()
        external
        view
        returns (bool canExec, bytes memory execPayload)
    {
        uint256 shares;
        address receiveToken;
        address liquidateToken;

        for (uint256 nftID = 8 * BASE_INTERVAL; nftID < 9 * BASE_INTERVAL; nftID++) {

            (
                liquidateToken,
                receiveToken,
                shares

            ) = _getLiqudationPosition(
                nftID
            );

            if (liquidateToken == ZERO_ADDRESS) {
                continue;
            }

            execPayload = abi.encodeWithSelector(
                WISE_LIQUIDATION.liquidatePartiallyFromTokens.selector,
                nftID,
                NFT_BOT,
                liquidateToken,
                receiveToken,
                shares
            );

            return (true, execPayload);
        }

        return (false, EMPTY_BYTES);
    }

    function resolverLiqudation10()
        external
        view
        returns (bool canExec, bytes memory execPayload)
    {
        uint256 shares;
        address receiveToken;
        address liquidateToken;

        for (uint256 nftID = 9 * BASE_INTERVAL; nftID < 10 * BASE_INTERVAL; nftID++) {

            (
                liquidateToken,
                receiveToken,
                shares

            ) = _getLiqudationPosition(
                nftID
            );

            if (liquidateToken == ZERO_ADDRESS) {
                continue;
            }

            execPayload = abi.encodeWithSelector(
                WISE_LIQUIDATION.liquidatePartiallyFromTokens.selector,
                nftID,
                NFT_BOT,
                liquidateToken,
                receiveToken,
                shares
            );

            return (true, execPayload);
        }

        return (false, EMPTY_BYTES);
    }

        function _getLiqudationPosition(
        uint256 _nftId
    )
        internal
        view
        returns (
            address,
            address,
            uint256
        )
    {
        address liquidateToken;
        address receiveToken;
        uint256 shares;
        uint256 liquidationUSDBare;
        uint256 receiveUSD;
        uint256 shareUSD;

        uint256 debtRatio = WISE_SECURITY.getLiveDebtRatio(
            _nftId
        );

        if (debtRatio < PRECISION_FACTOR_E18) {
            return (
                ZERO_ADDRESS,
                ZERO_ADDRESS,
                0
            );
        }

        (
            liquidateToken,
            shares,
            liquidationUSDBare

        ) = _checkForLiquidatableToken(
            _nftId
        );

        bool canExec = liquidateToken != ZERO_ADDRESS;

        if (canExec == false) {
            return (
                ZERO_ADDRESS,
                ZERO_ADDRESS,
                0
            );
        }

        (
            receiveToken,
            receiveUSD

        ) = _checkForReceiveToken(
            _nftId
        );

        shares = _checkReceiveValue(
            liquidationUSDBare,
            receiveUSD,
            shares
        );

        shareUSD = _getSharesUSD(
            liquidateToken,
            shares
        );

        if (shareUSD < THRESHOLD) {
            return (
                ZERO_ADDRESS,
                ZERO_ADDRESS,
                0
            );
        }

        return(
            liquidateToken,
            receiveToken,
            shares
        );
    }

    function _checkMaxFee(
        uint256 _paybackUSD
    )
        internal
        pure
        returns (uint256)
    {
        uint256 feeUSD = _paybackUSD
            * FEE_PERCENT
            / PRECISION_FACTOR_E18;

        return feeUSD < MAX_USD_LIQUIDATION_FEE
            ? feeUSD
            : MAX_USD_LIQUIDATION_FEE;
    }

    function _checkReceiveValue(
        uint256 _liquidationUSDBare,
        uint256 _receiveUSD,
        uint256 _liquidationShares
    )
        internal
        pure
        returns (uint256)
    {
        uint256 liquidationUSDTotal = _liquidationUSDBare
            + _checkMaxFee(_liquidationUSDBare);

        if (liquidationUSDTotal <= _receiveUSD) {
            return _liquidationShares;
        }

        return _receiveUSD
            * _liquidationShares
            / liquidationUSDTotal;
    }

    function _checkForReceiveToken(
        uint256 _nftId
    )
        internal
        view
        returns (address highestToken, uint256 highsteUSDValue)
    {
        highsteUSDValue = 0;

        for (uint8 i = 0; i < WISE_LENDING.getPositionLendingTokenLength(_nftId); ++i) {

            address token = WISE_LENDING.getPositionLendingTokenByIndex(
                _nftId,
                i
            );

            uint256 tokenAmount = WISE_SECURITY.getPositionLendingAmount(
                _nftId,
                token
            );

            uint256 USDEquivalent = ORACLE_HUB.getTokensInUSD(
                token,
                tokenAmount
            );

            if (USDEquivalent > highsteUSDValue) {
                highsteUSDValue = USDEquivalent;
                highestToken = token;
            }
        }
    }

    function _checkForLiquidatableToken(
        uint256 _nftId
    )
        internal
        view
        returns (address, uint256, uint256)
    {
        uint256 l = WISE_LENDING.getPositionBorrowTokenLength(
            _nftId
        );

        for (uint8 i = 0; i < l; ++i) {

            address token = WISE_LENDING.getPositionBorrowTokenByIndex(
                _nftId,
                i
            );

            uint256 shareAmount = WISE_LENDING.getPositionBorrowShares(
                _nftId,
                token
            );

            uint256 liquidationShares = shareAmount
                * liquidationPercent
                / PRECISION_FACTOR_E18;

            uint256 USDEquivalent = _getSharesUSD(
                token,
                liquidationShares
            );

            if (USDEquivalent >= THRESHOLD) {
                return (
                    token,
                    liquidationShares,
                    USDEquivalent
                );
            }
        }

        return (
            ZERO_ADDRESS,
            0,
            0
        );
    }

    function _getSharesUSD(
        address _tokenAddress,
        uint256 _shares
    )
        internal
        view
        returns (uint256)
    {
        return ORACLE_HUB.getTokensInUSD(
            _tokenAddress,
            WISE_LENDING.paybackAmount(
                _tokenAddress,
                _shares
            )
        );
    }

    function _checkIntervall(
        address _token
    )
        internal
        view
        returns (bool)
    {
        return block.timestamp >
            WISE_LENDING.lastUpdated(_token)
            + intervallUpdate[_token];
    }

    function _checkPriceThreshold(
        address _token
    )
        internal
        view
        returns (bool)
    {
        uint256 previousUSD = ORACLE_HUB.previousValue(
            _token
        );

        uint256 currentUSD = ORACLE_HUB.latestResolver(
            _token
        );

        uint256 upperBound = previousUSD
            * (PRECISION_FACTOR_E18 + thresholdPriceDeviation[_token])
            / PRECISION_FACTOR_E18;

        uint256 lowerBound = previousUSD
            * (PRECISION_FACTOR_E18 - thresholdPriceDeviation[_token])
            / PRECISION_FACTOR_E18;

        if (currentUSD > upperBound) {
            return true;
        }

        if (currentUSD < lowerBound) {
            return true;
        }

        return false;
    }
}