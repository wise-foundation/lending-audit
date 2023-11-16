// SPDX-License-Identifier: -- WISE --
pragma solidity =0.8.21;

import "./WiseIsolationHelper.sol";

contract WiseIsolationMode is WiseIsolationHelper {

    modifier updatePoolCollateral() {
        _updatePoolCollateral();
        _;
    }

    modifier updatePoolsBorrow() {
        _updatePoolsBorrow();
        _;
    }

    constructor(
        address _oracleHubAddress,
        address _wiseLendingAddress,
        address _wiseLiquidationAddress,
        address _collateralTokenAddress,
        address _wiseSecurityAddress,
        uint256 _collateralFactor,
        // uint256 _borrowPercentageCap,
        address[] memory _borrowTokenAddresses,
        uint256[] memory _portionTotalBorrow
    )
        Declarations(
            _oracleHubAddress,
            _wiseLendingAddress,
            _wiseLiquidationAddress,
            _collateralTokenAddress,
            _wiseSecurityAddress,
            _collateralFactor,
            _borrowTokenAddresses,
            _portionTotalBorrow
        )
    {}

    function registrationFarm(
        uint256 _nftId,
        uint256 _index
    )
        external
    {
        WISE_SECURITY.checksRegister(
            _nftId,
            msg.sender
        );

        if (nftToIndex[_nftId] != 0) {
            revert AlreadySet();
        }

        nftToIndex[_nftId] = _index;

        WISE_LENDING.setRegistrationIsolationPool(
            _nftId,
            true
        );

        emit RegistrationFarm(
            _nftId,
            _index,
            block.timestamp
        );
    }

    function unregistrationFarm(
        uint256 _nftId
    )
        external
    {
        WISE_SECURITY.checksRegister(
            _nftId,
            msg.sender
        );

        uint256 previousIndex = nftToIndex[
            _nftId
        ];

        nftToIndex[_nftId] = 0;

        WISE_LENDING.setRegistrationIsolationPool(
            _nftId,
            false
        );

        emit UnregistrationFarm(
            _nftId,
            previousIndex,
            block.timestamp
        );
    }

    function _updatePoolsBorrow()
        private
    {
        uint256 i;
        uint256 l = borrowTokenNumber;

        for (i; i < l;) {
            address currentAddress = borrowTokenAddresses[i];

            WISE_LENDING.preparePool(
                currentAddress
            );

            unchecked {
                ++i;
            }
        }
    }

    function _updatePoolCollateral()
        private
    {
        WISE_LENDING.preparePool(
            COLLATERAL_TOKEN_ADDRESS
        );
    }

    function depositExactAmount(
        uint256 _nftId,
        uint256 _amount
    )
        external
        returns (uint256 shares)
    {
        require(
            _checkMinDepositAmount(_amount),
            "WiseIsolation: AMOUNT_TOO_LOW"
        );

        _safeTransferFrom(
            COLLATERAL_TOKEN_ADDRESS,
            msg.sender,
            address(this),
            _amount
        );

        shares = WISE_LENDING.depositExactAmount(
            _nftId,
            COLLATERAL_TOKEN_ADDRESS,
            _amount
        );

        emit IsDepositIsolationPool(
            _nftId,
            block.timestamp
        );
    }

    function withdrawExactAmount(
        uint256 _nftId,
        uint256 _amount
    )
        external
        updatePoolCollateral
        updatePoolsBorrow
        returns (uint256 shares)
    {
        if (checkDebtratioWithdraw(_nftId, _amount)) {
            revert ResultsInBadDebt();
        }

        shares = WISE_LENDING.withdrawOnBehalfExactAmount(
            _nftId,
            COLLATERAL_TOKEN_ADDRESS,
            _amount
        );

        _safeTransfer(
            COLLATERAL_TOKEN_ADDRESS,
            msg.sender,
            _amount
        );

        emit IsWithdrawIsolationPool(
            _nftId,
            block.timestamp
        );
    }

    function withdrawExactShares(
        uint256 _nftId,
        uint256 _share
    )
        external
        updatePoolCollateral
        updatePoolsBorrow
        returns (uint256 amount)
    {
        amount = WISE_LENDING.cashoutAmount(
            {
                _poolToken: COLLATERAL_TOKEN_ADDRESS,
                _shares: _share,
                _maxAmount: false
            }
        );

        if (checkDebtratioWithdraw(_nftId, amount)) {
            revert ResultsInBadDebt();
        }

        WISE_LENDING.withdrawOnBehalfExactShares(
            _nftId,
            COLLATERAL_TOKEN_ADDRESS,
            _share
        );

        _safeTransfer(
            COLLATERAL_TOKEN_ADDRESS,
            msg.sender,
            amount
        );

        emit IsWithdrawIsolationPool(
            _nftId,
            block.timestamp
        );
    }

    function borrowExactDebtRatio(
        uint256 _nftId,
        uint256 _targetDebtRatio
    )
        external
        updatePoolCollateral
        updatePoolsBorrow
        returns (uint256[] memory borrowAmounts)
    {
        uint256 borrowUSD = getBorrowAmountFromDebtratio(
            _nftId,
            _targetDebtRatio
        );

        borrowAmounts = _coreBorrowIsolationMode(
            _nftId,
            msg.sender,
            borrowUSD
        );

        emit IsBorrowIsolationPool(
            _nftId,
            block.timestamp
        );
    }

    function borrowExactUSD(
        uint256 _nftId,
        uint256 _usdAmount
    )
        external
        updatePoolCollateral
        updatePoolsBorrow
        returns (uint256[] memory borrowAmounts)
    {
        borrowAmounts = _coreBorrowIsolationMode(
            _nftId,
            msg.sender,
            _usdAmount
        );

        emit IsBorrowIsolationPool(
            _nftId,
            block.timestamp
        );
    }

    function paybackExactDebtratio(
        uint256 _nftId,
        uint256 _targetDebtratio
    )
        external
        updatePoolCollateral
        updatePoolsBorrow
        returns (uint256[] memory paybackAmounts)
    {
        uint256 paybackUSD = getPaybackAmountFromDebtRatio(
            _nftId,
            _targetDebtratio
        );

        paybackAmounts = _corePaybackIsolationMode(
            _nftId,
            msg.sender,
            paybackUSD
        );

        emit IsPaybackIsolationPool(
            _nftId,
            block.timestamp
        );
    }

    function paybackExactUSD(
        uint256 _nftId,
        uint256 _usdAmount
    )
        external
        updatePoolsBorrow
        returns (uint256[] memory paybackAmounts)
    {
        paybackAmounts = _corePaybackIsolationMode(
            _nftId,
            msg.sender,
            _usdAmount
        );

        emit IsPaybackIsolationPool(
            _nftId,
            block.timestamp
        );
    }

    function paybackAll(
        uint256 _nftId
    )
        external
        updatePoolsBorrow
        returns (uint256[] memory)
    {
        uint256 borrowShares;
        address borrowTokenAddress;

        uint256[] memory paybackAmounts = new uint256[](
            borrowTokenNumber
        );

        uint256 i;
        uint256 l = borrowTokenNumber;

        for (i; i < l;) {

            borrowTokenAddress = borrowTokenAddresses[i];
            borrowTokenAddress = borrowTokenAddresses[i];

            borrowShares = WISE_LENDING.getPositionBorrowShares(
                _nftId,
                borrowTokenAddress
            );

            paybackAmounts[i] = WISE_LENDING.paybackAmount(
                borrowTokenAddress,
                borrowShares
            );

            _safeTransferFrom(
                borrowTokenAddress,
                msg.sender,
                address(this),
                paybackAmounts[i]
            );

            WISE_LENDING.paybackExactShares(
                _nftId,
                borrowTokenAddress,
                borrowShares
            );

            unchecked {
                ++i;
            }
        }

        emit IsPaybackIsolationPool(
            _nftId,
            block.timestamp
        );

        return paybackAmounts;
    }

    function liquidationUSDAmount(
        uint256 _nftId,
        uint256 _nftIdLiquidator,
        uint256 _usdAmount
    )
        external
        updatePoolCollateral
        updatePoolsBorrow
        returns (
            uint256[] memory paybackAmounts,
            uint256[] memory receivingAmount
        )
    {
        (
            paybackAmounts,
            receivingAmount
        )
            = _coreLiquidation(
                _nftId,
                _nftIdLiquidator,
                msg.sender,
                _usdAmount
            );

        emit LiquidatedIsolationPool(
            _nftId,
            msg.sender,
            borrowTokenAddresses,
            COLLATERAL_TOKEN_ADDRESS,
            _usdAmount,
            block.timestamp
        );
    }

    function getLiveDebtRatio(
        uint256 _nftId
    )
        external
        view
        returns (uint256)
    {
        uint256 totalCollateral = getTotalWeightedCollateralUSD(
            _nftId
        );

        if (totalCollateral == 0) {
            return 0;
        }

        return getTotalBorrowUSD(_nftId)
            * PRECISION_FACTOR_E18
            / totalCollateral;
    }
}
