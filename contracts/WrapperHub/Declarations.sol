// SPDX-License-Identifier: -- WISE --

pragma solidity = 0.8.21;

import "./AaveEvents.sol";
import "./InterfacesWrapperHub.sol";

import "../InterfaceHub/IWETH.sol";
import "../InterfaceHub/IWiseLending.sol";
import "../InterfaceHub/IWiseSecurity.sol";
import "../InterfaceHub/IPositionNFTs.sol";

import "../OwnableMaster.sol";

error AlreadySet();

contract Declarations is OwnableMaster, AaveEvents {

    IAave immutable AAVE;
    IWETH immutable WETH;

    IWiseLending immutable public WISE_LENDING;
    IPositionNFTs immutable public POSITION_NFT;

    uint16 constant REF_CODE = 0;
    IWiseSecurity public WISE_SECURITY;

    address immutable public WETH_ADDRESS;
    address immutable public AAVE_ADDRESS;

    uint256 constant PRECISION_FACTOR_E9 = 1E9;
    uint256 constant PRECISION_FACTOR_E18 = 1E18;
    uint256 constant MAX_AMOUNT = type(uint256).max;

    mapping (address => address) public aaveTokenAddress;

    constructor(
        address _master,
        address _aaveAddress,
        address _lendingAddress
    )
        OwnableMaster(
            _master
        )
    {
        if (_aaveAddress == ZERO_ADDRESS) {
            revert NoValue();
        }

        if (_lendingAddress == ZERO_ADDRESS) {
            revert NoValue();
        }

        AAVE_ADDRESS = _aaveAddress;

        WISE_LENDING = IWiseLending(
            _lendingAddress
        );

        WETH_ADDRESS = WISE_LENDING.WETH_ADDRESS();

        AAVE = IAave(
            AAVE_ADDRESS
        );

        WETH = IWETH(
            WETH_ADDRESS
        );

        POSITION_NFT = IPositionNFTs(
            WISE_LENDING.POSITION_NFT()
        );
    }

    function _checkOwner(
        uint256 _nftId
    )
        internal
        view
    {
        WISE_SECURITY.checkOwnerPosition(
            _nftId,
            msg.sender
        );
    }

    function _checkPositionLocked(
        uint256 _nftId
    )
        internal
        view
    {
        WISE_LENDING.checkPositionLocked(
            _nftId,
            msg.sender
        );
    }

    function _checkDeposit(
        uint256 _nftId,
        address _underlyingToken,
        uint256 _depositAmount
    )
        internal
        view
    {
        WISE_LENDING.checkDeposit(
            _nftId,
            msg.sender,
            aaveTokenAddress[_underlyingToken],
            _depositAmount
        );
    }

    function _checksWithdraw(
        uint256 _nftId,
        address _underlyingToken,
        uint256 _withdrawAmount
    )
        internal
        view
    {
        WISE_SECURITY.checksWithdraw(
            _nftId,
            msg.sender,
            aaveTokenAddress[_underlyingToken],
            _withdrawAmount
        );
    }

    function _checksBorrow(
        uint256 _nftId,
        address _underlyingToken,
        uint256 _borrowAmount
    )
        internal
        view
    {
        WISE_SECURITY.checksBorrow(
            _nftId,
            msg.sender,
            aaveTokenAddress[_underlyingToken],
            _borrowAmount
        );
    }

    function _checksSolelyWithdraw(
        uint256 _nftId,
        address _underlyingToken,
        uint256 _withdrawAmount
    )
        internal
        view
    {
        WISE_SECURITY.checksSolelyWithdraw(
            _nftId,
            msg.sender,
            aaveTokenAddress[_underlyingToken],
            _withdrawAmount
        );
    }

    function _syncPool(
        address _underlyingToken
    )
        private
    {
        WISE_LENDING.preparePool(
            aaveTokenAddress[_underlyingToken]
        );
    }

    function setWiseSecurity(
        address _securityAddress
    )
        external
        onlyMaster
    {
        WISE_SECURITY = IWiseSecurity(
            _securityAddress
        );
    }
}
