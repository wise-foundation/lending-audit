
// SPDX-License-Identifier: -- WISE --

pragma solidity =0.8.21;

import "./PendleFarmLogic.sol";

abstract contract PendleWstETHLeverageLogic is
    PendleFarmLogic,
    IFlashLoanRecipient
{
    /**
     * @dev Wrapper function preparing balancer flashloan and
     * loading data to pass into receiver.
     */
    function _executeBalancerFlashLoan(
        uint256 _nftId,
        uint256 _amount,
        uint256 _initialAmount,
        uint256 _lendingShares,
        uint256 _borrowShares,
        uint256 _minAmountOut,
        uint256 _overhangFetched,
        bool _ptGreaterFetched,
        bool _ethBack,
        bytes memory _swapDataFetched
    )
        internal
    {
        globalTokens.push(
            IERC20(WETH_ADDRESS)
        );

        globalAmounts.push(
            _amount
        );

        allowEnter = true;

        BALANCER_VAULT.flashLoan(
            this,
            globalTokens,
            globalAmounts,
            abi.encode(
                _nftId,
                _initialAmount,
                _lendingShares,
                _borrowShares,
                _minAmountOut,
                _overhangFetched,
                msg.sender,
                _ptGreaterFetched,
                _ethBack,
                _swapDataFetched
            )
        );

        globalTokens.pop();
        globalAmounts.pop();
    }

    /**
     * @dev Receive function from balancer flashloan. Body
     * is called from balancer at the end of their {flashLoan()}
     * logic. Overwritten with opening flows.
     */
    function receiveFlashLoan(
        IERC20[] calldata _flashloanToken,
        uint256[] calldata _amounts,
        uint256[] calldata _feeAmounts,
        bytes calldata _userData
    )
        external
    {
        if (allowEnter == false) {
            revert InvalidAction();
        }

        allowEnter = false;

        if (_flashloanToken.length == 0) {
            revert InvalidAction();
        }

        if (msg.sender != BALANCER_ADDRESS) {
            revert InvalidAction();
        }

        uint256 userDataLength = _userData.length;

        if (userDataLength < SHARED_FLASH_LOAN_SIZE) {
            revert InvalidAction();
        }

        FlashLoanData memory flashLoanData = _decodeUserData(
            _userData
        );

        uint256 flashloanAmount = _amounts[0];

        uint256 totalAmount = flashloanAmount
            + _feeAmounts[0];

        if (flashLoanData.initialAmount == 0) {
            _logicClosePosition(
                flashLoanData.nftId,
                flashLoanData.borrowShares,
                flashLoanData.lendingShares,
                totalAmount,
                flashLoanData.overhangFetched,
                flashLoanData.caller,
                flashLoanData.ptGreaterFetched,
                flashLoanData.minOutAmount,
                flashLoanData.swapDataFetched
            );
        }

        _logicOpenPosition(
            flashLoanData.nftId,
            flashloanAmount + flashLoanData.initialAmount,
            totalAmount,
            flashLoanData.overhangFetched,
            flashLoanData.ptGreaterFetched,
            flashLoanData.swapDataFetched
        );
    }

    function _decodeUserData(
        bytes calldata _workingBytes
    )
        internal
        pure
        returns (FlashLoanData memory flashLoanData)
    {
        (
            flashLoanData.nftId,
            flashLoanData.initialAmount,
            flashLoanData.lendingShares,
            flashLoanData.borrowShares,
            flashLoanData.minOutAmount,
            flashLoanData.overhangFetched,
            flashLoanData.caller
        ) = abi.decode(
            _workingBytes[SHARED_FLASH_LOAN_SIZE:],
            (
                uint256,
                uint256,
                uint256,
                uint256,
                uint256,
                uint256,
                address
            )
        );

        (
            flashLoanData.ptGreaterFetched,
            flashLoanData.ethBack,
            flashLoanData.swapDataFetched
        ) = abi.decode(
            _workingBytes[:_workingBytes.length],
            (
                bool,
                bool,
                bytes
            )
        );
    }

    /**
     * @dev Internal function executing the
     * collateral deposit by converting ETH
     * into wstETH, adding it as collateral and
     * borrowing the flashloan token (WETH) to pay
     * back {_totalDebtBalancer}.
     */
    function _logicOpenPosition(
        uint256 _nftId,
        uint256 _depositAmount,
        uint256 _totalDebtBalancer,
        uint256 _overhang,
        bool _ptGreater,
        bytes memory _swapData
    )
        internal
    {
        _unwrapETH(
            _depositAmount
        );

        uint256 wstETHAmount = _wrapWstETH(
            _depositAmount
        );

        this.depositPositionPendle(
            _nftId,
            wstETHAmount,
            _overhang,
            _ptGreater,
            _swapData
        );

        WISE_LENDING.borrowExactAmount(
            _nftId,
            AAVE_WETH_ADDRESS,
            _totalDebtBalancer
        );

        if (_checkDebtRatio(_nftId) == false) {
            revert DebtRatioTooHigh();
        }

        AAVE.withdraw(
            WETH_ADDRESS,
            _totalDebtBalancer,
            msg.sender
        );
    }

    function _logicClosePosition(
        uint256 _nftId,
        uint256 _borrowShares,
        uint256 _lendingShares,
        uint256 _totalDebtBalancer,
        uint256 _overhangFetched,
        address _caller,
        bool _ptGreaterFetched,
        uint256 _minAmountOut,
        bytes memory _swapDataFetched
    )
        internal
    {
        AAVE_HUB.paybackExactShares(
            _nftId,
            WETH_ADDRESS,
            _borrowShares
        );

        uint256 withdrawAmount = WISE_LENDING.withdrawExactShares(
            _nftId,
            address(HYBRID_TOKEN),
            _lendingShares
        );

        (
            uint256 ethAmount,
            uint256 pyAmount
            ,
            // bool ptGreater
        ) = _handleBurnIrreducibleETH(
                withdrawAmount,
                _minAmountOut,
                address(this)
        );

        uint256 extraWeth = this.handleSwapClosePosition(
            _overhangFetched,
            pyAmount,
            _ptGreaterFetched,
            _swapDataFetched
        );

        _unwrapETH(
            extraWeth
        );

        _wrapETH(
            _totalDebtBalancer
        );

        _safeTransfer(
            WETH_ADDRESS,
            BALANCER_ADDRESS,
            _totalDebtBalancer
        );

        _sendValue(
            _caller,
            ethAmount
                + extraWeth
                - _totalDebtBalancer
        );
    }

    function handleSwapClosePosition(
        uint256 _overhangFetched,
        uint256 _pyAmount,
        bool _ptGreaterFetched,
        bytes calldata _swapDataFetched
    )
        public
        checkCaller
        returns (uint256 extraWeth)
    {
        bool ptGreaterContract = farmState.ptGreater;

        _checkDeviation(
            _overhangFetched,
            farmState.totalYtAmount,
            farmState.totalPtAmount,
            _ptGreaterFetched,
            ptGreaterContract
        );

        if (_checkReceiverAndMarket(_swapDataFetched) == false) {
            revert WrongMarketOrReceiver();
        }

        if (_validateToken(_swapDataFetched) == false) {
            revert InvalidToken();
        }

        extraWeth = _swapFromExact(
            _swapDataFetched,
            ptGreaterContract == true
                ? SELECTOR_EXACT_PT_FOR_TOKEN
                : SELECTOR_EXACT_YT_FOR_TOKEN,
            _pyAmount
        );
    }

    /**
     * @dev Workaround to allow passing {memory _data}
     * as {calldata _data} with {this.} call. This
     * is neccessary because abi.decode saves calldata
     * into memory by default.
     */
    function depositPositionPendle(
        uint256 _nftId,
        uint256 _amount,
        uint256 _overhang,
        bool _ptGreater,
        bytes calldata _swapData
    )
        public
        checkCaller
    {
        _depositPositionPendle(
            _nftId,
            _amount,
            _overhang,
            _ptGreater,
            _swapData
        );
    }
}
