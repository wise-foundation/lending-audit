// SPDX-License-Identifier: -- WISE --

pragma solidity =0.8.21;

/**
 * @author Christoph Krpoun
 * @author René Hochmuth
 * @author Vitally Marinchenko
 */

import "./PendleWstETHFarm.sol";
import "../PowerFarmNFTs/MinterReserver.sol";

contract PendleWstETHManager is PendleWstETHFarm, MinterReserver {

    /**
     * @dev Standard receive functions forwarding
     * directly send ETH to the master address.
     */
    receive()
        external
        payable
    {
        emit ETHReceived(
            msg.value,
            msg.sender
        );
    }

    constructor(
        address _wiseLending,
        address _lockContract,
        uint256 _collateralFactor,
        address _powerFarmNFTs
    )
        MinterReserver(
            _powerFarmNFTs
        )
        PendleWstETHDeclarations(
            _wiseLending,
            _lockContract,
            _collateralFactor
        )
    {
        _approveTokens();
    }

    function _approveTokens()
        internal
    {
        _safeApprove(
            address(HYBRID_TOKEN),
            address(WISE_LENDING),
            MAX_AMOUNT
        );

        _safeApprove(
            WST_ETH_ADDRESS,
            SY_PENDLE_ADDRESS,
            MAX_AMOUNT
        );

        _safeApprove(
            ST_ETH_ADDRESS,
            WST_ETH_ADDRESS,
            MAX_AMOUNT
        );

        _safeApprove(
            ST_ETH_ADDRESS,
            CURVE_POOL_ADDRESS,
            MAX_AMOUNT
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
        onlyMaster
    {
        isShutdown = _state;
    }

    /**
     * @dev External set function to change referral address
     * for lido staking. Can only be called by master.
     */
    function changeRefAddress(
        address _newAddress
    )
        external
        onlyMaster
    {
        referralAddress = _newAddress;
    }

    function enterFarm(
        uint256 _amount,
        uint256 _leverage,
        uint256 _overhangFetched,
        bool _ptGreaterFetched,
        bytes calldata _swapDataFetched
    )
        external
        isActive
        updatePools
        returns (uint256)
    {
        uint256 wiseLendingNFT = _getWiseLendingNFT();

        _safeTransferFrom(
            WETH_ADDRESS,
            msg.sender,
            address(this),
            _amount
        );

        _openPosition(
            wiseLendingNFT,
            _amount,
            _leverage,
            _overhangFetched,
            _ptGreaterFetched,
            _swapDataFetched
        );

        return _reserveKey(
            msg.sender,
            wiseLendingNFT
        );
    }

    function enterFarmETH(
        uint256 _leverage,
        uint256 _overhangFetched,
        bool _ptGreaterFetched,
        bytes calldata _swapDataFetched
    )
        external
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
            wiseLendingNFT,
            msg.value,
            _leverage,
            _overhangFetched,
            _ptGreaterFetched,
            _swapDataFetched
        );

        return _reserveKey(
            msg.sender,
            wiseLendingNFT
        );
    }

    function _getWiseLendingNFT()
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
            nftId
        );

        POSITION_NFT.approve(
            AAVE_HUB_ADDRESS,
            nftId
        );

        return nftId;
    }

    function exitFarm(
        uint256 _keyId,
        uint256 _minOutAmount,
        bool _ethBack,
        uint256 _overhangFetched,
        bool _ptGreaterFetched,
        bytes calldata _swapDataFetched
    )
        external
        updatePools
        onlyKeyOwner(_keyId)
    {
        uint256 wiseLendingNFT = farmingKeys[
            _keyId
        ];

        delete farmingKeys[
            _keyId
        ];

        FARMS_NFTS.burnKey(
            _keyId
        );

        availableNFTs[
            ++availableNFTCount
        ] = wiseLendingNFT;

        _closingPosition(
            wiseLendingNFT,
            _minOutAmount,
            _ethBack,
            _overhangFetched,
            _ptGreaterFetched,
            _swapDataFetched
        );
    }

    /*
    function manuallyPaybackShares(
        uint256 _keyId,
        uint256 _paybackShares
    )
        external
        updatePools
    {
        _manuallyPaybackShares(
            farmingKeys[_keyId],
            _paybackShares
        );
    }
    */

    /*
    function manuallyWithdrawShares(
        uint256 _keyId,
        uint256 _withdrawShares
    )
        external
        updatePools
        onlyKeyOwner(_keyId)
    {
        _manuallyWithdrawShares(
            farmingKeys[_keyId],
            _withdrawShares
        );
    }
    */
}
