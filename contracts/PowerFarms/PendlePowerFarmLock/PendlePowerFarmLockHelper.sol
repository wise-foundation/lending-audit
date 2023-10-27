// SPDX-License-Identifier: -- WISE --

pragma solidity =0.8.21;

import "./PendlePowerFarmLockBase.sol";

abstract contract PendlePowerFarmLockHelper is PendlePowerFarmLockBase {

    function _calcExpiry(
        uint128 _weeks
    )
        internal
        view
        returns (uint128)
    {
        uint128 startTime = uint128((block.timestamp / WEEK)
            * WEEK);

        return startTime + (_weeks * WEEK);
    }

    function _getExpiry()
        internal
        view
        returns (uint256)
    {
        return PENDLE_LOCK.positionData(
            address(this)
        ).expiry;
    }

    function _getLockAmount()
        internal
        view
        returns (uint256)
    {
        return PENDLE_LOCK.positionData(
            address(this)
        ).amount;
    }

    function _claimTokenRewards(
        address _powerFarm,
        bytes[] memory _data
    )
        internal
        returns (uint256)
    {
        (
            uint256 interestOut,

        ) = YT_FARM[_powerFarm].redeemDueInterestAndRewards(
            address(this),
            true,
            true
        );

        uint256 i;
        uint256 len = _data.length;
        address fromToken;
        uint256 swapAmount;

        for (i; i < len;) {

            fromToken = farmRewardTokensYt[_powerFarm][i];

            swapAmount += _performCustomSwap(
                _powerFarm,
                fromToken,
                _data[i]
            );

            unchecked {
                ++i;
            }
        }

        return interestOut + swapAmount;
    }

    function _claimPendleRewards(
        address _powerFarm,
        bytes[] memory _data
    )
        internal
        returns (uint256)
    {
        LP_FARM[_powerFarm].redeemRewards(
            address(this)
        );

        address fromToken;
        uint256 swapAmount;

        uint256 i;
        uint256 len = _data.length;

        for (i; i < len;) {

            fromToken = farmRewardTokensMarket[_powerFarm][i];

            swapAmount += _performCustomSwap(
                _powerFarm,
                fromToken,
                _data[i]
            );

            unchecked {
                ++i;
            }
        }

        return swapAmount;
    }

    function _sendRewardsFarm(
        address _powerFarm,
        uint256 _amount
    )
        internal
    {
        POWER_FARM[_powerFarm].addCompoundSyAmount(
            _amount
        );

        _safeTransfer(
            address(SY_FARM[_powerFarm]),
            _powerFarm,
            _amount
        );
    }

    function _performCustomSwap(
        address _powerFarm,
        address _fromToken,
        bytes memory _data
    )
        internal
        returns (uint256)
    {
        TokenInput memory tokenInputData = _securityChecks(
            _powerFarm,
            _fromToken,
            _data
        );

        _safeApproveReset(
            _fromToken,
            PENDLE_ROUTER_ADDRESS,
            tokenInputData.netTokenIn
        );

        (
            bool success,
            bytes memory callbackData
        ) = PENDLE_ROUTER_ADDRESS.call(
            _data
        );

        return _checkSwap(
            success,
            callbackData
        );
    }

    function _safeApproveReset(
        address _token,
        address _spender,
        uint256 _amount
    )
        internal
    {
        _safeApprove(
            _token,
            _spender,
            0
        );

        _safeApprove(
            _token,
            _spender,
            _amount
        );
    }

    function _securityChecks(
        address _farm,
        address _rewardToken,
        bytes memory _data
    )
        internal
        view
        returns (TokenInput memory)
    {
        bytes4 selector;
        address receiver;
        address syToken;
        address tokenIn;

        uint256 length = _data.length;

        TokenInput memory tokenInput;

        assembly {
            selector := mload(add(_data, 4))
            receiver := mload(add(_data, 24))
            syToken := mload(add(_data, 44))
            tokenInput := mload(add(_data, length))
        }

        tokenIn = tokenInput.tokenIn;

        if (receiver != address(this)) {
            revert SwapChecksFailed();
        }

        if (tokenIn != _rewardToken) {
            revert SwapChecksFailed();
        }

        if (syToken != address(SY_FARM[_farm])) {
            revert SwapChecksFailed();
        }

        if (selector != SELECTOR_MINT_SY_FROM_TOKEN) {
            revert SwapChecksFailed();
        }

        return tokenInput;
    }

    function _checkSwap(
        bool _success,
        bytes memory _callbackData
    )
        internal
        pure
        returns (uint256)
    {
        if (_success == false) {
            revert SwapFailed();
        }

        return abi.decode(
            _callbackData,
            (uint256)
        );
    }

    modifier onlyAllowedCaller()
    {
        if (allowedCaller[msg.sender] == false) {
            revert NotAllowed();
        }
        _;
    }
}
