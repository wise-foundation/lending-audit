// SPDX-License-Identifier: -- WISE --

pragma solidity =0.8.21;

/**
 * @author Christoph Krpoun
 * @author René Hochmuth
 * @author Vitally Marinchenko
 */

import "./WiseSecurityHelper.sol";
import "../TransferHub/ApprovalHelper.sol";

/**
 * @dev WiseSecurity is a core contract for wiseLending including most of
 * the performed security checks for withdraws, borrows, paybacks and liquidations.
 * It also has several read only functions providing UI data for a better user
 * experiencne.
 *
 */

error NotWiseLendingSecurity();

contract WiseSecurity is WiseSecurityHelper, ApprovalHelper {

    modifier onlyWiseLending() {
        _onlyWiseLending();
        _;
    }

    function _onlyWiseLending()
        private
        view
    {
        if (msg.sender == address(WISE_LENDING)) {
            return;
        }

        revert NotWiseLendingSecurity();
    }

    constructor(
        address _master,
        address _wiseLendingAddress,
        address _aaveHubAddress,
        uint256 _borrowPercentageCap
    )
        WiseSecurityDeclarations(
            _master,
            _wiseLendingAddress,
            _aaveHubAddress,
            _borrowPercentageCap
        )
    {}

    /**
     * @dev View functions returning current
     * debt ratio of a postion in normal mode.
     * 1% <=> 1E16
     */
    function getLiveDebtRatio(
        uint256 _nftId
    )
        external
        view
        returns (uint256)
    {
        uint256 overallCollateral = overallUSDCollateralsWeighted(
            _nftId
        );

        if (overallCollateral == 0) {
            return 0;
        }

        return overallUSDBorrow(_nftId)
            * PRECISION_FACTOR_E18
            / overallCollateral;
    }

    /**
     * @dev Set functions to define underlying tokens
     * for a pool token. (E.g underlying token of a
     * LP token like Curve, Uniswap).
     */
    function setLiquidationSettings(
        uint256 _baseReward,
        uint256 _baseRewardFarm,
        uint256 _newMaxFeeUSD,
        uint256 _newMaxFeeFarmUSD
    )
        external
        onlyMaster
    {
        if (_baseReward > 0) {
            baseRewardLiquidation = _baseReward;
        }

        if (_baseRewardFarm > 0) {
            baseRewardLiquidationFarm = _baseRewardFarm;
        }

        if (_newMaxFeeUSD > 0) {
            maxFeeUSD = _newMaxFeeUSD;
        }

        if (_newMaxFeeFarmUSD > 0) {
            maxFeeFarmUSD = _newMaxFeeFarmUSD;
        }
    }

    /**
     * @dev Checks for liquidation logic.
     */
    function checksLiquidation(
        uint256 _nftIdLiquidate,
        address _tokenToPayback,
        uint256 _shareAmountToPay
    )
        external
        view
    {
        (
            uint256 weightedCollateralUSD,
            uint256 unweightedCollateralUSD

        ) = overallUSDCollateralsBoth(
            _nftIdLiquidate
        );

        uint256 borrowUSDTotal = overallUSDBorrowHeartbeat(
            _nftIdLiquidate
        );

        canLiquidate(
            borrowUSDTotal,
            weightedCollateralUSD
        );

        checkMaxShares(
            _nftIdLiquidate,
            _tokenToPayback,
            borrowUSDTotal,
            unweightedCollateralUSD,
            _shareAmountToPay
        );
    }

    /**
     * @dev Set function for preparing curve pools.
     */
    function prepareCurvePools(
        address _poolToken,
        CurveSwapStructData memory _curveSwapStructData,
        CurveSwapStructToken memory _curveSwapStructToken
    )
        external
        onlyWiseLending
    {
        curveSwapInfoData[_poolToken] = _curveSwapStructData;
        curveSwapInfoToken[_poolToken] = _curveSwapStructToken;

        address curvePool = curveSwapInfoData[_poolToken].curvePool;
        uint256 tokenIndexForApprove = _curveSwapStructToken.curvePoolTokenIndexFrom;

        _safeApprove(
            ICurve(curvePool).coins(tokenIndexForApprove),
            curvePool,
            0
        );

        _safeApprove(
            ICurve(curvePool).coins(tokenIndexForApprove),
            curvePool,
            UINT256_MAX
        );

        address curveMetaPool = curveSwapInfoData[_poolToken].curveMetaPool;

        if (curveMetaPool == ZERO_ADDRESS) {
            return;
        }

        tokenIndexForApprove = _curveSwapStructToken.curveMetaPoolTokenIndexFrom;

        _safeApprove(
            ICurve(curveMetaPool).coins(tokenIndexForApprove),
            curveMetaPool,
            0
        );

        _safeApprove(
            ICurve(curveMetaPool).coins(tokenIndexForApprove),
            curveMetaPool,
            UINT256_MAX
        );
    }

    /**
     * @dev Reentrency guard for curve pools. Forces
     * a swap to update internal curve values.
     */
    function curveSecurityCheck(
        address _poolToken
    )
        external
        onlyWiseLending
    {
        address curvePool = curveSwapInfoData[_poolToken].curvePool;

        if (curvePool == ZERO_ADDRESS) {
            return;
        }

        (
            bool success
            ,
        ) = curvePool.call{value: 0} (
            curveSwapInfoData[_poolToken].swapBytesPool
        );

        _checkSuccess(
            success
        );

        address curveMeta = curveSwapInfoData[_poolToken].curveMetaPool;

        if (curveMeta == ZERO_ADDRESS) {
            return;
        }

        (
            success
            ,
        ) = curveMeta.call{value: 0} (
            curveSwapInfoData[_poolToken].swapBytesMeta
        );

        _checkSuccess(
            success
        );
    }

    /**
     * @dev Checks for withdraw logic.
     */
    function checksWithdraw(
        uint256 _nftId,
        address _caller,
        address _poolToken,
        uint256 _amount
    )
        external
        view
    {
        if (_checkConditions(_poolToken) == true) {

            if (_overallUSDBorrowBare(_nftId) > 0) {
                revert OpenBorrowPosition();
            }

            return;
        }

        if (_caller == AAVE_HUB) {
            return;
        }

        if (WISE_LENDING.verifiedIsolationPool(_caller) == true) {
            return;
        }

        _checkPositionLocked(
            _nftId
        );

        if (_isUncollateralized(_nftId, _poolToken) == true) {
            return;
        }

        checkBorrowLimit(
            _nftId,
            _poolToken,
            _amount
        );
    }

    /**
     * @dev Checks for solely withdraw logic.
     */
    function checksSolelyWithdraw(
        uint256 _nftId,
        address _caller,
        address _poolToken,
        uint256 _amount
    )
        external
        view
    {
        if (_checkConditions(_poolToken) == true) {

            if (_overallUSDBorrowBare(_nftId) > 0) {
                revert OpenBorrowPosition();
            }

            return;
        }

        if (_caller == AAVE_HUB) {
            return;
        }

        _checkPositionLocked(
            _nftId
        );

        checkBorrowLimit(
            _nftId,
            _poolToken,
            _amount
        );
    }

    /**
     * @dev Checks for borrow logic.
     */
    function checksBorrow(
        uint256 _nftId,
        address _caller,
        address _poolToken,
        uint256 _amount
    )
        external
        view
    {
        _tokenChecks(
            _poolToken
        );

        checkTokenAllowed(
            _poolToken
        );

        if (WISE_LENDING.verifiedIsolationPool(_caller) == true) {
            return;
        }

        if (_caller == AAVE_HUB) {
            return;
        }

        _checkPositionLocked(
            _nftId
        );

        _checkBorrowPossible(
            _nftId,
            _poolToken,
            _amount
        );
    }

    /**
     * @dev Checks for payback with lending
     * shares logic.
     */
    function checkPaybackLendingShares(
        uint256 _nftIdReceiver,
        uint256 _nftIdCaller,
        address _caller,
        address _poolToken,
        uint256 _amount
    )
        external
        view
    {
        checkOwnerPosition(
            _nftIdCaller,
            _caller
        );

        _checkPositionLocked(
            _nftIdReceiver
        );

        _checkPositionLocked(
            _nftIdCaller
        );

        if (_isUncollateralized(_nftIdCaller, _poolToken) == true) {
            return;
        }

        checkBorrowLimit(
            _nftIdCaller,
            _poolToken,
            _amount
        );
    }

    /**
     * @dev Checks for collateralize deposit logic.
     */
    function checksCollateralizeDeposit(
        uint256 _nftId,
        address _caller,
        address _poolAddress
    )
        external
        view
    {
        if (checkHeartbeat(_poolAddress) == false) {
            revert ChainlinkDead();
        }

        checkOwnerPosition(
            _nftId,
            _caller
        );
    }

    /**
     * @dev Checks for uncollateralized deposit logic.
     */
    function checkUncollateralizedDeposit(
        uint256 _nftId,
        address _poolToken
    )
        external
        view
    {
        if (_checkConditions(_poolToken) == true) {

            if (_overallUSDBorrowBare(_nftId) > 0) {
                revert OpenBorrowPosition();
            }

            return;
        }

        checkBorrowLimit({
            _nftId: _nftId,
            _poolToken: _poolToken,
            _amount: 0
        });
    }

    /**
     * @dev Checks for bad debt logic. Compares
     * total USD of borrow and collateral.
     */
    function checkBadDebt(
        uint256 _nftId
    )
        external
        onlyWiseLending
    {

        uint256 bareCollateral = overallUSDCollateralsBare(
            _nftId
        );

        uint256 totalBorrow = _overallUSDBorrowBare(
            _nftId
        );

        if (totalBorrow < bareCollateral) {
            return;
        }

        uint256 diff = totalBorrow
            - bareCollateral;

        FEE_MANAGER.increaseTotalBadDebtLiquidation(
            diff
        );

        FEE_MANAGER.setBadDebtUserLiquidation(
            _nftId,
            diff
        );
    }

    /**
     * @dev View function returning weighted
     * supply APY of a postion. 1% <=> 1E16
     */
    function overallLendingAPY(
        uint256 _nftId
    )
        external
        view
        returns (uint256)
    {
        uint256 len = WISE_LENDING.getPositionLendingTokenLength(
            _nftId
        );

        if (len == 0) {
            return 0;
        }

        uint8 i;
        address token;
        uint256 amount;
        uint256 usdValue;
        uint256 overallUSD;
        uint256 weightedRate;

        for (i = 0; i < len; ++i) {

            token = WISE_LENDING.getPositionLendingTokenByIndex(
                _nftId,
                i
            );

            amount = getPositionLendingAmount(
                _nftId,
                token
            );

            usdValue = WISE_ORACLE.getTokensInUSD(
                token,
                amount
            );

            weightedRate += usdValue
                * getLendingRate(token);

            overallUSD += usdValue;
        }

        return weightedRate
            / overallUSD;
    }

    /**
     * @dev View function returning weighted
     * borrow APY of a postion. 1% <=> 1E16
     */
    function overallBorrowAPY(
        uint256 _nftId
    )
        external
        view
        returns (uint256)
    {
        uint256 len = WISE_LENDING.getPositionBorrowTokenLength(
            _nftId
        );

        if (len == 0) {
            return 0;
        }

        uint8 i;
        address token;
        uint256 amount;
        uint256 usdValue;
        uint256 overallUSD;
        uint256 weightedRate;

        for (i = 0; i < len; ++i) {

            token = WISE_LENDING.getPositionBorrowTokenByIndex(
                _nftId,
                i
            );

            amount = getPositionBorrowAmount(
                _nftId,
                token
            );

            usdValue = WISE_ORACLE.getTokensInUSD(
                token,
                amount
            );

            weightedRate += usdValue
                * getBorrowRate(token);

            overallUSD += usdValue;
        }

        return weightedRate
            / overallUSD;
    }

    /**
     * @dev View function returning the total
     * net APY of a postion. 1% <=> 1E16
     */
    function overallNetAPY(
        uint256 _nftId
    )
        external
        view
        returns (uint256, bool)
    {
        uint8 i;
        address token;
        uint256 usdValue;
        uint256 usdValueDebt;
        uint256 usdValueGain;
        uint256 totalUsdSupply;

        uint256 netAPY;

        uint256 lenBorrow = WISE_LENDING.getPositionBorrowTokenLength(
            _nftId
        );

        uint256 lenDeposit = WISE_LENDING.getPositionLendingTokenLength(
            _nftId
        );

        for (i = 0; i < lenBorrow; ++i) {

            token = WISE_LENDING.getPositionBorrowTokenByIndex(
                _nftId,
                i
            );

            usdValue = getUSDBorrow(
                _nftId,
                token
            );

            usdValueDebt += usdValue
                * getBorrowRate(token);
        }

        for (i = 0; i < lenDeposit; ++i) {

            token = WISE_LENDING.getPositionLendingTokenByIndex(
                _nftId,
                i
            );

            usdValue = getUSDCollateral(
                _nftId,
                token
            );

            totalUsdSupply += usdValue;
            usdValueGain += usdValue
                * getLendingRate(token);
        }

        if (usdValueGain >= usdValueDebt) {

            netAPY = (usdValueGain - usdValueDebt)
                / totalUsdSupply;

            return (netAPY, false);
        }

        netAPY = (usdValueDebt - usdValueGain)
                / totalUsdSupply;

        return (netAPY, true);
    }

    /**
     * @dev View function claculating the open
     * amount a postion is allowed to borrow.
     */
    function safeLimitPosition(
        uint256 _nftId
    )
        external
        view
        returns (uint256)
    {
        uint256 len = WISE_LENDING.getPositionLendingTokenLength(
            _nftId
        );

        if (len == 0) {
            return 0;
        }

        uint256 i;
        address token;
        uint256 buffer;

        for (i = 0; i < len; ++i) {

            token = WISE_LENDING.getPositionLendingTokenByIndex(
                _nftId,
                i
            );

            if (checkHeartbeat(token) == false) {
                continue;
            }

            if (wasBlacklisted[token] == true) {
                continue;
            }

            buffer += WISE_LENDING.lendingPoolData(token).collateralFactor
                * getFullCollateralUSD(
                    _nftId,
                    token
                ) / PRECISION_FACTOR_E18;
        }

        return buffer
            * borrowPercentageCap
            / PRECISION_FACTOR_E18;
    }

    /**
     * @dev View function checking if the postion is
     * locked due to blacklisted token or token which
     * chainlink oracles are dead a.k.a having no
     * heartbeat.
     */
    function positionLocked(
        uint256 _nftId
    )
        external
        view
        returns (bool, address)
    {
        uint256 len = WISE_LENDING.getPositionLendingTokenLength(
            _nftId
        );

        uint256 i;
        address token;

        for (i = 0; i < len; ++i) {

            token = WISE_LENDING.getPositionLendingTokenByIndex(
                _nftId,
                i
            );

            if (_checkConditions(token) == true) {
                return (
                    true,
                    token
                );
            }
        }

        uint256 lenBorrow = WISE_LENDING.getPositionBorrowTokenLength(
            _nftId
        );

        for (i = 0; i < lenBorrow; ++i) {

            token = WISE_LENDING.getPositionBorrowTokenByIndex(
                _nftId,
                i
            );

            if (_checkConditions(token) == true) {
                return (
                    true,
                    token
                );
            }
        }

        return (
            false,
            ZERO_ADDRESS
        );
    }

    /**
     * @dev View function extrapolating the
     * possible withdraw amount of a postion
     * for a specific _poolToken.
     */
    function maximumWithdrawToken(
        uint256 _nftId,
        address _poolToken,
        uint256 _interval,
        uint256 _solelyWithdrawAmount
    )
        external
        view
        returns (uint256)
    {
        uint256 withdrawAmount;

        uint256 expectedMaxAmount = getExpectedLendingAmount(
            _nftId,
            _poolToken,
            _interval
        );

        uint256 maxAmountPool = WISE_LENDING.getTotalPool(
            _poolToken
        );

        withdrawAmount = expectedMaxAmount;

        if (expectedMaxAmount > maxAmountPool) {
            withdrawAmount = maxAmountPool;
        }

        if (_isUncollateralized(_nftId, _poolToken) == true) {
            return withdrawAmount;
        }

        uint256 possibelWithdraw = _getPossibleWithdrawAmount(
            _nftId,
            _poolToken,
            _interval
        );

        withdrawAmount = possibelWithdraw;

        if (possibelWithdraw > expectedMaxAmount) {
            withdrawAmount = expectedMaxAmount;
        }

        if (_solelyWithdrawAmount >= withdrawAmount) {
            return 0;
        }

        withdrawAmount = withdrawAmount - _solelyWithdrawAmount;

        if (withdrawAmount > maxAmountPool) {
            return maxAmountPool;
        }

        return withdrawAmount;
    }

    /**
     * @dev View function extrapolating the
     * possible withdraw amount of a private
     * postion for a specific _poolToken.
     */
    function maximumWithdrawTokenSolely(
        uint256 _nftId,
        address _poolToken,
        uint256 _interval,
        uint256 _poolWithdrawAmount
    )
        external
        view
        returns (uint256)
    {
        uint256 tokenAmount = _getPossibleWithdrawAmount(
            _nftId,
            _poolToken,
            _interval
        );

        if (_isUncollateralized(_nftId, _poolToken) == false) {

            if (_poolWithdrawAmount >= tokenAmount) {
                return 0;
            }

            tokenAmount = tokenAmount - _poolWithdrawAmount;
        }

        uint256 maxSolelyAmount = WISE_LENDING.getPureCollateralAmount(
            _nftId,
            _poolToken
        );

        if (tokenAmount > maxSolelyAmount) {
            return maxSolelyAmount;
        }

        return tokenAmount;
    }

    /**
     * @dev View function extrapolating the
     * possible borrow amount of postion for
     * a specific _poolToken.
     */
    function maximumBorrowToken(
        uint256 _nftId,
        address _poolToken,
        uint256 _interval
    )
        external
        view
        returns (uint256 tokenAmount)
    {
        uint256 term = _overallUSDCollateralsWeighted(_nftId, _interval)
            * borrowPercentageCap
            / PRECISION_FACTOR_E18;

        uint256 borrowUSD = term
            - _overallUSDBorrow(
                _nftId,
                _interval
            );

        tokenAmount = WISE_ORACLE.getTokensFromUSD(
            _poolToken,
            borrowUSD
        );

        uint256 maxPoolAmount = WISE_LENDING.getTotalPool(
            _poolToken
        );

        if (tokenAmount > maxPoolAmount) {
            tokenAmount = maxPoolAmount;
        }
    }

    /**
     * @dev View function extrapolating the
     * possible payback amount of a position
     * for a specific _poolToken.
     */
    function getExpectedPaybackAmount(
        uint256 _nftId,
        address _poolToken,
        uint256 _interval
    )
        external
        view
        returns (uint256)
    {
        uint256 borrowShares = WISE_LENDING.getPositionBorrowShares(
            _nftId,
            _poolToken
        );

        uint256 currentTotalBorrowShares = WISE_LENDING.getTotalBorrowShares(
            _poolToken
        );

        if (currentTotalBorrowShares == 0) {
            return 0;
        }

        uint256 updatedPseudo = _getUpdatedPseudoBorrow(
            _poolToken,
            _interval
        );

        return borrowShares
            * updatedPseudo
            / currentTotalBorrowShares;
    }

    /**
     * @dev View function extrapolating the
     * possible lending amount of a position
     * for a specific _poolToken.
     */
    function getExpectedLendingAmount(
        uint256 _nftId,
        address _poolToken,
        uint256 _interval
    )
        public
        view
        returns (uint256)
    {
        uint256 lendingShares = WISE_LENDING.getPositionLendingShares(
            _nftId,
            _poolToken
        );

        uint256 currentTotalLendingShares = WISE_LENDING.getTotalDepositShares(
            _poolToken
        );

        if (currentTotalLendingShares == 0) {
            return 0;
        }

        uint256 updatedPseudo = _getUpdatedPseudoPool(
            _poolToken,
            _interval
        );

        return lendingShares
            * updatedPseudo
            / currentTotalLendingShares;
    }

    /**
     * @dev Set function for blacklisting token.
     * Those token can not be borrowed our used as
     * collateral anymore. Only callable by master.
     */
    function setBlacklistToken(
        address _tokenAddress,
        bool _state
    )
        external
        onlyMaster()
    {
        wasBlacklisted[_tokenAddress] = _state;
    }
}
