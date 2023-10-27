// SPDX-License-Identifier: -- WISE --

pragma solidity =0.8.21;

/**
 * @author Christoph Krpoun
 * @author René Hochmuth
 * @author Vitally Marinchenko
 */

import "./sDaiFarm.sol";
import "../PowerFarmNFTs/MinterReserver.sol";

/**
 * @dev The sDai power farm is an automated leverage contract working as a
 * second layer for Wise lending. It needs to be registed inside the latter one
 * to have access to the pools. It uses BALANCER FLASHLOANS as well as UNISWAPV3,
 * the sDAI contract and the DSS-PSM contract for fee-less exchanging of USDC <-> DAI.
 * The corresponding contract addresses can be found in {sDaiFarmDeclarations.sol}.
 *
 * It allows to open leverage positions with different stable borrow tokens, namely
 * USDC, USDT and DAI. For opening a position the user needs to have {_initalAmount}
 * of DAI in the wallet. A maximum of 15x leverage is possible. Once the user
 * registers with its position NFT that NFT is locked for ALL other interactions with
 * wise lending as long as the positon is open!
 *
 * For more infos see {https://wisesoft.gitbook.io/wise/}
 */

contract sDaiFarmManager is sDaiFarm, MinterReserver {

    constructor(
        address _wiseLendingAddress,
        uint256 _collateralFactor,
        address _powerFarmNFTs
    )
        sDaiFarmDeclarations(
            _wiseLendingAddress,
            _collateralFactor
        )
        MinterReserver(
            _powerFarmNFTs
        )
    {}

    /**
     * @dev External function deactivating the power farm by
     * disableing the openPosition function. Allowing user
     * to manualy payback and withdraw.
     */
    function shutDownFarm(
        bool _state
    )
        external
        onlyMaster
    {
        isShutdown = _state;
    }

    function enterFarm(
        uint256 _index,
        uint256 _initialAmount,
        uint256 _leverage,
        uint256 _minOutAmount
    )
        external
        isActive
        returns (uint256)
    {
        uint256 wiseLendingNFT = _getWiseLendingNFT(
            _index
        );

        _updatePools(
            aaveTokenAddresses[
                _index
            ]
        );

        _storeIndex(
            _index,
            wiseLendingNFT
        );

        _openPosition(
            wiseLendingNFT,
            _initialAmount,
            _leverage,
            _minOutAmount
        );

        uint256 keyId = _reserveKey(
            msg.sender,
            wiseLendingNFT
        );

        emit FarmEntry(
            keyId,
            wiseLendingNFT,
            _leverage,
            _initialAmount,
            _minOutAmount,
            block.timestamp
        );

        return keyId;
    }

    /**
     * @dev Function to close a leveraged position. User
     * must be the owner of the used position with {_keyId}.
     * The return token is DAI and gets directly transferd in
     * the owners wallet after closing.
     * {_maxInAmount} needs to be passed from the UI when USDT
     * is used as borrow token. (querring quoteExactOutputSingle
     * with a callStatic from quoterContract [uniswapV3])
     */
    function exitFarm(
        uint256 _keyId,
        uint256 _maxInAmount
    )
        external
        onlyKeyOwner(_keyId)
    {
        uint256 wiseLendingNFT = farmingKeys[
            _keyId
        ];

        _updatePools(
            _getTokenAddressFromId(
                wiseLendingNFT
            )
        );

        delete farmingKeys[
            _keyId
        ];

        if (reservedKeys[msg.sender] == _keyId) {
            reservedKeys[msg.sender] = 0;
        } else {
            FARMS_NFTS.burnKey(
                _keyId
            );
        }

        emit FarmExit(
            _keyId,
            wiseLendingNFT,
            _maxInAmount,
            block.timestamp
        );

        availableNFTs[
            ++availableNFTCount
        ] = wiseLendingNFT;

        _closingPosition(
            wiseLendingNFT,
            _maxInAmount
        );
    }

    function _getWiseLendingNFT(
        uint256 _tokenIndex
    )
        internal
        returns (uint256)
    {
        if (availableNFTCount > 0) {
            return availableNFTs[
                availableNFTCount--
            ];
        }

        uint256 nftId = POSITION_NFT.mintPositionForUser(
            address(this)
        );

        _registrationFarm(
            nftId,
            _tokenIndex
        );

        POSITION_NFT.approve(
            AAVE_HUB_ADDRESS,
            nftId
        );

        return nftId;
    }

    function _storeIndex(
        uint256 _index,
        uint256 _nftId
    )
        internal
    {
        nftToIndex[_nftId] = _index;
    }

    function _getTokenAddressFromId(
        uint256 _nftId
    )
        internal
        view
        returns (address)
    {
        return aaveTokenAddresses[
            nftToIndex[_nftId]
        ];
    }

    /**
     * @dev Manually payback function for users. Takes
     * {_paybackShares} which can be converted
     * into token with {paybackAmount()} or vice verse
     * with {calculateBorrowShares()} from wise lending
     * contract.
     */
    function manuallyPaybackShares(
        uint256 _keyId,
        uint256 _paybackShares
    )
        external
    {
        uint256 nftId = farmingKeys[
            _keyId
        ];

        address paybackTokenAddress = _getTokenAddressFromId(
            nftId
        );

        _updatePools(
            paybackTokenAddress
        );

        uint256 paybackAmount = WISE_LENDING.paybackAmount(
            paybackTokenAddress,
            _paybackShares
        );

        _safeTransferFrom(
            paybackTokenAddress,
            msg.sender,
            address(this),
            paybackAmount
        );

        WISE_LENDING.paybackExactShares(
            nftId,
            paybackTokenAddress,
            _paybackShares
        );
    }

    /**
     * @dev Manually withdraw function for users. Takes
     * {_withdrawShares} which can be converted
     * into token with {cashoutAmount()} or vice verse
     * with {calculateLendingShares()} from wise lending
     * contract.
     */
    function manuallyWithdrawShares(
        uint256 _keyId,
        uint256 _withdrawShares
    )
        external
        onlyKeyOwner(_keyId)
    {
        uint256 nftId = farmingKeys[
            _keyId
        ];

        _updatePools(
            _getTokenAddressFromId(
                nftId
            )
        );

        uint256 withdrawAmount = WISE_LENDING.cashoutAmount(
            SDAI_ADDRESS,
            _withdrawShares
        );

        if (_checkBorrowLimit(nftId, SDAI_ADDRESS, withdrawAmount) == false) {
            revert ResultsInBadDebt();
        }

        withdrawAmount = WISE_LENDING.withdrawExactShares(
            nftId,
            SDAI_ADDRESS,
            _withdrawShares
        );

        _safeTransfer(
            SDAI_ADDRESS,
            msg.sender,
            withdrawAmount
        );
    }

    /**
     * @dev Liquidation function for open power farm
     * postions which have a debtratio greater 100 %.
     *
     * NOTE: The borrow token is defined by the positon
     * and thus cannot be usseted by the liquidator.
     * Since the token are borrwed from an aave pool it
     * is always an aave token derivative!
     * The receiving token is always sDAI.
     */
    function liquidatePartiallyFromToken(
        uint256 _nftId,
        uint256 _nftIdLiquidator,
        uint256 _shareAmountToPay
    )
        external
        returns (
            uint256 paybackAmount,
            uint256 receivingAmount
        )
    {
        _updatePools(
            _getTokenAddressFromId(
                _nftId
            )
        );

        return _coreLiquidation(
            _nftId,
            _nftIdLiquidator,
            _shareAmountToPay
        );
    }
}
