// SPDX-License-Identifier: -- WISE --
pragma solidity =0.8.21;

import "./Declarations.sol";
import "../TransferHub/TransferHelper.sol";

abstract contract WiseIsolationHelper is Declarations, TransferHelper {

    function getTotalBorrowUSD(
        uint256 _nftId
    )
        public
        view
        returns (uint256 borrowUSD)
    {
        uint256 i;
        uint256 l = borrowTokenAddresses.length;

        for (i; i < l;) {
            borrowUSD += getUserBorrowUSD(
                _nftId,
                borrowTokenAddresses[i]
            );

            unchecked {
                ++i;
            }
        }
    }

    function getUserBorrowUSD(
        uint256 _nftId,
        address _poolToken
    )
        public
        view
        returns (uint256)
    {
        uint256 tokens = WISE_LENDING.paybackAmount(
            _poolToken,
            WISE_LENDING.getPositionBorrowShares(
                _nftId,
                _poolToken
            )
        );

        return ORACLE_HUB.getTokensInUSD(
            _poolToken,
            tokens
        );
    }

    function getTotalWeightedCollateralUSD(
        uint256 _nftId
    )
        public
        view
        returns (uint256)
    {
        uint256 tokens = WISE_LENDING.cashoutAmount(
            {
                _poolToken: COLLATERAL_TOKEN_ADDRESS,
                _shares: WISE_LENDING.getPositionLendingShares(
                    _nftId,
                    COLLATERAL_TOKEN_ADDRESS
                ),
                _maxAmount: false
            }
        );

        return collateralFactor
            * ORACLE_HUB.getTokensInUSD(
                COLLATERAL_TOKEN_ADDRESS,
                tokens
            )
            / PRECISION_FACTOR_E18;
    }

    function getTokenAmountsFromUSD(
        uint256 _usdBorrow,
        uint256 _tokenPortion,
        address _borrowTokenAddresses
    )
        public
        view
        returns (uint256 amount)
    {
        uint256 portionUSD = _usdBorrow
            * _tokenPortion
            / PRECISION_FACTOR_E18;

        amount = ORACLE_HUB.getTokensFromUSD(
            _borrowTokenAddresses,
            portionUSD
        );
    }

    function getBorrowAmountFromDebtratio(
        uint256 _nftId,
        uint256 _targetDebtratio
    )
        public
        view
        returns (uint256)
    {
        uint256 usdCollateral = getTotalWeightedCollateralUSD(
            _nftId
        );

        return usdCollateral
            * _targetDebtratio
            / PRECISION_FACTOR_E18;
    }

    function getPaybackAmountFromDebtRatio(
        uint256 _nftId,
        uint256 _targetDebtratio
    )
        public
        view
        returns (uint256)
    {
        uint256 usdBorrow = getTotalBorrowUSD(
            _nftId
        );

        uint256 usdCollateral = getTotalWeightedCollateralUSD(
            _nftId
        );

        return usdBorrow
            - usdCollateral
            * _targetDebtratio
            / PRECISION_FACTOR_E18;
    }

    function checkDebtratioBorrow(
        uint256 _nftId,
        uint256 _borrowAmountUSD
    )
        public
        view
        returns (bool)
    {
        return getTotalWeightedCollateralUSD(_nftId)
            > getTotalBorrowUSD(_nftId) + _borrowAmountUSD;
    }

    function checkDebtratioWithdraw(
        uint256 _nftId,
        uint256 _withdrawAmount
    )
        public
        view
        returns (bool)
    {
        uint256 totalBorrow = getTotalBorrowUSD(
            _nftId
        );

        if (totalBorrow == 0) {
            return false;
        }

        return getTotalWeightedCollateralUSD(_nftId)
            - ORACLE_HUB.getTokensInUSD(
                COLLATERAL_TOKEN_ADDRESS,
                _withdrawAmount
            )
            * collateralFactor
            / PRECISION_FACTOR_E18
            < totalBorrow;
    }

    function checkDebtratio(
        uint256 _nftId
    )
        public
        view
        returns (bool)
    {
        return getTotalWeightedCollateralUSD(_nftId)
            > getTotalBorrowUSD(_nftId);
    }

    function _coreLiquidation(
        uint256 _nftId,
        uint256 _nftIdLiquidator,
        address _caller,
        uint256 _usdAmount
    )
        internal
        returns (uint256[] memory, uint256[] memory)
    {
        if (checkDebtratio(_nftId) == true) {
            revert("WiseIsolation: TOO_LOW");
        }

        uint256[] memory paybackAmounts = new uint256[](
            borrowTokenNumber
        );

        uint256[] memory receivingAmount = new uint256[](
            borrowTokenNumber
        );

        uint256 i;
        uint256 l = borrowTokenNumber;

        for (i; i < l;) {

            paybackAmounts[i] = getTokenAmountsFromUSD(
                _usdAmount,
                portionTotalBorrow[i],
                borrowTokenAddresses[i]
            );

            receivingAmount[i] = WISE_LIQUIDATION.coreLiquidationIsolationPools(
                _nftId,
                _nftIdLiquidator,
                _caller,
                _caller,
                borrowTokenAddresses[i],
                COLLATERAL_TOKEN_ADDRESS,
                paybackAmounts[i],
                WISE_LENDING.calculateBorrowShares(
                    {
                        _poolToken: borrowTokenAddresses[i],
                        _amount: paybackAmounts[i],
                        _maxSharePrice: false
                    }
                )
            );

            unchecked {
                ++i;
            }
        }

        return (paybackAmounts, receivingAmount);
    }

    function _corePaybackIsolationMode(
        uint256 _nftId,
        address _caller,
        uint256 _usdAmount
    )
        internal
        returns (uint256[] memory)
    {
        uint256 i;
        address borrowTokenAddress;

        uint256[] memory paybackAmounts = new uint256[](
            borrowTokenNumber
        );

        uint256 l = borrowTokenNumber;

        for (i; i < l;) {

            borrowTokenAddress = borrowTokenAddresses[i];
            paybackAmounts[i] = getTokenAmountsFromUSD(
                _usdAmount,
                portionTotalBorrow[i],
                borrowTokenAddress
            );

            _safeTransferFrom(
                borrowTokenAddress,
                _caller,
                address(this),
                paybackAmounts[i]
            );

            WISE_LENDING.paybackExactAmount(
                _nftId,
                borrowTokenAddress,
                paybackAmounts[i]
            );

            unchecked {
                ++i;
            }
        }

        return paybackAmounts;
    }

    function _coreBorrowIsolationMode(
        uint256 _nftId,
        address _caller,
        uint256 _usdAmount
    )
        internal
        returns (uint256[] memory)
    {
        uint256 i;
        address borrowTokenAddress;

        uint256[] memory borrowAmounts = new uint256[](
            borrowTokenNumber
        );

        if (checkDebtratioBorrow(_nftId, _usdAmount) == false) {
            revert("WiseIsolation: OWE_TOO_MUCH");
        }

        uint256 l = borrowTokenNumber;

        for (i; i < l;) {

            borrowTokenAddress = borrowTokenAddresses[i];
            borrowAmounts[i] = getTokenAmountsFromUSD(
                _usdAmount,
                portionTotalBorrow[i],
                borrowTokenAddress
            );

            WISE_LENDING.borrowOnBehalfExactAmount(
                _nftId,
                borrowTokenAddress,
                borrowAmounts[i]
            );

            _safeTransfer(
                borrowTokenAddress,
                _caller,
                borrowAmounts[i]
            );

            unchecked {
                ++i;
            }
        }

        return borrowAmounts;
    }

    function _checkMinDepositAmount(
        uint256 _amount
    )
        internal
        view
        returns (bool)
    {
        return ORACLE_HUB.getTokensInUSD(
            COLLATERAL_TOKEN_ADDRESS,
            _amount
        ) >= MIN_DEPOSIT_USD_AMOUNT;
    }
}
