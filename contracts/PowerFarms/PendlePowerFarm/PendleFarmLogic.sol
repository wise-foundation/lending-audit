// SPDX-License-Identifier: -- WISE --

pragma solidity =0.8.21;

import "./PendleFarmSwapLogic.sol";

abstract contract PendleFarmLogic is PendleFarmSwapLogic {

    modifier onlyLockContract() {
        _onlyLockContract();
        _;
    }

    function _onlyLockContract()
        private
        view
    {
        if (msg.sender != address(LOCK_CONTRACT)) {
            revert NotLockerContract();
        }
    }

    modifier redeemPt() {
        _redeemContractPt();
        _;
    }

    function redeemContractPt()
        external
    {
        _redeemContractPt();
    }

    function _redeemContractPt()
        private
    {
        uint256 amount = _min(
            farmState.totalYtAmount,
            farmState.contractPtAmount
        );

        if (amount == 0) {

            _updateFarmState();
            _updateOracleValue(
                farmState.totalSyAmount
            );

            return;
        }

        uint256 syAmount = _redeemSwappedPT(
            amount
        );

        farmState.contractPtAmount -= amount;

        _exchangeSyToLp(
            syAmount
        );

        _updateFarmState();
        _updateOracleValue(
            farmState.totalSyAmount
        );
    }

    function updateFarmState()
        external
    {
        _updateFarmState();
    }

    function _updateFarmState()
        internal
    {
        MarketState memory marketState = LP_PENDLE.readState(
            msg.sender
        );

        uint256 currentPtAmount = _getTotalPtAmount(
            marketState
        );

        uint256 currentYtAmount = farmState.totalYtAmount;

        farmState.totalPtAmount = currentPtAmount
            + farmState.contractPtAmount;

        farmState.ptGreater = currentPtAmount > currentYtAmount;

        farmState.totalSyAmount = _updateSy(
            marketState,
            currentPtAmount,
            currentYtAmount
        );
    }

    function addCompoundSyAmount(
        uint256 _amount
    )
        external
        onlyLockContract
    {
        compoundSyAmount += _amount;
    }

    function mintHybridTokenSimpleExactToken(
        uint256 _desiredTokens
    )
        external
        redeemPt
        returns (
            uint256 syTransfer,
            uint256 transferAmountOverHang,
            bool ptGreater
        )
    {
        FarmState memory farmStateCache = farmState;

        uint256 totalSupply = HYBRID_TOKEN.totalSupply();

        ptGreater = farmStateCache.ptGreater == true;

        syTransfer = farmStateCache.totalSyAmount
            * _desiredTokens
            / totalSupply;

        transferAmountOverHang = ptGreater
            ? (farmStateCache.totalPtAmount - farmStateCache.totalYtAmount)
                * _desiredTokens
                / totalSupply
            : (farmStateCache.totalYtAmount - farmStateCache.totalPtAmount)
                * _desiredTokens
                / totalSupply;

        address overHangTokenAddress = farmStateCache.ptGreater == true
            ? PT_PENDLE_ADDRESS
            : YT_PENDLE_ADDRESS;

        ptGreater == true
            ? farmState.totalPtAmount += transferAmountOverHang
            : farmState.totalYtAmount += transferAmountOverHang;

        _safeTransferFrom(
            SY_PENDLE_ADDRESS,
            msg.sender,
            address(this),
            syTransfer
        );

        _safeTransferFrom(
            overHangTokenAddress,
            msg.sender,
            address(this),
            transferAmountOverHang
        );

        _handleMintZeroPriceImpact(
            msg.sender,
            _desiredTokens,
            syTransfer
        );

        _increaseOracleValue(
            syTransfer
        );

        _updateFarmState();
    }

    function mintHybridTokenUnderlying(
        uint256 _amount,
        uint256 _overhangFetched,
        bool _ptGreaterFetched,
        bytes calldata _dataFetched
    )
        external
        redeemPt
        returns (uint256)
    {
        _safeTransferFrom(
            WST_ETH_ADDRESS,
            msg.sender,
            address(this),
            _amount
        );

        return _depositPendleMint(
            _amount,
            _overhangFetched,
            msg.sender,
            _ptGreaterFetched,
            _dataFetched
        );
    }

    function _removeLpOverhangYt(
        uint256 _removeLp,
        uint256 _pyAmount,
        address _receiver
    )
        internal
    {
        (
            uint256 syOut,
            uint256 ptOut
        ) = LOCK_CONTRACT.burnLP(
            _removeLp,
            address(this)
        );

        farmState.totalLpAmount -= _removeLp;

        LOCK_CONTRACT.sendYT(
            ptOut + _pyAmount,
            address(this)
        );

        uint256 redeemAmount = _redeemPY(
            ptOut
        );

        _redeemSy(
            syOut + redeemAmount,
            _receiver
        );

        farmState.totalYtAmount -= _pyAmount;

        _updateFarmState();
    }

    function _removeLpOverhangPt(
        uint256 _removeLp,
        uint256 _pyAmount,
        address _receiver
    )
        internal
    {
        uint256 rescaledAmount = _removeLp
            * PRECISION_FACTOR_E18
            / _getSyToPtRatio();

        (
            uint256 syOut,
            uint256 ptOut
        ) = LOCK_CONTRACT.burnLP(
            rescaledAmount,
            address(this)
        );

        farmState.totalLpAmount -= rescaledAmount;
        farmState.contractPtAmount += ptOut
            - _pyAmount;

        _redeemSy(
            syOut,
            _receiver
        );

        _redeemContractPt();
    }

    function burnHybridTokenUnderlying(
        uint256 _amount
    )
        external
        redeemPt
        returns (
            uint256 wstEthAmount,
            uint256 pyAmount,
            bool ptGreater
        )
    {
        (
            wstEthAmount,
            pyAmount,
            ptGreater
        ) = _coreBurn(
            {
                _amount: _amount,
                _caller: msg.sender,
                _receiver: msg.sender
            }
        );

        _decreaseOracleValue(
            wstEthAmount
        );

        address sendToken = ptGreater == true
            ? PT_PENDLE_ADDRESS
            : YT_PENDLE_ADDRESS;

        _safeTransfer(
            sendToken,
            msg.sender,
            pyAmount
        );
    }

    function burnHybdriTokenIrreducibleETH(
        uint256 _amount,
        uint256 _minOutAmount
    )
        external
        redeemPt
        returns (
            uint256 ethAmount,
            uint256 pyAmount,
            bool ptGreater
        )
    {
        return _burnHybridTokenIrreducibleETH(
            _amount,
            _minOutAmount
        );
    }

    function _burnHybridTokenIrreducibleETH(
        uint256 _amount,
        uint256 _minOutAmount
    )
        internal
        redeemPt
        returns (
            uint256 ethAmount,
            uint256 pyAmount,
            bool ptGreater
        )
    {
        _handleBurnIrreducibleETH(
            _amount,
            _minOutAmount,
            msg.sender
        );

        return (
            ethAmount,
            pyAmount,
            ptGreater
        );
    }

    function _handleBurnIrreducibleETH(
        uint256 _amount,
        uint256 _minOutAmount,
        address _caller
    )
        internal
        returns (
            uint256 ethAmount,
            uint256 pyAmount,
            bool ptGreater
        )
    {
        uint256 wstEthAmount;

        (
            wstEthAmount,
            pyAmount,
            ptGreater
        ) = _coreBurn(
            {
                _amount: _amount,
                _caller: _caller,
                _receiver: address(this)
            }
        );

        _decreaseOracleValue(
            wstEthAmount
        );

        address sendToken = ptGreater == true
            ? PT_PENDLE_ADDRESS
            : YT_PENDLE_ADDRESS;

        ethAmount = _unwrapWstETH(
            wstEthAmount,
            _minOutAmount
        );

        _safeTransfer(
            sendToken,
            _caller,
            pyAmount
        );

        _sendValue(
            _caller,
            ethAmount
        );
    }

    function _coreBurn(
        uint256 _amount,
        address _caller,
        address _receiver
    )
        internal
        returns (
            uint256 syAmount,
            uint256 pyAmount,
            bool ptGreater
        )
    {
        (
            syAmount,
            pyAmount,
            ptGreater
        ) = _burnHybridToken(
            _amount,
            _caller
        );

        ptGreater == true
            ? _removeLpOverhangPt(
                syAmount,
                pyAmount,
                _receiver
            )
            : _removeLpOverhangYt(
                syAmount,
                pyAmount,
                _receiver
            );
    }

    function _burnHybridToken(
        uint256 _amount,
        address _receiver
    )
        internal
        returns (
            uint256,
            uint256,
            bool
        )
    {
        bool ptGreater = farmState.ptGreater;

        uint256 overhang = ptGreater == true
            ? farmState.totalPtAmount - farmState.totalYtAmount
            : farmState.totalYtAmount - farmState.totalPtAmount;

        uint256 percentage = _amount
            * PRECISION_FACTOR_E18
            / HYBRID_TOKEN.totalSupply();

        uint256 syAmount = farmState.totalSyAmount
            * percentage
            / PRECISION_FACTOR_E18;

        uint256 pyAmount = overhang
            * percentage
            / PRECISION_FACTOR_E18;

        HYBRID_TOKEN.burn(
            _receiver,
            _amount
        );

        return (
            syAmount,
            pyAmount,
            ptGreater
        );
    }

    function mintHybridTokenIrreducibleETH(
        uint256 _overhang,
        bool _ptGreater,
        bytes calldata _data
    )
        external
        payable
        returns (uint256)
    {
        return _mintHybridTokenIrreducible(
            msg.value,
            _overhang,
            _ptGreater,
            _data
        );
    }

    function mintHybridTokenIrreducible(
        uint256 _amount,
        uint256 _overhang,
        bool _ptGreater,
        bytes calldata _data
    )
        external
        redeemPt
        returns (uint256)
    {
        _safeTransferFrom(
            WETH_ADDRESS,
            msg.sender,
            address(this),
            _amount
        );

        _unwrapETH(
            _amount
        );

        return _mintHybridTokenIrreducible(
            _amount,
            _overhang,
            _ptGreater,
            _data
        );
    }

    function _getTotalPtAmount(
        MarketState memory _marketState
    )
        internal
        view
        returns (uint256)
    {
        return farmState.totalLpAmount
            * uint256(_marketState.totalPt)
            / LP_PENDLE.totalSupply();
    }

    function compoundFarm(
        bytes calldata _data,
        uint256 _overhangQueried,
        bool _ptGreater,
        bool _swapAllSy
    )
        external
        redeemPt
        onlyLockContract
    {
        uint256 currentPtAmount = farmState.totalPtAmount;
        uint256 currentYtAmount = farmState.totalYtAmount;

        bool ptGreater = farmState.ptGreater;

        if (_ptGreater != ptGreater) {
            revert OverhangChanged();
        }

        uint256 leftSyAmount = ptGreater == true
            ? _swapSyToYt(
                currentYtAmount - currentPtAmount,
                _overhangQueried,
                _data,
                _swapAllSy
            )
            : _swapSyToPt(
                currentPtAmount - currentYtAmount,
                _overhangQueried,
                _data,
                _swapAllSy
            );

        if (leftSyAmount == 0) {
            compoundSyAmount = 0;
            return;
        }

        _exchangeSyToLp(
            leftSyAmount
        );

        _updateFarmState();

        _updateOracleValue(
            farmState.totalSyAmount
        );

        compoundSyAmount = 0;
    }

    function _updateSy(
        MarketState memory _marketState,
        uint256 _ptAmount,
        uint256 _ytAmount
    )
        internal
        view
        returns (uint256)
    {
        uint256 additionalSy = _min(
            _ytAmount,
            _ptAmount
        );

        uint256 rescaled = additionalSy
            * PRECISION_FACTOR_E18
            / YT_PENDLE.pyIndexStored();

        return uint256(_marketState.totalSy)
            * farmState.totalLpAmount
            / LP_PENDLE.totalSupply()
            + rescaled;
    }

    function _updateOracleValue(
        uint256 _amount
    )
        internal
    {
        oracleSyAmount = _amount;
    }

    function _increaseOracleValue(
        uint256 _amount
    )
        internal
    {
        oracleSyAmount += _amount;
    }

    function _decreaseOracleValue(
        uint256 _amount
    )
        internal
    {
        if (_amount > oracleSyAmount) {
            revert OracleUnderflow();
        }

        unchecked {
            oracleSyAmount -= _amount;
        }
    }

    function _min(
        uint256 _a,
        uint256 _b
    )
        internal
        pure
        returns (uint256)
    {
        return _a < _b
            ? _a
            : _b;
    }

    function _mintHybridTokenIrreducible(
        uint256 _amount,
        uint256 _overhangFetched,
        bool _ptGreaterFetched,
        bytes calldata _dataFetched
    )
        internal
        returns (uint256)
    {
        uint256 wstETHAmount = _wrapWstETH(
            _amount
        );

        return _depositPendleMint(
            wstETHAmount,
            _overhangFetched,
            msg.sender,
            _ptGreaterFetched,
            _dataFetched
        );
    }

    function _depositPositionPendle(
        uint256 _nftId,
        uint256 _amount,
        uint256 _overhangFetched,
        bool _ptGreaterFetched,
        bytes calldata _dataFetched
    )
        internal
    {
        uint256 amount = _applyFee(
            _amount
        );

        uint256 hybridTokens = _depositPendleMint(
            amount,
            _overhangFetched,
            address(this),
            _ptGreaterFetched,
            _dataFetched
        );

        _safeApprove(
            address(HYBRID_TOKEN),
            address(WISE_LENDING),
            hybridTokens
        );

        WISE_LENDING.depositExactAmount(
            _nftId,
            address(HYBRID_TOKEN),
            hybridTokens
        );
    }

    function _applyFee(
        uint256 _amount
    )
        internal
        returns (uint256)
    {
        uint256 feeAmount = _amount
            * USAGE_FEE
            / PRECISION_FACTOR_E18;

        _safeTransfer(
            WST_ETH_ADDRESS,
            master,
            feeAmount
        );

        return _amount - feeAmount;
    }

    function _exchangeSyToLp(
        uint256 _amount
    )
        internal
    {
        uint256 amountPt = _getDisassembleTokenAmount(
            _amount
        );

        uint256 pyAmount = _getPY(
            amountPt
        );

        uint256[3] memory results = _getLP(
            _amount - amountPt,
            pyAmount
        );

        farmState.totalLpAmount += results[0];

        _sendTokenLockContract(
            results[0],
            pyAmount
        );
    }

    function _checkDeviation(
        uint256 _overhangFetched,
        uint256 _currentYtAmount,
        uint256 _currentPtAmount,
        bool _ptGreaterExternal,
        bool _ptGreaterContract
    )
        internal
        pure
    {
        if (_ptGreaterExternal != _ptGreaterContract) {
            revert OverhangChanged();
        }

        uint256 overhang = _ptGreaterContract == true
            ? _currentPtAmount - _currentYtAmount
            : _currentYtAmount - _currentPtAmount;

        if (_checkWithinRange(overhang, _overhangFetched, DEVIATION_MINT) == false) {
            revert DeviationTooBig();
        }
    }

    function _depositPendleMint(
        uint256 _amount,
        uint256 _overhangFetched,
        address _receiver,
        bool _ptGreaterFetched,
        bytes calldata _dataFetched
    )
        internal
        returns (uint256)
    {
        _increaseOracleValue(
            _amount
        );

        bool ptGreaterContract = farmState.ptGreater;

        _checkDeviation(
            _overhangFetched,
            farmState.totalYtAmount,
            farmState.totalPtAmount,
            _ptGreaterFetched,
            ptGreaterContract
        );

        if (_checkReceiverAndMarket(_dataFetched) == false) {
            revert WrongMarketOrReceiver();
        }

        uint256 newPY;
        uint256 usedSy;

        uint256 syAmount = _getSy(
            _amount
        );

        (
            usedSy,
            newPY
        ) = ptGreaterContract == true
            ? _swapPtOverhang(_dataFetched)
            : _swapYtOverhang(_dataFetched);

        uint256 restSy = syAmount
            - usedSy;

        uint256 hybridTokens = _getHybridEquivalent(
            restSy,
            newPY,
            _overhangFetched
        );

        _handleMintZeroPriceImpact(
            _receiver,
            hybridTokens,
            restSy
        );

        _updateFarmState();

        return hybridTokens;
    }

    function _handleMintZeroPriceImpact(
        address _receiver,
        uint256 _amountMint,
        uint256 _amountSy
    )
        internal
    {
        HYBRID_TOKEN.mint(
            _receiver,
            _amountMint
        );

        _exchangeSyToLp(
            _amountSy
        );
    }

    function _getHybridEquivalent(
        uint256 _restSy,
        uint256 _swapAmount,
        uint256 _overhang
    )
        internal
        view
        returns (uint256)
    {
        uint256 totalSupply = HYBRID_TOKEN.totalSupply();

        if (totalSupply == 0) {
            return _restSy;
        }

        uint256 percentageSy = _restSy
            * PRECISION_FACTOR_E18
            / (farmState.totalSyAmount + _restSy);

        uint256 percentagePY = _swapAmount
            * PRECISION_FACTOR_E18
            / (_overhang + _swapAmount);

        uint256 smallerValue = percentageSy > percentagePY
            ? percentagePY
            : percentageSy;

        return smallerValue
            * totalSupply
            / PRECISION_FACTOR_E18;
    }

    function _getPtToSyRatio()
        internal
        view
        returns (uint256)
    {
        MarketState memory marketState = LP_PENDLE.readState(
            msg.sender
        );

        uint256 rescaledTotalSy = uint256(marketState.totalSy)
            * YT_PENDLE.pyIndexStored()
            / PRECISION_FACTOR_E18;

        uint256 totalPt = uint256(
            marketState.totalPt
        );

        return PRECISION_FACTOR_E18
            * totalPt
            / (totalPt + rescaledTotalSy);
    }

    function _getSyToPtRatio()
        internal
        view
        returns (uint256)
    {
        return PRECISION_FACTOR_E18
            - _getPtToSyRatio();
    }

    function _getDisassembleTokenAmount(
        uint256 _amount
    )
        internal
        view
        returns (uint256)
    {
        return _amount
            * _getPtToSyRatio()
            / PRECISION_FACTOR_E18;
    }

    function _getSy(
        uint256 _amount
    )
        internal
        returns (uint256)
    {
        return SY_PENDLE.deposit(
            address(this),
            WST_ETH_ADDRESS,
            _amount,
            _amount
        );
    }

    function _redeemSy(
        uint256 _amount,
        address _receiver
    )
        internal
        returns (uint256)
    {
        return SY_PENDLE.redeem(
            _receiver,
            _amount,
            WST_ETH_ADDRESS,
            _amount,
            false
        );
    }

    function _getPY(
        uint256 _amount
    )
        internal
        returns (uint256)
    {
        _safeTransfer(
            SY_PENDLE_ADDRESS,
            YT_PENDLE_ADDRESS,
            _amount
        );

        uint256 pyAmount = YT_PENDLE.mintPY(
            address(this),
            address(this)
        );

        farmState.totalYtAmount += pyAmount;

        return pyAmount;
    }

    function _getLP(
        uint256 _amountSy,
        uint256 _amountPt
    )
        internal
        returns (uint256[3] memory)
    {
        _safeTransfer(
            PT_PENDLE_ADDRESS,
            PENDLE_MARKET_ADDRESS,
            _amountPt
        );

        _safeTransfer(
            SY_PENDLE_ADDRESS,
            PENDLE_MARKET_ADDRESS,
            _amountSy
        );

        return LP_PENDLE.mint(
            address(this),
            _amountSy,
            _amountPt
        );
    }
}
