// SPDX-License-Identifier: -- WISE --

pragma solidity =0.8.24;

/**
 * @author René Hochmuth
 * @author Christoph Krpoun
 * @author Vitally Marinchenko
 */

import "../OwnableMaster.sol";

import "./GenericPowerFarm.sol";
import "./PowerFarmNFTs/MinterReserver.sol";

contract GenericPowerManager is
    OwnableMaster,
    GenericPowerFarm,
    MinterReserver
{
    receive()
        external
        payable
        virtual
    {
        emit ETHReceived(
            msg.value,
            msg.sender
        );

        if (msg.sender == WETH_ADDRESS) {
            return;
        }

        if (sendingProgress == true) {
            revert GenericSendingOnGoing();
        }

        _sendValue(
            master,
            msg.value
        );
    }

    constructor(
        address _wiseLendingAddress,
        address _pendleChildTokenAddress,
        address _pendleRouter,
        address _entryAsset,
        address _pendleSy,
        address _underlyingMarket,
        address _routerStatic,
        address _dexAddress,
        uint256 _collateralFactor,
        address _powerFarmNFTs
    )
        OwnableMaster(msg.sender)
        MinterReserver(_powerFarmNFTs)
        GenericDeclarations(
            _wiseLendingAddress,
            _pendleChildTokenAddress,
            _pendleRouter,
            _entryAsset,
            _pendleSy,
            _underlyingMarket,
            _routerStatic,
            _dexAddress,
            _collateralFactor
        )
    {}

    function setSpecialDepegCase(
        bool _state
    )
        external
        virtual
        onlyMaster
    {
        specialDepegCase = _state;
    }

    function revokeCollateralFactorRole()
        public
        virtual
        onlyCollateralFactorRole
    {
        collateralFactorRole = ZERO_ADDRESS;
    }

    function setCollateralFactor(
        uint256 _newCollateralFactor
    )
        external
        override
        onlyCollateralFactorRole()
    {
        collateralFactor = _newCollateralFactor;
    }

    function changeMinDeposit(
        uint256 _newMinDeposit
    )
        external
        virtual
        onlyMaster
    {
        minDepositEthAmount = _newMinDeposit;

        emit MinDepositChange(
            _newMinDeposit,
            block.timestamp
        );
    }

    /**
     * @dev External function deactivating the power farm by
     * disableing the openPosition function. Allowing user
     * to manualy payback and withdraw.
     */
    function shutDownFarm(
        bool _state
    )
        external
        virtual
        onlyMaster
    {
        isShutdown = _state;

        emit FarmStatus(
            _state,
            block.timestamp
        );
    }

    function enterFarm(
        bool _isAave,
        uint256 _amount,
        uint256 _leverage,
        uint256 _allowedSpread
    )
        external
        virtual
        isActive
        updatePools
        returns (uint256)
    {
        uint256 wiseLendingNFT = _getWiseLendingNFT();

        _safeTransferFrom(
            FARM_ASSET,
            msg.sender,
            address(this),
            _amount
        );

        _openPosition(
            _isAave,
            wiseLendingNFT,
            _amount,
            _leverage,
            _allowedSpread
        );

        uint256 keyId = _reserveKey(
            msg.sender,
            wiseLendingNFT
        );

        isAave[wiseLendingNFT] = _isAave;

        _storeData(
            keyId,
            wiseLendingNFT,
            _leverage,
            _amount,
            getTokenAmountEquivalentInFarmAsset(wiseLendingNFT),
            block.timestamp
        );

        return keyId;
    }

    function _storeData(
        uint256 _keyId,
        uint256 _wiseLendingNFT,
        uint256 _leverage,
        uint256 _amount,
        uint256 _amountAfterMintFee,
        uint256 _timestamp
    )
        internal
        virtual
    {
        FarmData memory FarmData = FarmData(
            _wiseLendingNFT,
            _leverage,
            _amount,
            _amountAfterMintFee,
            _timestamp
        );

        farmData[_keyId] = FarmData;

        emit FarmEntry(
            _keyId,
            _wiseLendingNFT,
            _leverage,
            _amount,
            _amountAfterMintFee,
            _timestamp
        );
    }

    function enterFarmETH(
        bool _isAave,
        uint256 _leverage,
        uint256 _allowedSpread
    )
        external
        virtual
        payable
        isActive
        updatePools
        returns (uint256)
    {
        uint256 wiseLendingNFT = _getWiseLendingNFT();

        _wrapETH(
            msg.value
        );

        _openPosition(
            _isAave,
            wiseLendingNFT,
            msg.value,
            _leverage,
            _allowedSpread
        );

        uint256 keyId = _reserveKey(
            msg.sender,
            wiseLendingNFT
        );

        isAave[wiseLendingNFT] = _isAave;

        _storeData(
            keyId,
            wiseLendingNFT,
            _leverage,
            msg.value,
            getTokenAmountEquivalentInFarmAsset(wiseLendingNFT),
            block.timestamp
        );

        return keyId;
    }

    function _getWiseLendingNFT()
        internal
        virtual
        returns (uint256)
    {
        if (availableNFTCount == 0) {

            uint256 nftId = POSITION_NFT.mintPosition();

            _registrationFarm(
                nftId
            );

            POSITION_NFT.approve(
                AAVE_HUB_ADDRESS,
                nftId
            );

            return nftId;
        }

        return availableNFTs[
            availableNFTCount--
        ];
    }

    function exitFarm(
        uint256 _keyId,
        uint256 _allowedSpread,
        bool _ethBack
    )
        external
        virtual
        updatePools
        onlyKeyOwner(_keyId)
    {
        uint256 wiseLendingNFT = farmingKeys[
            _keyId
        ];

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

        availableNFTs[
            ++availableNFTCount
        ] = wiseLendingNFT;

        _closingPosition(
            isAave[wiseLendingNFT],
            wiseLendingNFT,
            _allowedSpread,
            _ethBack
        );

        emit FarmExit(
            _keyId,
            wiseLendingNFT,
            _allowedSpread,
            block.timestamp
        );
    }

    function manuallyPaybackShares(
        uint256 _keyId,
        uint256 _paybackShares
    )
        external
        virtual
        updatePools
    {
        _manuallyPaybackShares(
            farmingKeys[_keyId],
            _paybackShares
        );

        emit ManualPaybackShares(
            _keyId,
            farmingKeys[_keyId],
            _paybackShares,
            block.timestamp
        );
    }

    function manuallyWithdrawShares(
        uint256 _keyId,
        uint256 _withdrawShares
    )
        external
        virtual
        updatePools
        onlyKeyOwner(_keyId)
    {
        uint256 wiseLendingNFT = farmingKeys[
            _keyId
        ];

        _manuallyWithdrawShares(
            wiseLendingNFT,
            _withdrawShares
        );

        if (_checkDebtRatio(wiseLendingNFT) == false) {
            revert GenericDebtRatioTooHigh();
        }

        emit ManualWithdrawShares(
            _keyId,
            wiseLendingNFT,
            _withdrawShares,
            block.timestamp
        );
    }
}
