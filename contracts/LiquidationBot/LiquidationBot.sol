// SPDX-License-Identifier: -- WISE --

pragma solidity =0.8.21;

import "./LiquidationResolver.sol";
import "../TransferHub/ApprovalHelper.sol";

contract LiquidationBot is LiquidationResolver, ApprovalHelper {

    receive()
        external
        payable
    {
        payable(master).transfer(
            msg.value
        );
    }

    constructor(
        address _automateAddress,
        address _wiseLendingAddress
    )
        DeclarationsLiquidationBot(
            _automateAddress,
            _wiseLendingAddress
        )
    {
    }

    function getFunds()
        external
        view
        returns (uint256)
    {
        return TASK_TREASURY.totalUserTokenBalance(
            address(this),
            ETH
        );
    }

    function loadFunds()
        external
        payable
    {
        TASK_TREASURY.depositFunds{value: msg.value}(
            address(this),
            ETH,
            msg.value
        );
    }

    function removeFunds(
        uint256 _amount
    )
        external
    {
        withdrawFunds(
            _amount,
            ETH
        );
    }

    function approveTokenLiquidation(
        address _tokenAddress
    )
        external
        onlyMaster
    {
        _safeApprove(
            _tokenAddress,
            address(WISE_LENDING),
            MAX_AMOUNT
        );
    }

    function loadLiquidationToken(
        address _tokenAddress,
        uint256 _amount
    )
        external
    {
        _safeTransferFrom(
            _tokenAddress,
            msg.sender,
            address(this),
            _amount
        );
    }

    function contractBalances(
        address _token
    )
        external
        view
        returns (uint256)
    {
        return IERC20(_token).balanceOf(
            address(this)
        );
    }

    function setLiquidationPercent(
        uint256 _newValue
    )
        external
        onlyMaster
    {
        liquidationPercent = _newValue;
    }

    function setIntervallUpdate(
        address _poolToken,
        uint256 _intervall
    )
        external
        onlyMaster
    {
        intervallUpdate[_poolToken] = _intervall;
    }

    function setThresholdPriceDeviation(
        address _poolToken,
        uint256 _deviation
    )
        external
        onlyMaster
    {
        thresholdPriceDeviation[_poolToken] = _deviation;
    }

    function createAllBots()
        external
        onlyMaster
    {
        for(uint8 i = 0; i < MAX_ANZ_RESOLVER; ++i) {
            createBotIntervall(i);
        }
    }

    function createUpdateTask()
        external
        onlyMaster
    {
        if (updateTask != EMPTY_BYTES32) {
            revert AlreadyInitalized();
        }

        ModuleData memory moduleData = ModuleData(
            {
                modules: new Module[](2),
                args: new bytes[](2)
            }
        );

        moduleData.modules[0] = Module.RESOLVER;
        moduleData.modules[1] = Module.PROXY;

        moduleData.args[0] = _resolverModuleArg(
            address(this),
            abi.encodeWithSignature(
                "resolverUpdate()"
            )
        );

        updateTask = _createTask(
            address(WISE_LENDING),
            abi.encodeWithSelector(
                WISE_LENDING.syncManually.selector
            ),
            moduleData,
            address(0)
        );
    }

    function createBotIntervall(
        uint8 _index
    )
        public
        onlyMaster
    {
        if (taskIds[_index] != EMPTY_BYTES32) {
            revert AlreadyInitalized();
        }

        ModuleData memory moduleData = ModuleData(
            {
                modules: new Module[](2),
                args: new bytes[](2)
            }
        );

        moduleData.modules[0] = Module.RESOLVER;
        moduleData.modules[1] = Module.PROXY;

        moduleData.args[0] = _resolverModuleArg(
            address(this),
            abi.encodeWithSignature(
                functionNamesResolver[_index]
            )
        );

        taskIds[_index] = _createTask(
            address(WISE_LIQUIDATION),
            abi.encodeWithSelector(
                WISE_LIQUIDATION.liquidatePartiallyFromTokens.selector
            ),
            moduleData,
            address(0)
        );

        taskCounter += 1;
    }

    function cancleAllTasks()
        external
        onlyMaster
    {
        for (uint8 i = 0; i <= taskCounter; ++i) {
            cancelTask(i);
        }
    }

    function cancelTask(
        uint8 _index
    )
        public
        onlyMaster
    {
        _cancelTask(
            taskIds[_index]
        );

        taskIds[_index] = EMPTY_BYTES32;

        taskCounter -= 1;
    }

    function cancelUpdate()
        external
        onlyMaster
    {
        _cancelTask(
            updateTask
        );

        updateTask = EMPTY_BYTES32;
    }
}
