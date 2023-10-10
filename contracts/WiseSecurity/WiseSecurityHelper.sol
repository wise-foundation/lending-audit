// SPDX-License-Identifier: -- WISE --
pragma solidity =0.8.21;

import "./WiseSecurityDeclarations.sol";

abstract contract WiseSecurityHelper is WiseSecurityDeclarations {

    /**
     * @dev Read function returning weighted and
     * and unweighted total collateral of a
     * postion with {_nftId} (unweighted means
     * collateral factor equals 1E18).
     */
    function overallUSDCollateralsBoth(
        uint256 _nftId
    )
        public
        view
        returns (uint256, uint256)
    {
        uint256 amount;
        uint256 weightedTotal;
        uint256 unweightedAmount;
        address tokenAddress;

        for (uint256 i = 0; i < WISE_LENDING.getPositionLendingTokenLength(_nftId); ++i) {

            tokenAddress = WISE_LENDING.getPositionLendingTokenByIndex(
                _nftId,
                i
            );

            if (checkHeartbeat(tokenAddress) == false) {
                revert ChainlinkDead();
            }

            amount = getFullCollateralUSD(
                _nftId,
                tokenAddress
            );

            weightedTotal += amount
                * WISE_LENDING.lendingPoolData(tokenAddress).collateralFactor
                / PRECISION_FACTOR_E18;

            unweightedAmount += amount;
        }

        return (
            weightedTotal,
            unweightedAmount
        );
    }

    /**
     * @dev Read function returning weighted
     *  total collateral of a postion with {_nftId}.
     */
    function overallUSDCollateralsWeighted(
        uint256 _nftId
    )
        public
        view
        returns (uint256 weightedTotal)
    {
        address tokenAddress;

        for (uint256 i = 0; i < WISE_LENDING.getPositionLendingTokenLength(_nftId); ++i) {

            tokenAddress = WISE_LENDING.getPositionLendingTokenByIndex(
                _nftId,
                i
            );

            _tokenChecks(
                tokenAddress
            );

            weightedTotal += WISE_LENDING.lendingPoolData(tokenAddress).collateralFactor
                * getFullCollateralUSD(
                    _nftId,
                    tokenAddress
                ) / PRECISION_FACTOR_E18;
        }
    }

    /**
     * @dev Read function returning unweighted
     *  total collateral of a postion with {_nftId}
     * (unweighted means collateral factor equals 1E18).
     */
    function overallUSDCollateralsBare(
        uint256 _nftId
    )
        public
        view
        returns (uint256 amount)
    {
        address tokenAddress;

        for (uint256 i = 0; i < WISE_LENDING.getPositionLendingTokenLength(_nftId); ++i) {

            tokenAddress = WISE_LENDING.getPositionLendingTokenByIndex(
                _nftId,
                i
            );

            if (checkHeartbeat(tokenAddress) == false) {
                revert ChainlinkDead();
            }

            amount += getFullCollateralUSD(
                _nftId,
                tokenAddress
            );
        }
    }

    /**
     * @dev Internal calculation function returning
     * the updated weighted collateral amount of a
     * postion with {_nftId}. Result can be
     * extrapolated linear with length {_interval}.
     */
    function _overallUSDCollateralsWeighted(
        uint256 _nftId,
        uint256 _interval
    )
        internal
        view
        returns (uint256 weightedTotal)
    {
        uint256 i;
        address tokenAddress;

        for (i = 0; i < WISE_LENDING.getPositionLendingTokenLength(_nftId); ++i) {

            tokenAddress = WISE_LENDING.getPositionLendingTokenByIndex(
                _nftId,
                i
            );

            _tokenChecks(
                tokenAddress
            );

            weightedTotal += WISE_LENDING.lendingPoolData(tokenAddress).collateralFactor
                * _getCollateralOfTokenUSDUpdated(
                    _nftId,
                    tokenAddress,
                    _interval
                ) / PRECISION_FACTOR_E18;
        }
    }

    /**
     * @dev Read function returning the full bare
     * collateral amount of a {_poolToken} from a
     * {_nftId}. Full means sum of private and
     * public added funds.
     */
    function getFullCollateralUSD(
        uint256 _nftId,
        address _poolToken
    )
        public
        view
        returns (uint256 usdCollateral)
    {
        usdCollateral = WISE_ORACLE.getTokensInUSD(
            _poolToken,
            WISE_LENDING.getPureCollateralAmount(
                _nftId,
                _poolToken
            )
        );

        if (_isDecollateralized(_nftId, _poolToken) == true) {
            return usdCollateral;
        }

        usdCollateral += getUSDCollateral(
            _nftId,
            _poolToken
        );
    }

    /**
     * @dev Wrapper function checking if a supplied
     * fund is decollateralized.
     */
    function _isDecollateralized(
        uint256 _nftId,
        address _poolToken
    )
        internal
        view
        returns (bool)
    {
        return WISE_LENDING.isDecollteralized(
            _nftId,
            _poolToken
        );
    }

    /**
     * @dev Read function returning the full
     * collateral amount of a {_poolToken} from a
     * {_nftId} updated to current values.
     * Full means sum of private and public added
     * funds. Can be extrapolated linear within
     * {_interval}.
     */
    function _getCollateralOfTokenUSDUpdated(
        uint256 _nftId,
        address _poolToken,
        uint256 _interval
    )
        internal
        view
        returns (uint256 usdCollateral)
    {
        usdCollateral = WISE_ORACLE.getTokensInUSD(
            _poolToken,
            WISE_LENDING.getPureCollateralAmount(
                _nftId,
                _poolToken
            )
        );

        if (_isDecollateralized(_nftId, _poolToken) == true) {
            return usdCollateral;
        }

        usdCollateral += getUSDCollateralUpdated(
            _nftId,
            _poolToken,
            _interval
        );
    }

    /**
     * @dev Read function returning the full
     * (private and public) collateral amount
     * of a {_poolToken} from a {_nftId} updated
     * to current values. Can be extrapolated
     * linear within {_interval}.
     */
    function getUSDCollateralUpdated(
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

        if (lendingShares == 0) {
            return 0;
        }

        uint256 currentTotalLendingShares = WISE_LENDING.getTotalDepositShares(
            _poolToken
        );

        uint256 updatedPseudo = _getUpdatedPseudoPool(
            _poolToken,
            _interval
        );

        uint256 updatedToken = lendingShares
            * updatedPseudo
            / currentTotalLendingShares;

        return WISE_ORACLE.getTokensInUSD(
            _poolToken,
            updatedToken
        );
    }

    /**
     * @dev Read function returning the public
     * collateral amount of a {_poolToken} from a
     * {_nftId}.
     */
    function getUSDCollateral(
        uint256 _nftId,
        address _poolToken
    )
        public
        view
        returns (uint256)
    {
        return WISE_ORACLE.getTokensInUSD(
            _poolToken,
            getPositionLendingAmount(
                _nftId,
                _poolToken
            )
        );
    }

    /**
     * @dev Read function returning the total
     * borrow amount of a postion with {_nftId}.
     * No heartbeat or blacklisted checks are
     * included in this function!
     */
    function _overallUSDBorrowBare(
        uint256 _nftId
    )
        internal
        view
        returns (uint256 buffer)
    {
        uint256 l = WISE_LENDING.getPositionBorrowTokenLength(
            _nftId
        );

        for (uint256 i = 0; i < l; ++i) {

            buffer += getUSDBorrow(
                _nftId,
                WISE_LENDING.getPositionBorrowTokenByIndex(
                    _nftId,
                    i
                )
            );
        }
    }

    /**
     * @dev Read function returning the total
     * borrow amount of a postion with {_nftId}.
     * No blacklisted check is included
     * in this function!
     */
    function overallUSDBorrowHeartbeat(
        uint256 _nftId
    )
        public
        view
        returns (uint256 buffer)
    {
        address tokenAddress;

        uint256 l = WISE_LENDING.getPositionBorrowTokenLength(
            _nftId
        );

        for (uint256 i = 0; i < l; ++i) {

            tokenAddress = WISE_LENDING.getPositionBorrowTokenByIndex(
                _nftId,
                i
            );

            if (checkHeartbeat(tokenAddress) == false) {
                revert ChainlinkDead();
            }

            buffer += getUSDBorrow(
                _nftId,
                tokenAddress
            );
        }
    }

    /**
     * @dev Read function returning the total
     * borrow amount of a postion with {_nftId}.
     */
    function overallUSDBorrow(
        uint256 _nftId
    )
        public
        view
        returns (uint256 buffer)
    {
        uint256 i;
        address tokenAddress;

        uint256 l = WISE_LENDING.getPositionBorrowTokenLength(
            _nftId
        );

        for (i = 0; i < l; ++i) {

            tokenAddress = WISE_LENDING.getPositionBorrowTokenByIndex(
                _nftId,
                i
            );

            _tokenChecks(
                tokenAddress
            );

            buffer += getUSDBorrow(
                _nftId,
                tokenAddress
            );
        }
    }

    /**
     * @dev Internal function combining hearbeat
     * and blacklisted checks.
     */
    function _checkConditions(
        address _poolToken
    )
        internal
        view
        returns (bool)
    {
        return checkHeartbeat(_poolToken) == false
            || wasBlacklisted[_poolToken] == true;
    }

    /**
     * @dev Read function returning the total
     * updated current borrow amount of a
     * postion with {_nftId}. Can be
     * extrapolated linear with {_intervall}.
     */
    function _overallUSDBorrow(
        uint256 _nftId,
        uint256 _interval
    )
        internal
        view
        returns (uint256 buffer)
    {
        uint256 i;
        address tokenAddress;

        uint256 l = WISE_LENDING.getPositionBorrowTokenLength(
            _nftId
        );

        for (i = 0; i < l; ++i) {

            tokenAddress = WISE_LENDING.getPositionBorrowTokenByIndex(
                _nftId,
                i
            );

            _tokenChecks(
                tokenAddress
            );

            buffer += _getUSDBorrowUpdated(
                _nftId,
                tokenAddress,
                _interval
            );
        }
    }

    /**
     * @dev Internal function calculating
     * the updated pseudo borrow amount of
     * {_poolToken}. Result can be extrapolated
     * linear with {_interval}.
     */
    function _getUpdatedPseudoBorrow(
        address _poolToken,
        uint256 _interval
    )
        internal
        view
        returns (uint256)
    {
        uint256 currentPseudo = WISE_LENDING.getPseudoTotalBorrowAmount(
            _poolToken
        );

        return _getInterest(
            _poolToken,
            _interval
        ) + currentPseudo;
    }

    /**
     * @dev Internal function calculating
     * the updated pseudo lending amount of
     * {_poolToken}. Result can be extrapolated
     * linear with {_interval}.
     */
    function _getUpdatedPseudoPool(
        address _poolToken,
        uint256 _interval
    )
        internal
        view
        returns (uint256)
    {
        uint256 currentPseudo = WISE_LENDING.getPseudoTotalPool(
            _poolToken
        );

        return _getInterest(_poolToken, _interval)
            * (PRECISION_FACTOR_E18 - WISE_LENDING.globalPoolData(_poolToken).poolFee)
            / PRECISION_FACTOR_E18
            + currentPseudo;
    }

    /**
     * @dev Internal math function calculating
     * the accumulated interest amount for
     * {_poolToken}. Result can be extrapolated
     * linear with {_interval}.
     */
    function _getInterest(
        address _poolToken,
        uint256 _interval
    )
        internal
        view
        returns (uint256)
    {
        BorrowPoolEntry memory borrowPoolData = WISE_LENDING.borrowPoolData(
            _poolToken
        );

        uint256 timeInterval = _interval
            + block.timestamp
            - WISE_LENDING.getTimeStamp(_poolToken);

        uint256 rate = timeInterval
            * borrowPoolData.borrowRate
            * WISE_LENDING.getPseudoTotalBorrowAmount(_poolToken)
            / PRECISION_FACTOR_E18
            / ONE_YEAR;

        return rate;
    }

    /**
     * @dev Read function returning the full
     * borrow amount of a {_poolToken} from a
     * {_nftId} updated to current values.
     * Can be extrapolated linear within
     * {_interval}.
     */
    function _getUSDBorrowUpdated(
        uint256 _nftId,
        address _poolToken,
        uint256 _intervall
    )
        internal
        view
        returns (uint256)
    {
        uint256 borrowShares = WISE_LENDING.getPositionBorrowShares(
            _nftId,
            _poolToken
        );

        if (borrowShares == 0) {
            return 0;
        }

        uint256 currentTotalBorrowShares = WISE_LENDING.getTotalBorrowShares(
            _poolToken
        );

        uint256 updatesPseudo = _getUpdatedPseudoBorrow(
            _poolToken,
            _intervall
        );

        uint256 updatedToken = borrowShares
            * updatesPseudo
            / currentTotalBorrowShares;

        return WISE_ORACLE.getTokensInUSD(
            _poolToken,
            updatedToken
        );
    }

    /**
     * @dev Read function returning the borow
     * amount of a {_poolToken} from a {_nftId}.
     */
    function getUSDBorrow(
        uint256 _nftId,
        address _poolToken
    )
        public
        view
        returns (uint256)
    {
        return WISE_ORACLE.getTokensInUSD(
            _poolToken,
            getPositionBorrowAmount(
                _nftId,
                _poolToken
            )
        );
    }

    /**
     * @dev Read function checking if
     * {_poolToken} is allowed to borrow.
     */
    function checkTokenAllowed(
        address _poolAddress
    )
        public
        view
    {
        if (WISE_LENDING.borrowPoolData(_poolAddress).allowBorrow == false) {
            revert NotAllowedToBorrow();
        }
    }

    /**
     * @dev Check if chainLink feed was
     * updated within expected timeframe
     */
    function checkHeartbeat(
        address _poolToken
    )
        public
        view
        returns (bool)
    {
        if (WISE_ORACLE.chainLinkIsDead(_poolToken) == true) {
            return false;
        }

        return true;
    }

    /**
     * @dev Check if the postion with
     * {_nftId} is locked for interactions.
     */
    function _checkPositionLocked(
        uint256 _nftId
    )
        internal
        view
    {
        if (WISE_LENDING.positionLocked(_nftId) == true) {
            revert PositionLocked();
        }
    }

    /**
     * @dev Wrapper function for external
     * {_checkMaxFee} call.
     */
    function checkMaxFee(
        uint256 _paybackUSD,
        uint256 _feeLiquidation,
        uint256 _maxFeeUSD
    )
        external
        pure
        returns (uint256)
    {
        return _checkMaxFee(
            _paybackUSD,
            _feeLiquidation,
            _maxFeeUSD
        );
    }

    /**
     * @dev Returning the possible fee
     * for liquidation.
     */
    function _checkMaxFee(
        uint256 _paybackUSD,
        uint256 _liquidationFee,
        uint256 _maxFeeUSD
    )
        internal
        pure
        returns (uint256)
    {
        uint256 feeUSD = _paybackUSD
            * _liquidationFee
            / PRECISION_FACTOR_E18;

        return feeUSD < _maxFeeUSD
            ? feeUSD
            : _maxFeeUSD;
    }

    /**
     * @dev Math function computing the
     * percentage of the receiving token
     * which the liquidator receivs for
     * liquidation.
     */
    function calculateWishPercentage(
        uint256 _nftId,
        address _receiveToken,
        uint256 _paybackUSD,
        uint256 _maxFeeUSD,
        uint256 _baseRewardLiquidation
    )
        external
        view
        returns (uint256)
    {
        uint256 feeUSD = _checkMaxFee(
            _paybackUSD,
            _baseRewardLiquidation,
            _maxFeeUSD
        );

        return (feeUSD + _paybackUSD)
            * PRECISION_FACTOR_E18
            / getFullCollateralUSD(
                _nftId,
                _receiveToken
            );
    }

    /**
     * @dev Check function for withdraw flow.
     * Tests if debt ratio is not greater than
     * 100% after withdraw of {_poolToken} for
     * {_amount}.
     */
    function checkBorrowLimit(
        uint256 _nftId,
        address _poolToken,
        uint256 _amount
    )
        public
        view
    {
        uint256 borrowAmount = overallUSDBorrow(
            _nftId
        );

        if (borrowAmount == 0) {
            return;
        }

        uint256 withdrawValue = WISE_ORACLE.getTokensInUSD(
            _poolToken,
            _amount
        )
            * WISE_LENDING.lendingPoolData(_poolToken).collateralFactor
            / PRECISION_FACTOR_E18;

        bool state = borrowPercentageCap
            * (overallUSDCollateralsWeighted(_nftId) - withdrawValue)
            / PRECISION_FACTOR_E18
            < borrowAmount;

        if (state == true) {
            revert ResultsInBadDebt();
        }
    }

    /**
     * @dev Check function for borrow flow.
     * Tests if debt ratio is not greater than
     * 100% after borrow of {_poolToken} for
     * {_amount}.
     */
    function _checkBorrowPossible(
        uint256 _nftId,
        address _poolToken,
        uint256 _amount
    )
        internal
        view
    {
        uint256 borrowValue = WISE_ORACLE.getTokensInUSD(
            _poolToken,
            _amount
        );

        bool state = borrowPercentageCap
            * overallUSDCollateralsWeighted(_nftId)
            / PRECISION_FACTOR_E18
            < overallUSDBorrow(_nftId) + borrowValue;

        if (state == true) {
            revert NotEnoughCollateral();
        }
    }

    /**
     * @dev Check function for registration
     * of power farms. User can only register
     * when the postion is empty!
     */
    function checksRegister(
        uint256 _nftId,
        address _caller
    )
        public
        view
    {
        checkOwnerPosition(
            _nftId,
            _caller
        );

        if (overallUSDCollateralsWeighted(_nftId) > 0) {
            revert NotAllowedWiseSecurity();
        }
    }

    /**
     * @dev Pure math function comparing
     * borrow and collateral amount for
     * liquidation.
     */
    function canLiquidate(
        uint256 _borrowUSDTotal,
        uint256 _weightedCollateralUSD
    )
        public
        pure
    {
        if (_borrowUSDTotal < _weightedCollateralUSD) {
            revert LiquidationDenied();
        }
    }

    /**
     * @dev Helper function for liquidation checking
     * return amount of receiving shares for liquidator.
     * Has to be smaller 50% when no bad debt occurs.
     */
    function checkMaxShares(
        uint256 _nftId,
        address _tokenToPayback,
        uint256 _borrowUSDTotal,
        uint256 _unweightedCollateralUSD,
        uint256 _shareAmountToPay
    )
        public
        view
    {
        uint256 totalSharesUser = WISE_LENDING.getPositionBorrowShares(
            _nftId,
            _tokenToPayback
        );

        uint256 maxShares = checkBadDebtThreshold(_borrowUSDTotal, _unweightedCollateralUSD)
            ? totalSharesUser
            : totalSharesUser * MAX_LIQUIDATION_50 / PRECISION_FACTOR_E18;

        if (_shareAmountToPay <= maxShares) {
            return;
        }

        revert TooManyShares();
    }

    /**
     * @dev Helper function for liquidation checking
     * if postion has bad debt.
     */
    function checkBadDebtThreshold(
        uint256 _borrowUSDTotal,
        uint256 _unweightedCollateral
    )
        public
        pure
        returns (bool)
    {
        return _borrowUSDTotal * PRECISION_FACTOR_E18
            >= _unweightedCollateral * BAD_DEBT_THRESHOLD;
    }

    /**
     * @dev Helper function computing lending
     * token amount for {_poolToken}.
     */
    function getPositionLendingAmount(
        uint256 _nftId,
        address _poolToken
    )
        public
        view
        returns (uint256)
    {
        return WISE_LENDING.cashoutAmount(
            _poolToken,
            WISE_LENDING.getPositionLendingShares(
                _nftId,
                _poolToken
            )
        );
    }

    /**
     * @dev Helper function computing borrow
     * token amount for {_poolToken}.
     */
    function getPositionBorrowAmount(
        uint256 _nftId,
        address _poolToken
    )
        public
        view
        returns (uint256)
    {
        return WISE_LENDING.paybackAmount(
            _poolToken,
            WISE_LENDING.getPositionBorrowShares(
                _nftId,
                _poolToken
            )
        );
    }

    /**
     * @dev Helper function checking the owner
     * of {_nftId}. Reverts if owner is invalid.
     */
    function checkOwnerPosition(
        uint256 _nftId,
        address _caller
    )
        public
        view
    {
        if (POSITION_NFTS.isOwner(
            _nftId,
            _caller
        ) == false) {
            revert NotOwner();
        }
    }

    /**
     * @dev Wrapper function returning the borrow
     * rate from pool with token {_poolToken}.
     */
    function getBorrowRate(
        address _poolToken
    )
        public
        view
        returns (uint256)
    {
        return WISE_LENDING.borrowPoolData(_poolToken).borrowRate;
    }

    /**
     * @dev View function returning the lending
     * rate from pool with token {_poolToken}.
     */
    function getLendingRate(
        address _poolToken
    )
        public
        view
        returns (uint256)
    {
        uint256 pseudoTotalPool = WISE_LENDING.getPseudoTotalPool(
            _poolToken
        );

        if (pseudoTotalPool == 0) {
            return 0;
        }

        uint256 adjustedRate = getBorrowRate(_poolToken)
            * (PRECISION_FACTOR_E18 - WISE_LENDING.globalPoolData(_poolToken).poolFee)
            / PRECISION_FACTOR_E18;

        return adjustedRate
            * WISE_LENDING.getPseudoTotalBorrowAmount(_poolToken)
            / pseudoTotalPool;
    }

    /**
     * @dev Internal helper function calculating
     * the possible withdraw amount of {_poolToken}
     * under current borrow and collateral amount
     * of {_nftId}.
     */
    function _getPossibleWithdrawAmount(
        uint256 _nftId,
        address _poolToken,
        uint256 _interval
    )
        internal
        view
        returns (uint256)
    {
        uint256 term = _overallUSDBorrow(_nftId, _interval)
            * PRECISION_FACTOR_E18
            / borrowPercentageCap;

        uint256 withdrawUSD = PRECISION_FACTOR_E18
            * (_overallUSDCollateralsWeighted(_nftId, _interval) - term)
            / WISE_LENDING.lendingPoolData(_poolToken).collateralFactor;

        return WISE_ORACLE.getTokensFromUSD(
            _poolToken,
            withdrawUSD
        );
    }

    /**
     * @dev Wrapper for {_checkConditions}.
     */
    function _tokenChecks(
        address _poolToken
    )
        internal
        view
    {
        if (_checkConditions(_poolToken) == true) {
            revert();
        }
    }

    /**
     * @dev Internal helper checking of success
     * for a low level byte call of a function
     * with {.call()}.
     */
    function _checkSuccess(
        bool _success
    )
        internal
        pure
    {
        if (_success == false) {
            revert SecuritySwapFaild();
        }
    }
}
