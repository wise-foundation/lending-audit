pragma solidity =0.8.21;

// SPDX-License-Identifier: MIT

import "../InterfaceHub/IFlash.sol";
import "../InterfaceHub/IERC20.sol";

import "../TransferHub/ApprovalHelper.sol";

// This is an example of an Implementation for outside developers!!!

contract FlashBorrower is IFlashBorrower, ApprovalHelper {

    bytes32 constant CALLBACK_VALUE = keccak256(
        "IFlashBorrower.onFlashLoan"
    );

    IFlashLender public lender;

    constructor(IFlashLender _lender) {
        lender = _lender;
    }

    event FlashLoan(
        address[] _token,
        uint256[] _amount,
        uint256[] _fee,
        bytes[] _data
    );

    function flashBorrowBulk(
        IERC20[] memory _flashMaker,
        address[] memory _tokenList,
        uint256[] memory _amountList,
        bytes[] calldata _bytesArray
    )
        external
    {
        uint256 lengthIndex = _flashMaker.length;

        require(
            _flashMaker.length == _amountList.length,
            "FlashBorrower: LENGTH_MISSMATCH"
        );

        require(
            _tokenList.length == _amountList.length,
            "FlashBorrower: LENGTH_MISSMATCH"
        );

        uint256[] memory feeList = new uint256[] (lengthIndex);

        for (uint256 i = 0; i < lengthIndex; ++i) {
            uint256 allowance = _flashMaker[i].allowance(
                address(this),
                address(lender)
            );

            feeList[i] = lender.flashFee(
                _tokenList[i],
                _amountList[i]
            );

            uint256 repayment = _amountList[i] + feeList[i];

            _safeApprove(
                address(_flashMaker[i]),
                address(lender),
                allowance + repayment
            );
        }

        lender.flashLoan(
            this,
            _tokenList,
            _amountList,
            _bytesArray
        );
    }

    function onFlashLoan(
        address _initiator,
        address[] memory _tokenList,
        uint256[] memory _amountList,
        uint256[] memory _feeList,
        bytes[] calldata _data
    )
        external
        returns (bytes32)
    {
        require(
            msg.sender == address(lender),
            "FlashBorrower: Untrusted lender"
        );

        require(
            _initiator == address(this),
            "FlashBorrower: Untrusted loan initiator"
        );

        // lender.flashFee for getting fees and decode data if u wanna know how much tokens u need in the contract left at the end...

        // Arbitrairy LOGIC goes in here!
        //
        //
        //
        //
        //

        emit FlashLoan(
            _tokenList,
            _amountList,
            _feeList,
            _data
        );

        return CALLBACK_VALUE;
    }
}
