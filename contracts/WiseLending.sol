// SPDX-License-Identifier: -- WISE --

pragma solidity =0.8.21;

/**
 * @author Christoph Krpoun
 * @author René Hochmuth
 * @author Vitally Marinchenko
 */

import "./PoolManager.sol";

/**
 * @dev WISE lending is an automated lending platform on which users can collateralize
 * their assets and borrow tokens against them.
 *
 * Users need to pay borrow rates for debt tokens, which are reflected in a borrow APY for
 * each asset type (pool). This borrow rate is variable over time and determined through the
 * utilization of the pool. The bounding curve is a family of different bonding curves adjusted
 * automatically by LASA (Lending Automated Scaling Algorithm). For more information, see:
 * [https://wisesoft.gitbook.io/wise/wise-lending-protocol/lasa-ai]
 *
 * In addition to normal deposit, withdraw, borrow, and payback functions, there are other
 * interacting modes:
 *
 * - Solely deposit and withdraw allows the user to keep their funds private, enabling
 *    them to withdraw even when the pools are borrowed empty.
 *
 * - Aave pools  allow for maximal capital efficiency by earning aave supply APY for not
 *   borrowed funds.
 *
 * - Special curve pools nside beefy farms can be used as collateral, opening up new usage
 *   possibilities for these asset types.
 *
 * - Users can pay back their borrow with lending shares of the same asset type, making it
 *   easier to manage their positions.
 *
 * - Users save their collaterals and borrows inside a position NFT, making it possible
 *   to trade their whole positions or use them in second-layer contracts
 *   (e.g., spot trading with PTP NFT trading platforms).
 */

