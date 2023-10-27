// SPDX-License-Identifier: -- WISE --

pragma solidity =0.8.21;

import "./sDaiFarmSwapLogic.sol";

abstract contract sDaiFarmLeverageLogic is
    sDaiFarmSwapLogic,
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
        uint256 _minMaxAmount,
        address _flashloanToken
    )
        internal
    {
        bytes memory data = abi.encode(
            _nftId,
            _initialAmount,
            _lendingShares,
            _borrowShares,
            _minMaxAmount,
            msg.sender
        );

        globalTokens.push(
            IERC20(_flashloanToken)
        );

        globalAmounts.push(
            _amount
        );

        allowEnter = true;

        BALANCER_VAULT.flashLoan(
            this,
            globalTokens,
            globalAmounts,
            data
        );

        globalTokens.pop();
        globalAmounts.pop();
    }

    /**
     * @dev Receive function from balancer flashloan. Body
     * is called from balancer at the end of their {flashLoan()}
     * logic. Overwritten with different opening flows depending
     * on the chosen borrow by the user.
     */
    function receiveFlashLoan(
        IERC20[] memory _flashloanToken,
        uint256[] memory _amounts,
        uint256[] memory _feeAmounts,
        bytes memory _userData
    )
        external
    {
        if (msg.sender != BLANCER_ADDRESS) {
            revert NotBalancerVault();
        }

        if (allowEnter == false) {
            revert NotAllowed();
        }

        allowEnter = false;

        uint256 flashloanAmount = _amounts[0];

        uint256 totalDebtBalancer = flashloanAmount
            + _feeAmounts[0];

        address flashloanToken = address(
            _flashloanToken[0]
        );

        (
            uint256 nftId,
            uint256 initialAmount,
            uint256 lendingShares,
            uint256 borrowShares,
            uint256 minMaxAmount,
            address caller

        ) = abi.decode(
            _userData,
            (
                uint256,
                uint256,
                uint256,
                uint256,
                uint256,
                address
            )
        );

        uint256 index = nftToIndex[
            nftId
        ];

        if (initialAmount == 0) {
            _logicClosePosition(
                nftId,
                index,
                borrowShares,
                lendingShares,
                totalDebtBalancer,
                minMaxAmount,
                flashloanToken,
                caller
            );

            return;
        }

        if (index == uint256(Token.DAI)) {
            _logicOpenPositionBase(
                nftId,
                index,
                flashloanAmount + initialAmount,
                totalDebtBalancer,
                flashloanToken
            );

            return;
        }

        _logicOpenPostionSwap(
            nftId,
            index,
            initialAmount,
            flashloanAmount,
            minMaxAmount,
            totalDebtBalancer,
            flashloanToken
        );
    }

    /**
     * @dev Core logic for closing a position using balancer
     * flashloans.
     */
    function _logicClosePosition(
        uint256 _nftId,
        uint256 _index,
        uint256 _borrowShares,
        uint256 _lendingShares,
        uint256 _totalDebtBalancer,
        uint256 _maxInAmount,
        address _flashloanToken,
        address _caller
    )
        internal
    {
        uint256 unwrapedAmount = _paybackAndUnstake(
            _nftId,
            _index,
            _borrowShares,
            _lendingShares
        );

        uint256 sendAmount = unwrapedAmount
            - _totalDebtBalancer;

        if (_index == uint256(Token.USDT)) {

            uint256 adjustedUnwrapAmount = unwrapedAmount
                / PRECISION_FACTOR_E12;

            DSS_PSM.buyGem(
                address(this),
                adjustedUnwrapAmount
            );

            uint256 amountIn = _swapUSDCToUSDT(
                _totalDebtBalancer,
                _maxInAmount
            );

            uint256 sellAmount = adjustedUnwrapAmount
                - amountIn;

            DSS_PSM.sellGem(
                address(this),
                sellAmount
            );

            sendAmount = unwrapedAmount
                - (amountIn * PRECISION_FACTOR_E12);
        }

        if (_index == uint256(Token.USDC)) {

            DSS_PSM.buyGem(
                address(this),
                _totalDebtBalancer
            );

            sendAmount = unwrapedAmount
                - (_totalDebtBalancer * PRECISION_FACTOR_E12);
        }

        _safeTransfer(
            _flashloanToken,
            msg.sender,
            _totalDebtBalancer
        );

        _safeTransfer(
            DAI_ADDRESS,
            _caller,
            sendAmount
        );
    }

    /**
     * @dev Internal function combining paying back the
     * borrow amount, withdrawing the collateral (sDAI)
     * and converting it back to DAI.
     */
    function _paybackAndUnstake(
        uint256 _nftId,
        uint256 _index,
        uint256 _borrowShares,
        uint256 _lendingShares
    )
        internal
        returns (uint256)
    {
        AAVE_HUB.paybackExactShares(
            _nftId,
            borrowTokenAddresses[_index],
            _borrowShares
        );

        uint256 withdrawAmount = WISE_LENDING.withdrawExactShares(
            _nftId,
            SDAI_ADDRESS,
            _lendingShares
        );

        uint256 unwrapedAmount = SDAI.redeem(
            withdrawAmount,
            address(this),
            address(this)
        );

        return unwrapedAmount;
    }

    /**
     * @dev Internal function converting the borrow
     * token (USDT or USDC) into DAI. After that calling
     * {_logicOpenPositionBase()} which performs the
     * collateral deposit.
     */
    function _logicOpenPostionSwap(
        uint256 _nftId,
        uint256 _index,
        uint256 _initialAmount,
        uint256 _flashloanAmount,
        uint256 _minOutAmount,
        uint256 _totalDebtBalancer,
        address _flashloanToken
    )
        internal
    {
        uint256 depositAmount = _index == uint256(Token.USDT)
            ? _depositPreparationsUSDT(
                _flashloanAmount,
                _initialAmount,
                _minOutAmount
            )
            : _depositPreparationsUSDC(
                _flashloanAmount,
                _initialAmount
            );

        _logicOpenPositionBase(
            _nftId,
            _index,
            depositAmount,
            _totalDebtBalancer,
            _flashloanToken
        );
    }

    /**
     * @dev Internal function executing the
     * collateral deposit by converting DAI
     * into sDAI, adding it as collateral and
     * borrowing the flahsloan token to pay
     * back {_totalDebtBalancer}.
     */
    function _logicOpenPositionBase(
        uint256 _nftId,
        uint256 _index,
        uint256 _depositAmount,
        uint256 _totalDebtBalancer,
        address _flashloanToken
    )
        internal
    {
        uint256 sDaiAmount = SDAI.deposit(
            _depositAmount,
            address(this)
        );

        WISE_LENDING.depositExactAmount(
            _nftId,
            SDAI_ADDRESS,
            sDaiAmount
        );

        WISE_LENDING.borrowExactAmount(
            _nftId,
            aaveTokenAddresses[_index],
            _totalDebtBalancer
        );

        if (_checkDebtRatio(_nftId) == false) {
            revert DebtratioTooHigh();
        }

        AAVE.withdraw(
            _flashloanToken,
            _totalDebtBalancer,
            msg.sender
        );
    }
}
