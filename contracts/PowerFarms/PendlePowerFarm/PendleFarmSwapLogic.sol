// SPDX-License-Identifier: -- WISE --

pragma solidity =0.8.21;

import "./PendleWstETHMathLogic.sol";

abstract contract PendleFarmSwapLogic is PendleWstETHMathLogic {

    function _validateSelector(
        bytes memory _data,
        bytes4 _selector
    )
        internal
        pure
        returns (bool)
    {
        bytes4 selector;

        assembly {
            selector := mload(add(_data, 4))
        }

        return selector == _selector;
    }

    function _validateToken(
        bytes calldata _data
    )
        internal
        pure
        returns (bool isValid)
    {
        // bytes memory newData = _data[OFFSET_INPUT_AMOUNT_END:];

        TokenOutput memory output = abi.decode(
            _data,(TokenOutput)
        );

        isValid = output.tokenOut == WETH_ADDRESS
            ? true
            : false;
    }

    function _checkReceiverAndMarket(
        bytes calldata _data
    )
        internal
        view
        returns (bool)
    {
        address market;
        address receiver;

        bytes memory _newData = _data[4:];

        assembly {
            receiver := mload(add(_newData, 20))
            market := mload(add(_newData, 40))
        }

        return receiver == address(this)
            && market == PENDLE_MARKET_ADDRESS;
    }

    function _changeExactInputAmount(
        bytes calldata _data,
        uint256 _newAmount
    )
        internal
        pure
        returns (bytes memory)
    {
        return _changeData(
            _data,
            abi.encode(_newAmount),
            OFFSET_INPUT_AMOUNT,
            OFFSET_INPUT_AMOUNT_END
        );
    }

    function _changeData(
        bytes calldata _original,
        bytes memory _newData,
        uint256 _offsetFromOriginal,
        uint256 _offsetToOriginal
    )
        internal
        pure
        returns (bytes memory)
    {
        bytes memory replacedData = _original;

        uint256 offsetLength = _offsetToOriginal
            - _offsetFromOriginal;

        uint256 i;

        for (i; i < offsetLength;) {
            replacedData[i + _offsetFromOriginal] = _newData[i];

            unchecked {
                ++i;
            }
        }

        return replacedData;
    }

    function _extractExactAmount(
        bytes calldata _data
    )
        internal
        pure
        returns (uint256)
    {
        uint256 exactAmount;

        bytes memory _newData = _data[OFFSET_INPUT_AMOUNT:];

        assembly {
            exactAmount := mload(add(_newData, 32))
        }

        return exactAmount;
    }

    function _checkSwap(
        bool _success,
        bytes memory _callbackData
    )
        internal
        pure
        returns (uint256)
    {
        (
            uint256 swapAmount,

        ) = abi.decode(
            _callbackData,
            (uint256,uint256)
        );

        if (_success == false) {
            revert SwapCallFailed();
        }

        return swapAmount;
    }

    function _checkWithinRange(
        uint256 _overhang,
        uint256 _overhangQueried,
        uint256 _deviationPercentage
    )
        internal
        pure
        returns (bool)
    {
        uint256 allowedDeviation = _overhangQueried
            * _deviationPercentage
            / PRECISION_FACTOR_E18;

        bool aboveLowerBound = _overhang
            >= _overhangQueried
            - allowedDeviation;

        bool belowUpperBound = _overhang
            <= _overhangQueried
            + allowedDeviation;

        return aboveLowerBound && belowUpperBound;
    }

    function _swapSyToYt(
        uint256 _amountYt,
        uint256 _overhangQueried,
        bytes calldata _data,
        bool _swapAllSy
    )
        internal
        returns (uint256)
    {
        bool success;
        bytes memory callbackData;

        uint256 usedSy;
        uint256 newYtAmount;

        if (_checkWithinRange(_amountYt, _overhangQueried, DEVIATION_COMPOUND) == false) {
            revert OverhangChanged();
        }

        if (_checkReceiverAndMarket(_data) == false) {
            revert WrongMarketOrReceiver();
        }

        if (_swapAllSy == true) {

            if (_validateSelector(_data, SELECTOR_EXACT_SY_FOR_YT) == false) {
                revert WrongSelector();
            }

            (
                success,
                callbackData
                //is out amount in calldata for exactSyForYt?
            ) = PENDLE_ROUTER_ADDRESS.call(
                _data
            );

            // since we use exactSyForYt in callbackData should be the Yt amount
            uint256 receivedYt = _checkSwap(
                success,
                callbackData
            );

            if (usedSy != compoundSyAmount) {
                revert OffchainDataWrong();
            }

            _transferYt(
                receivedYt
            );

            return 0;
        }

        (
            usedSy,
            newYtAmount

        ) = _swapToExact(
            _data,
            SELECTOR_SY_FOR_EXACT_YT
        );

        _transferYt(
            newYtAmount
        );

        return compoundSyAmount - usedSy;
    }

    function _swapSyToPt(
        uint256 _amountPt,
        uint256 _overhangQueried,
        bytes calldata _data,
        bool _swapAllSy
    )
        internal
        returns (uint256)
    {
        bool success;
        bytes memory callbackData;

        uint256 newSy;
        uint256 usedSy;
        uint256 newPtAmount;

        if (_checkWithinRange(_amountPt, _overhangQueried, DEVIATION_COMPOUND) == false) {
            revert OverhangChanged();
        }

        if (_checkReceiverAndMarket(_data) == false) {
            revert WrongMarketOrReceiver();
        }

        if (_swapAllSy == true) {

            if (_validateSelector(_data, SELECTOR_EXACT_SY_FOR_PT) == false) {
                revert WrongSelector();
            }

            (
                success,
                callbackData
                // is out amount in calldata for exactSyForYt?
            ) = PENDLE_ROUTER_ADDRESS.call(
                _data
            );

            // NOTE: Possible to repeat this step since new sy generated?
            if (_extractExactAmount(_data) != compoundSyAmount) {
                revert OffchainDataWrong();
            }

            // since we use exactSyForPt in callbackData should be the Pt amount
            uint256 receivedPt = _checkSwap(
                success,
                callbackData
            );

            // take always the smaller value!
            newSy = _redeemSwappedPT(
                receivedPt
            );

            return newSy;
        }

        (
            usedSy,
            newPtAmount

        ) = _swapToExact(
            _data,
            SELECTOR_SY_FOR_EXACT_PT
        );

        newSy = _redeemSwappedPT(
            newPtAmount
        );

        return compoundSyAmount
            - usedSy
            + newSy;
    }

    function _swapToExact(
        bytes calldata _data,
        bytes4 _selector
    )
        internal
        returns (
            uint256 tokenInAmount,
            uint256 tokenOutAmount
        )
    {
        if (_validateSelector(_data, _selector) == false) {
            revert WrongSelector();
        }

        (
            bool success,
            bytes memory callbackData
        ) = PENDLE_ROUTER_ADDRESS.call(
            _data
        );

        //since we use SyForExactPt in callbackData should be the Sy amount
        tokenInAmount = _checkSwap(
            success,
            callbackData
        );

        tokenOutAmount = _extractExactAmount(
            _data
        );
    }

    function _swapFromExact(
        bytes calldata _data,
        bytes4 _selector,
        uint256 _actualAmount
    )
        internal
        returns (uint256 tokenOutAmount)
    {
        if (_validateSelector(_data, _selector) == false) {
            revert WrongSelector();
        }

        uint256 tokenInAmountData = _extractExactAmount(
            _data
        );

        _checkWithinRange(
            _actualAmount,
            tokenInAmountData,
            DEVIATION_CLOSE
        );

        bytes memory actualCallData = _changeExactInputAmount(
            _data,
            _actualAmount
        );

        (
            bool success,
            bytes memory callbackData
        ) = PENDLE_ROUTER_ADDRESS.call(
            actualCallData
        );

        tokenOutAmount = _checkSwap(
            success,
            callbackData
        );
    }

    function _swapPtOverhang(
        bytes calldata _data
    )
        internal
        returns (
            uint256 tokenInAmount,
            uint256 tokenOutAmount
        )
    {
        (
            tokenInAmount,
            tokenOutAmount

        ) = _swapToExact(
            _data,
            SELECTOR_SY_FOR_EXACT_PT
        );

        farmState.contractPtAmount += tokenOutAmount;
    }

    function _swapYtOverhang(
        bytes calldata _data
    )
        internal
        returns (
            uint256 tokenInAmount,
            uint256 tokenOutAmount
        )
    {
        (
            tokenInAmount,
            tokenOutAmount

        ) = _swapToExact(
            _data,
            SELECTOR_SY_FOR_EXACT_YT
        );

        farmState.totalYtAmount += tokenOutAmount;

        _transferYt(
            tokenOutAmount
        );
    }

    function _transferYt(
        uint256 _amountYt
    )
        internal
    {
        _safeApprove(
            YT_PENDLE_ADDRESS,
            address(LOCK_CONTRACT),
            _amountYt
        );

        LOCK_CONTRACT.transferYT(
            _amountYt,
            address(this)
        );
    }

    function _sendTokenLockContract(
        uint256 _amountLp,
        uint256 _amountYt
    )
        internal
    {
        _safeApprove(
            address(LP_PENDLE),
            address(LOCK_CONTRACT),
            _amountLp
        );

        LOCK_CONTRACT.transferLP(
            _amountLp,
            address(this)
        );

        _transferYt(
            _amountYt
        );
    }

    function _redeemSwappedPT(
        uint256 _amount
    )
        internal
        returns (uint256)
    {
        LOCK_CONTRACT.sendYT(
            _amount,
            address(this)
        );

        return _redeemPY(
            _amount
        );
    }

    function _redeemPY(
        uint256 _amount
    )
        internal
        returns (uint256)
    {
        _safeTransfer(
            YT_PENDLE_ADDRESS,
            YT_PENDLE_ADDRESS,
            _amount
        );

        _safeTransfer(
            PT_PENDLE_ADDRESS,
            YT_PENDLE_ADDRESS,
            _amount
        );

        farmState.totalYtAmount -= _amount;

        return YT_PENDLE.redeemPY(
            address(this)
        );
    }
}