contract WiseLending is PoolManager {

    /**
     * @dev Standard receive functions forwarding
     * directly send ETH to the master address.
     */
    receive()
        external
        payable
    {
        if (msg.sender == WETH_ADDRESS) {
            return;
        }

        _sendValue(
            master,
            msg.value
        );
    }

    /**
     * @dev Runs the LASA algorithm known as
     * Lending Automated Scaling Algorithm
     * and updates pool data based on token
     */
    modifier syncPool(
        address _poolToken
    ) {
        _syncPoolBeforeCodeExecution(
            _poolToken
        );
        _;
        _syncPoolAfterCodeExecution(
            _poolToken
        );
    }

    constructor(
        address _master,
        address _wiseOracleHubAddress,
        address _nftContract,
        address _wethContract
    )
        WiseLendingDeclaration(
            _master,
            _wiseOracleHubAddress,
            _nftContract,
            _wethContract
        )
    {}

    /**
     * @dev First part of pool sync updating pseudo
     * amounts. Is skipped when powerFarms or aaveHub
     * is calling the function.
     */
    function _syncPoolBeforeCodeExecution(
        address _poolToken
    )
        private
    {
        if (sendingProgress == true) {
            revert InvalidAction();
        }

        if (_byPassCase(msg.sender) == true) {
            return;
        }

        _preparePool(
            _poolToken
        );
    }

    /**
     * @dev Second part of pool sync updating
     * the borrow rate of the pool.
     */
    function _syncPoolAfterCodeExecution(
        address _poolToken
    )
        private
    {
        _newBorrowRate(
            _poolToken
        );
    }

    /**
     * @dev Allows to give permission for onBehalf function
     * execution, allowing 3rd party to perform actions such as
     * borrowOnBehalf and withdrawOnBehalf with amount limit
     */
    function approve(
        address _spender,
        address _poolToken,
        uint256 _amount
    )
        external
    {
        allowance[msg.sender][_poolToken][_spender] = _amount;

        emit Approve(
            _spender,
            _poolToken,
            msg.sender,
            _amount,
            block.timestamp
        );
    }

    /**
     * @dev Enables _poolToken to be used as a collateral.
     */
    function collateralizeDeposit(
        uint256 _nftId,
        address _poolToken
    )
        external
        syncPool(_poolToken)
    {
        WISE_SECURITY.checksCollateralizeDeposit(
            _nftId,
            msg.sender,
            _poolToken
        );

        userLendingData[_nftId][_poolToken].unCollateralized = false;
    }

    /**
     * @dev Disables _poolToken to be used as a collateral.
     */
    function unCollateralizeDeposit(
        uint256 _nftId,
        address _poolToken
    )
        external
        syncPool(_poolToken)
    {
        _checkOwnerPosition(
            _nftId,
            msg.sender
        );

        _prepareAssociatedTokens(
            _nftId,
            _poolToken
        );

        userLendingData[_nftId][_poolToken].unCollateralized = true;

        WISE_SECURITY.checkUncollateralizedDeposit(
            _nftId,
            _poolToken
        );
    }

    // --------------- Deposit Functions -------------

    /**
     * @dev Allows to supply funds using ETH.
     * Without converting to WETH, use ETH directly.
     */
    function depositExactAmountETH(
        uint256 _nftId
    )
        external
        payable
        syncPool(WETH_ADDRESS)
        returns (uint256)
    {
        return _depositExactAmountETH(
            _nftId
        );
    }

    function _depositExactAmountETH(
        uint256 _nftId
    )
        internal
        returns (uint256)
    {
        uint256 shareAmount = calculateLendingShares(
            {
                _poolToken: WETH_ADDRESS,
                _amount: msg.value,
                _maxSharePrice: false
            }
        );

        _handleDeposit(
            msg.sender,
            _nftId,
            WETH_ADDRESS,
            msg.value,
            shareAmount
        );

        _wrapETH(
            msg.value
        );

        return shareAmount;
    }

    /**
     * @dev Allows to supply funds using ETH.
     * Without converting to WETH, use ETH directly,
     * also mints position to avoid extra transaction.
     */
    function depositExactAmountETHMint()
        external
        payable
        returns (uint256)
    {
        return _depositExactAmountETH(
            _reservePosition()
        );
    }

    /**
     * @dev Allows to supply _poolToken and user
     * can decide if _poolToken should be collateralized,
     * also mints position to avoid extra transaction.
     */
    function depositExactAmountMint(
        address _poolToken,
        uint256 _amount
    )
        external
        returns (uint256)
    {
        return depositExactAmount(
            _reservePosition(),
            _poolToken,
            _amount
        );
    }

    /**
     * @dev Allows to supply _poolToken and user
     * can decide if _poolToken should be collateralized.
     */
    function depositExactAmount(
        uint256 _nftId,
        address _poolToken,
        uint256 _amount
    )
        public
        syncPool(_poolToken)
        returns (uint256)
    {
        uint256 shareAmount = calculateLendingShares(
            {
                _poolToken: _poolToken,
                _amount: _amount,
                _maxSharePrice: false
            }
        );

        _handleDeposit(
            msg.sender,
            _nftId,
            _poolToken,
            _amount,
            shareAmount
        );

        _safeTransferFrom(
            _poolToken,
            msg.sender,
            address(this),
            _amount
        );

        return shareAmount;
    }

    /**
     * @dev Allows to supply funds using ETH in solely mode,
     * which does not earn APY, but keeps the funds private.
     * Other users are restricted from borrowing these funds,
     * owner can always withdraw even if all funds are borrowed.
     * Also mints position to avoid extra transaction.
     */
    function solelyDepositETHMint()
        external
        payable
    {
        solelyDepositETH(
            _reservePosition()
        );
    }

    /**
     * @dev Allows to supply funds using ETH in solely mode,
     * which does not earn APY, but keeps the funds private.
     * Other users are restricted from borrowing these funds,
     * owner can always withdraw even if all funds are borrowed.
     */
    function solelyDepositETH(
        uint256 _nftId
    )
        public
        payable
        syncPool(WETH_ADDRESS)
    {
        _handleSolelyDeposit(
            msg.sender,
            _nftId,
            WETH_ADDRESS,
            msg.value
        );

        _wrapETH(
            msg.value
        );

        emit FundsSolelyDeposited(
            msg.sender,
            _nftId,
            WETH_ADDRESS,
            msg.value,
            block.timestamp
        );
    }

    /**
     * @dev Allows to supply funds using ERC20 in solely mode,
     * which does not earn APY, but keeps the funds private.
     * Other users are restricted from borrowing these funds,
     * owner can always withdraw even if all funds are borrowed.
     * Also mints position to avoid extra transaction.
     */
    function solelyDepositMint(
        address _poolToken,
        uint256 _amount
    )
        external
    {
        solelyDeposit(
            _reservePosition(),
            _poolToken,
            _amount
        );
    }

    /**
     * @dev Allows to supply funds using ERC20 in solely mode,
     * which does not earn APY, but keeps the funds private.
     * Other users are restricted from borrowing these funds,
     * owner can always withdraw even if all funds are borrowed.
     */
    function solelyDeposit(
        uint256 _nftId,
        address _poolToken,
        uint256 _amount
    )
        public
        syncPool(_poolToken)
    {
        _handleSolelyDeposit(
            msg.sender,
            _nftId,
            _poolToken,
            _amount
        );

        _safeTransferFrom(
            _poolToken,
            msg.sender,
            address(this),
            _amount
        );

        emit FundsSolelyDeposited(
            msg.sender,
            _nftId,
            _poolToken,
            _amount,
            block.timestamp
        );
    }

    // --------------- Withdraw Functions -------------

    /**
     * @dev Allows to withdraw publicly
     * deposited ETH funds using exact amount.
     */
    function withdrawExactAmountETH(
        uint256 _nftId,
        uint256 _amount
    )
        external
        syncPool(WETH_ADDRESS)
        returns (uint256)
    {
        uint256 withdrawShares = _preparationsWithdraw(
            _nftId,
            msg.sender,
            WETH_ADDRESS,
            _amount
        );

        _coreWithdrawToken(
            msg.sender,
            _nftId,
            WETH_ADDRESS,
            _amount,
            withdrawShares
        );

        _unwrapETH(
            _amount
        );

        _sendValue(
            msg.sender,
            _amount
        );

        emit FundsWithdrawn(
            msg.sender,
            _nftId,
            WETH_ADDRESS,
            _amount,
            withdrawShares,
            block.timestamp
        );

        return withdrawShares;
    }

    /**
     * @dev Allows to withdraw publicly
     * deposited ETH funds using exact shares.
     */
    function withdrawExactSharesETH(
        uint256 _nftId,
        uint256 _shares
    )
        external
        syncPool(WETH_ADDRESS)
        returns (uint256)
    {
        _checkOwnerPosition(
            _nftId,
            msg.sender
        );

        uint256 withdrawAmount = cashoutAmount(
            {
                _poolToken: WETH_ADDRESS,
                _shares: _shares,
                _maxAmount: true
            }
        );

        _coreWithdrawToken(
            msg.sender,
            _nftId,
            WETH_ADDRESS,
            withdrawAmount,
            _shares
        );

        _unwrapETH(
            withdrawAmount
        );

        _sendValue(
            msg.sender,
            withdrawAmount
        );

        emit FundsWithdrawn(
            msg.sender,
            _nftId,
            WETH_ADDRESS,
            withdrawAmount,
            _shares,
            block.timestamp
        );

        return withdrawAmount;
    }

    /**
     * @dev Allows to withdraw publicly
     * deposited ERC20 funds using exact amount.
     */
    function withdrawExactAmount(
        uint256 _nftId,
        address _poolToken,
        uint256 _withdrawAmount
    )
        external
        syncPool(_poolToken)
        returns (uint256)
    {
        uint256 withdrawShares = _preparationsWithdraw(
            _nftId,
            msg.sender,
            _poolToken,
            _withdrawAmount
        );

        _coreWithdrawToken(
            msg.sender,
            _nftId,
            _poolToken,
            _withdrawAmount,
            withdrawShares
        );

        _safeTransfer(
            _poolToken,
            msg.sender,
            _withdrawAmount
        );

        emit FundsWithdrawn(
            msg.sender,
            _nftId,
            _poolToken,
            _withdrawAmount,
            withdrawShares,
            block.timestamp
        );

        return withdrawShares;
    }

    /**
     * @dev Allows to withdraw privately
     * deposited ETH funds using input amount.
     */
    function solelyWithdrawETH(
        uint256 _nftId,
        uint256 withdrawAmount
    )
        external
        syncPool(WETH_ADDRESS)
    {
        _checkOwnerPosition(
            _nftId,
            msg.sender
        );

        _coreSolelyWithdraw(
            msg.sender,
            _nftId,
            WETH_ADDRESS,
            withdrawAmount
        );

        _unwrapETH(
            withdrawAmount
        );

        _sendValue(
            msg.sender,
            withdrawAmount
        );

        emit FundsSolelyWithdrawn(
            msg.sender,
            _nftId,
            WETH_ADDRESS,
            withdrawAmount,
            block.timestamp
        );
    }

    /**
     * @dev Allows to withdraw privately
     * deposited ERC20 funds using input amount.
     */
    function solelyWithdraw(
        uint256 _nftId,
        address _poolToken,
        uint256 _withdrawAmount
    )
        external
        syncPool(_poolToken)
    {
        _checkOwnerPosition(
            _nftId,
            msg.sender
        );

        _coreSolelyWithdraw(
            msg.sender,
            _nftId,
            _poolToken,
            _withdrawAmount
        );

        _safeTransfer(
            _poolToken,
            msg.sender,
            _withdrawAmount
        );

        emit FundsSolelyWithdrawn(
            msg.sender,
            _nftId,
            _poolToken,
            _withdrawAmount,
            block.timestamp
        );
    }

    /**
     * @dev Allows to withdraw privately
     * deposited ERC20 on behalf of owner.
     * Requires approval by _nftId owner.
     */
    function solelyWithdrawOnBehalf(
        uint256 _nftId,
        address _poolToken,
        uint256 _withdrawAmount
    )
        external
        onlyWhiteList
        syncPool(_poolToken)
    {
        _reduceAllowance(
            _nftId,
            _poolToken,
            msg.sender,
            _withdrawAmount
        );

        _coreSolelyWithdraw(
            msg.sender,
            _nftId,
            _poolToken,
            _withdrawAmount
        );

        _safeTransfer(
            _poolToken,
            msg.sender,
            _withdrawAmount
        );

        emit FundsSolelyWithdrawnOnBehalf(
            msg.sender,
            _nftId,
            _poolToken,
            _withdrawAmount,
            block.timestamp
        );
    }

    /**
     * @dev Allows to withdraw privately
     * deposited ERC20 on behalf of owner.
     * Requires approval by _nftId owner.
     */
    function withdrawOnBehalfExactAmount(
        uint256 _nftId,
        address _poolToken,
        uint256 _withdrawAmount
    )
        external
        onlyWhiteList
        syncPool(_poolToken)
        returns (uint256)
    {
        _reduceAllowance(
            _nftId,
            _poolToken,
            msg.sender,
            _withdrawAmount
        );

        uint256 withdrawShares = calculateLendingShares(
            {
                _poolToken: _poolToken,
                _amount: _withdrawAmount,
                _maxSharePrice: true
            }
        );

        _coreWithdrawToken(
            msg.sender,
            _nftId,
            _poolToken,
            _withdrawAmount,
            withdrawShares
        );

        _safeTransfer(
            _poolToken,
            msg.sender,
            _withdrawAmount
        );

        emit FundsWithdrawnOnBehalf(
            msg.sender,
            _nftId,
            _poolToken,
            _withdrawAmount,
            withdrawShares,
            block.timestamp
        );

        return withdrawShares;
    }

    /**
     * @dev Allows to withdraw ERC20
     * funds using shares as input value
     */
    function withdrawExactShares(
        uint256 _nftId,
        address _poolToken,
        uint256 _shares
    )
        external
        syncPool(_poolToken)
        returns (uint256)
    {
        _checkOwnerPosition(
            _nftId,
            msg.sender
        );

        uint256 withdrawAmount = cashoutAmount(
            {
                _poolToken: _poolToken,
                _shares: _shares,
                _maxAmount: true
            }
        );

        _coreWithdrawToken(
            msg.sender,
            _nftId,
            _poolToken,
            withdrawAmount,
            _shares
        );

        _safeTransfer(
            _poolToken,
            msg.sender,
            withdrawAmount
        );

        emit FundsWithdrawn(
            msg.sender,
            _nftId,
            _poolToken,
            withdrawAmount,
            _shares,
            block.timestamp
        );

        return withdrawAmount;
    }

    /**
     * @dev Withdraws ERC20 funds on behalf
     * of _nftId owner, requires approval.
     */
    function withdrawOnBehalfExactShares(
        uint256 _nftId,
        address _poolToken,
        uint256 _shares
    )
        external
        onlyWhiteList
        syncPool(_poolToken)
        returns (uint256)
    {
        uint256 withdrawAmount = cashoutAmount(
            {
                _poolToken: _poolToken,
                _shares: _shares,
                _maxAmount: true
            }
        );

        _reduceAllowance(
            _nftId,
            _poolToken,
            msg.sender,
            withdrawAmount
        );

        _coreWithdrawToken(
            msg.sender,
            _nftId,
            _poolToken,
            withdrawAmount,
            _shares
        );

        _safeTransfer(
            _poolToken,
            msg.sender,
            withdrawAmount
        );

        emit FundsWithdrawnOnBehalf(
            msg.sender,
            _nftId,
            _poolToken,
            withdrawAmount,
            _shares,
            block.timestamp
        );

        return withdrawAmount;
    }

    // --------------- Borrow Functions -------------

    /**
     * @dev Allows to borrow ETH funds
     * Requires user to have collateral.
     */
    function borrowExactAmountETH(
        uint256 _nftId,
        uint256 _amount
    )
        external
        syncPool(WETH_ADDRESS)
        returns (uint256)
    {
        _checkOwnerPosition(
            _nftId,
            msg.sender
        );

        uint256 shares = calculateBorrowShares(
            {
                _poolToken: WETH_ADDRESS,
                _amount: _amount,
                _maxSharePrice: true
            }
        );

        _coreBorrowTokens(
            msg.sender,
            _nftId,
            WETH_ADDRESS,
            _amount,
            shares
        );

        _unwrapETH(
            _amount
        );

        _sendValue(
            msg.sender,
            _amount
        );

        emit FundsBorrowed(
            msg.sender,
            _nftId,
            WETH_ADDRESS,
            _amount,
            shares,
            block.timestamp
        );

        return shares;
    }

    /**
     * @dev Allows to borrow ERC20 funds
     * Requires user to have collateral.
     */
    function borrowExactAmount(
        uint256 _nftId,
        address _poolToken,
        uint256 _amount
    )
        external
        syncPool(_poolToken)
        returns (uint256)
    {
        _checkOwnerPosition(
            _nftId,
            msg.sender
        );

        uint256 shares = calculateBorrowShares(
            {
                _poolToken: _poolToken,
                _amount: _amount,
                _maxSharePrice: true
            }
        );

        _coreBorrowTokens(
            msg.sender,
            _nftId,
            _poolToken,
            _amount,
            shares
        );

        _safeTransfer(
            _poolToken,
            msg.sender,
            _amount
        );

        emit FundsBorrowed(
            msg.sender,
            _nftId,
            _poolToken,
            _amount,
            shares,
            block.timestamp
        );

        return shares;
    }

    /**
     * @dev Allows to borrow ERC20 funds
     * on behalf of _nftId owner, if approved.
     */
    function borrowOnBehalfExactAmount(
        uint256 _nftId,
        address _poolToken,
        uint256 _amount
    )
        external
        onlyWhiteList
        syncPool(_poolToken)
        returns (uint256)
    {
        _reduceAllowance(
            _nftId,
            _poolToken,
            msg.sender,
            _amount
        );

        uint256 shares = calculateBorrowShares(
            {
                _poolToken: _poolToken,
                _amount: _amount,
                _maxSharePrice: true
            }
        );

        _coreBorrowTokens(
            msg.sender,
            _nftId,
            _poolToken,
            _amount,
            shares
        );

        _safeTransfer(
            _poolToken,
            msg.sender,
            _amount
        );

        emit FundsBorrowedOnBehalf(
            msg.sender,
            _nftId,
            _poolToken,
            _amount,
            shares,
            block.timestamp
        );

        return shares;
    }

    // --------------- Payback Functions ------------

    /**
     * @dev Ability to payback ETH loans
     * by providing exact payback amount.
     */
    function paybackExactAmountETH(
        uint256 _nftId
    )
        external
        payable
        syncPool(WETH_ADDRESS)
        returns (uint256)
    {
        _checkPositionLocked(
            _nftId,
            msg.sender
        );

        uint256 maxBorrowShares = getPositionBorrowShares(
            _nftId,
            WETH_ADDRESS
        );

        uint256 maxPaybackAmount = paybackAmount(
            WETH_ADDRESS,
            maxBorrowShares
        );

        uint256 paybackShares = calculateBorrowShares(
            {
                _poolToken: WETH_ADDRESS,
                _amount: msg.value,
                _maxSharePrice: false
            }
        );

        uint256 refundAmount;
        uint256 requiredAmount = msg.value;

        if (msg.value > maxPaybackAmount) {

            unchecked {
                refundAmount = msg.value
                    - maxPaybackAmount;
            }

            requiredAmount = requiredAmount
                - refundAmount;

            paybackShares = maxBorrowShares;
        }

        _handlePayback(
            msg.sender,
            _nftId,
            WETH_ADDRESS,
            requiredAmount,
            paybackShares
        );

        _wrapETH(
            requiredAmount
        );

        if (refundAmount > 0) {
            _sendValue(
                msg.sender,
                refundAmount
            );
        }

        return paybackShares;
    }

    /**
     * @dev Ability to payback ERC20 loans
     * by providing exact payback amount.
     */
    function paybackExactAmount(
        uint256 _nftId,
        address _poolToken,
        uint256 _amount
    )
        external
        syncPool(_poolToken)
        returns (uint256)
    {
        _checkPositionLocked(
            _nftId,
            msg.sender
        );

        uint256 paybackShares = calculateBorrowShares(
            {
                _poolToken: _poolToken,
                _amount: _amount,
                _maxSharePrice: false
            }
        );

        _handlePayback(
            msg.sender,
            _nftId,
            _poolToken,
            _amount,
            paybackShares
        );

        _safeTransferFrom(
            _poolToken,
            msg.sender,
            address(this),
            _amount
        );

        return paybackShares;
    }

    /**
     * @dev Ability to payback ERC20 loans
     * by providing exact payback shares.
     */
    function paybackExactShares(
        uint256 _nftId,
        address _poolToken,
        uint256 _shares
    )
        external
        syncPool(_poolToken)
        returns (uint256)
    {
        _checkPositionLocked(
            _nftId,
            msg.sender
        );

        uint256 paybackAmount = paybackAmount(
            _poolToken,
            _shares
        );

        _handlePayback(
            msg.sender,
            _nftId,
            _poolToken,
            paybackAmount,
            _shares
        );

        _safeTransferFrom(
            _poolToken,
            msg.sender,
            address(this),
            paybackAmount
        );

        return paybackAmount;
    }

    // --------------- Liquidation Functions ------------

    /**
     * @dev Function to liquidate a postion which reaches
     * a debt ratio greater than 100%. The liquidator can choose
     * token to payback and receive. (Both can differ!). The
     * amount is in shares of the payback token. The liquidator
     * gets an incentive which is calculated inside the liquidation
     * logic.
     */
    function liquidatePartiallyFromTokens(
        uint256 _nftId,
        uint256 _nftIdLiquidator,
        address _paybackToken,
        address _receiveToken,
        uint256 _shareAmountToPay
    )
        external
        returns (uint256)
    {
        _preparationCollaterals(
            _nftId,
            ZERO_ADDRESS
        );

        _preparationBorrows(
            _nftId,
            ZERO_ADDRESS
        );

        _checkPositionLocked(
            _nftId,
            msg.sender
        );

        WISE_SECURITY.checksLiquidation(
            _nftId,
            _paybackToken,
            _shareAmountToPay
        );

        uint256 paybackAmount = paybackAmount(
            _paybackToken,
            _shareAmountToPay
        );

        return _coreLiquidation(
            _nftId,
            _nftIdLiquidator,
            msg.sender,
            msg.sender,
            _paybackToken,
            _receiveToken,
            paybackAmount,
            _shareAmountToPay,
            WISE_SECURITY.maxFeeETH(),
            WISE_SECURITY.baseRewardLiquidation()
        );
    }

    /**
     * @dev Wrapper function for liqudaiton flow of
     * power farms.
     */
    function coreLiquidationIsolationPools(
        uint256 _nftId,
        uint256 _nftIdLiquidator,
        address _caller,
        address _receiver,
        address _paybackToken,
        address _receiveToken,
        uint256 _paybackAmount,
        uint256 _shareAmountToPay
    )
        external
        returns (uint256)
    {
        _onlyIsolationPool(
            msg.sender
        );

        return _coreLiquidation(
            _nftId,
            _nftIdLiquidator,
            _caller,
            _receiver,
            _paybackToken,
            _receiveToken,
            _paybackAmount,
            _shareAmountToPay,
            WISE_SECURITY.maxFeeFarmETH(),
            WISE_SECURITY.baseRewardLiquidationFarm()
        );
    }

    /**
     * @dev Allows to sync pool manually
     * so that the pool is up to date.
     */
    function syncManually(
        address _poolToken
    )
        external
        syncPool(_poolToken)
    {
        emit PoolSynced(
            _poolToken,
            block.timestamp
        );
    }

    /**
     * @dev Registers position _nftId
     * for isolation pool functionality
     */
    function setRegistrationIsolationPool(
        uint256 _nftId,
        bool _registerState
    )
        external
    {
        _onlyIsolationPool(
            msg.sender
        );

        positionLocked[_nftId] = _registerState;
    }

    /**
     * @dev Wrapper for isolation pool check.
     */
    function _onlyIsolationPool(
        address _poolAddress
    )
        private
        view
    {
        if (verifiedIsolationPool[_poolAddress] == false) {
            revert NotVerfiedPool();
        }
    }
}
