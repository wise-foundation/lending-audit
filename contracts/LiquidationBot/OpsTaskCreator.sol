// SPDX-License-Identifier: -- WISE --

pragma solidity ^0.8.14;

import "./DeclarationsLiquidationBot.sol";

abstract contract OpsTaskCreator is DeclarationsLiquidationBot {

    function withdrawFunds(
        uint256 _amount,
        address _token
    )
        internal
        onlyMaster
    {
        TASK_TREASURY.withdrawFunds(
            payable(master),
            _token,
            _amount
        );
    }

    function _createTask(
        address _execAddress,
        bytes memory _execDataOrSelector,
        ModuleData memory _moduleData,
        address _feeToken
    )
        internal
        returns (bytes32)
    {
        return OPS.createTask(
            _execAddress,
            _execDataOrSelector,
            _moduleData,
            _feeToken
        );
    }

    function _cancelTask(
        bytes32 _taskId
    )
        internal
    {
        OPS.cancelTask(_taskId);
    }

    function _resolverModuleArg(
        address _resolverAddress,
        bytes memory _resolverData
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encode(
            _resolverAddress,
            _resolverData
        );
    }

    function _timeModuleArg(
        uint256 _startTime,
        uint256 _interval
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encode(
            uint128(_startTime),
            uint128(_interval)
        );
    }

    function _proxyModuleArg()
        internal
        pure
        returns (bytes memory)
    {
        return bytes("");
    }

    function _singleExecModuleArg()
        internal
        pure
        returns (bytes memory)
    {
        return bytes("");
    }
}
