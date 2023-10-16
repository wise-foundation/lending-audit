pragma solidity =0.8.21;

// SPDX-License-Identifier: -- WISE --

import "../InterfaceHub/IFlash.sol";
import "../InterfaceHub/IERC20.sol";

error LengthMissmatch();
error CallbackFailed();
error NotAuthorized();

contract FlashMaker {

    bytes32 public constant CALLBACK_SUCCESS = 0xf51a74cb268a8f727edf953ddacc8f280294844b89df00cd2e0ae537e4b981d3;

    address public masterAddress;
    mapping(address => uint256) public tokenFees;

    constructor() {
        masterAddress = msg.sender;
    }

    function adjustFees(
        address _tokenAddress,
        uint256 _feeValue
    )
        external
    {
        if (masterAddress != msg.sender) {
            revert NotAuthorized();
        }

        tokenFees[_tokenAddress] = _feeValue;
    }

    function maxFlashLoan(
        IERC20 _flashMaker
    )
        external
        view
        returns (uint256 result)
    {
        result = _flashMaker.balanceOf(
            address(this)
        );
    }

    function flashFee(
        address _token,
        uint256 _amount
    )
        public
        view
        returns (uint256 result)
    {
        result = _amount
            * tokenFees[_token]
            / 1000000;
    }

    function flashLoan(
        IFlashBorrower _receiver,
        IERC20[] calldata _flashMaker,
        address[] calldata _tokenList,
        uint256[] calldata _amountList,
        bytes[] calldata _data
    )
        external
        returns (bool)
    {
        if (_tokenList.length !=_amountList.length) {
            revert LengthMissmatch();
        }

        if (_tokenList.length != _flashMaker.length) {
            revert LengthMissmatch();
        }

        uint256 lengthIndex = _tokenList.length;

        uint256[] memory feeList = new uint256[](lengthIndex);

        for (uint256 i = 0; i < lengthIndex; ++i) {
            _flashMaker[i].transfer(
                address(_receiver),
                _amountList[i]
            );

            feeList[i] = flashFee(
                _tokenList[i],
                _amountList[i]
            );
        }

        if (_receiver.onFlashLoan(msg.sender, _tokenList, _amountList, feeList, _data) !=
            CALLBACK_SUCCESS) {
                revert CallbackFailed();
        }

        for (uint256 i = 0; i < lengthIndex; ++i) {
            _flashMaker[i].transferFrom(
                address(_receiver),
                address(this),
                _amountList[i] + feeList[i]
            );
        }

        return true;
    }
}
