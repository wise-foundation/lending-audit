// SPDX-License-Identifier: -- WISE --

pragma solidity =0.8.21;

import "./PendlePowerFarmLockHelper.sol";

contract PendlePowerFarmLock is PendlePowerFarmLockHelper {

    constructor() {}

    function addPendleFarm(
        address _powerFarm
    )
        external
        onlyMaster
    {
        if (registerdPendleFarm[_powerFarm] == true) {
            revert AlreadySet();
        }

        pendlePowerFarms.push(
            _powerFarm
        );

        registerdPendleFarm[_powerFarm] = true;

        IPendlePowerFarms FARM = IPendlePowerFarms(
            _powerFarm
        );

        address ytAddress = FARM.YT_PENDLE_ADDRESS();
        address marketAddress = FARM.PENDLE_MARKET_ADDRESS();

        YT_FARM[_powerFarm] = IPendleYt(
            ytAddress
        );

        LP_FARM[_powerFarm] = IPendleMarket(
            marketAddress
        );

        SY_FARM[_powerFarm] = IPendleSy(
            FARM.SY_PENDLE_ADDRESS()
        );

        POWER_FARM[_powerFarm] = FARM;

        farmRewardTokensMarket[_powerFarm] = IPendleMarket(
            marketAddress
        ).getRewardTokens();

        farmRewardTokensYt[_powerFarm] = IPendleYt(
            ytAddress
        ).getRewardTokens();
    }

    function getFarmRewardTokensMarketIndex(
        address _powerFarm,
        uint256 _index
    )
        external
        view
        returns (address)
    {
        return farmRewardTokensMarket[_powerFarm][_index];
    }

    function getFarmRewardTokensYt(
        address _powerFarm,
        uint256 _index
    )
        external
        view
        returns (address)
    {
        return farmRewardTokensYt[_powerFarm][_index];
    }

    function getFarmRewardTokensMarketLength(
        address _powerFarm
    )
        external
        view
        returns (uint256)
    {
        return farmRewardTokensMarket[_powerFarm].length;
    }

    function getFarmRewardTokensYtLength(
        address _powerFarm
    )
        external
        view
        returns (uint256)
    {
        return farmRewardTokensYt[_powerFarm].length;
    }

    /**
     * @dev Same ordering as {getRewardTokens}.
     */
    function getFarmRewardsYield(
        address _powerFarm
    )
        external
        view
        returns (uint256[] memory)
    {
        address[] memory rewardTokens = farmRewardTokensYt[
            _powerFarm
        ];

        uint256 len = rewardTokens.length;
        uint256[] memory amounts = new uint256[](len);

        uint256 i;

        for (i; i < len;) {

            address token = rewardTokens[i];

            amounts[i] = YT_FARM[_powerFarm].userReward(
                token,
                address(this)
            ).accrued;

            amounts[i] += IERC20(token).balanceOf(
                address(this)
            );

            unchecked {
                ++i;
            }
        }

        return amounts;
    }

    function getFarmInterest(
        address _powerFarm
    )
        external
        view
        returns (uint256 interest)
    {
        (
            ,
            interest
        ) = YT_FARM[_powerFarm].userInterest(
            address(this)
        );
    }

    /**
     * @dev Same ordering as {getRewardTokens}.
     */
    function getFarmRewardsMarket(
        address _powerFarm
    )
        external
        view
        returns (uint256[] memory)
    {
        address[] memory rewardTokens = farmRewardTokensMarket[
            _powerFarm
        ];

        uint256 i;
        uint256 len = rewardTokens.length;

        uint256[] memory amounts = new uint256[](len);

        for (i; i < len;) {

            address token = rewardTokens[i];

            amounts[i] = LP_FARM[_powerFarm].userReward(
                token,
                address(this)
            ).accrued;

            amounts[i] += IERC20(token).balanceOf(
                address(this)
            );

            unchecked {
                ++i;
            }
        }

        return amounts;
    }

    function addAllowedCaller(
        address _newCaller
    )
        external
        onlyMaster
    {
        allowedCaller[_newCaller] = true;
    }

    function removeAlowedCaller(
        address _newCaller
    )
        external
        onlyMaster
    {
        allowedCaller[_newCaller] = false;
    }

    function getBalanceLP(
        address _pendleFarm
    )
        external
        view
        returns (uint256)
    {
        return balanceLP[_pendleFarm];
    }

    function getExpiry()
        external
        view
        returns (uint256)
    {
        return _getExpiry();
    }

    function getLockAmount()
        external
        view
        returns (uint256)
    {
        return _getLockAmount();
    }

    function claimPendleRewards(
        address _powerFarm,
        bytes[] calldata _dataSwapTokenRewards,
        bytes[] calldata _dataSwapPendleRewards
    )
        external
        onlyAllowedCaller
    {
        uint256 syAmount = _claimTokenRewards(
            _powerFarm,
            _dataSwapTokenRewards
        );

        syAmount += _claimPendleRewards(
            _powerFarm,
            _dataSwapPendleRewards
        );

        _sendRewardsFarm(
            _powerFarm,
            syAmount
        );
    }

    function compoundPendleRewards(
        address _powerFarm,
        bytes calldata _data,
        uint256 _overhangQueried,
        bool _ptGreater,
        bool _swapAllSy
    )
        external
        onlyAllowedCaller
    {
        POWER_FARM[_powerFarm].compoundFarm(
            _data,
            _overhangQueried,
            _ptGreater,
            _swapAllSy
        );
    }

    /**
     * @dev Can also be used to extend existing lock.
     */
    function lockPendle(
        uint256 _amount,
        uint128 _weeks
    )
        external
        onlyMaster
        returns (uint256)
    {
        uint128 expiry = _calcExpiry(
            _weeks
        );

        if (uint256(expiry) < _getExpiry()) {
            revert LockTimeTooShort();
        }

        if (_amount > 0) {

            _safeTransferFrom(
                PENDLE_TOKEN,
                msg.sender,
                address(this),
                _amount
            );

            _safeApprove(
                PENDLE_TOKEN,
                VE_PENDLE_CONTRACT,
                _amount
            );
        }

        return PENDLE_LOCK.increaseLockPosition(
            uint128(_amount),
            expiry
        );
    }

    function withdrawLock()
        external
        onlyMaster
        returns (uint256)
    {
        if (_getExpiry() > block.timestamp) {
            revert NotExpired();
        }

        uint256 amount = PENDLE_LOCK.withdraw();

        _safeTransfer(
            PENDLE_TOKEN,
            master,
            amount
        );

        return amount;
    }

    function getBalanceYT(
        address _pendleFarm
    )
        external
        view
        returns (uint256)
    {
        return balanceYT[_pendleFarm];
    }

    function transferLP(
        uint256 _amount,
        address _pendleFarm
    )
        external
        onlyAllowedPF
    {
        _safeTransferFrom(
            address(LP_FARM[_pendleFarm]),
            _pendleFarm,
            address(this),
            _amount
        );

        balanceLP[_pendleFarm] += _amount;
    }

    function transferYT(
        uint256 _amount,
        address _pendleFarm
    )
        external
        onlyAllowedPF
    {
        _safeTransferFrom(
            address(YT_FARM[_pendleFarm]),
            _pendleFarm,
            address(this),
            _amount
        );

        balanceYT[_pendleFarm] += _amount;
    }

    function sendYT(
        uint256 _amount,
        address _pendleFarm
    )
        external
        onlyAllowedPF
    {
        _safeTransfer(
            address(YT_FARM[_pendleFarm]),
            _pendleFarm,
            _amount
        );

        balanceYT[_pendleFarm] -= _amount;
    }

    function burnLP(
        uint256 _amount,
        address _pendleFarm
    )
        external
        onlyAllowedPF
        returns (
            uint256,
            uint256
        )
    {
        balanceLP[_pendleFarm] -= _amount;

        // uint256 bal = IERC20(0xD0354D4e7bCf345fB117cabe41aCaDb724eccCa2).balanceOf(
            //address(this)
        // );

        // console.log("bal", bal);
        // console.log("_amount", _amount);

        _safeTransfer(
            address(LP_FARM[_pendleFarm]),
            address(LP_FARM[_pendleFarm]),
            _amount
        );

        return LP_FARM[_pendleFarm].burn(
            _pendleFarm,
            _pendleFarm,
            _amount
        );
    }
}
