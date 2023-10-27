// SPDX-License-Identifier: -- WISE --

pragma solidity =0.8.21;

import {
    UserReward,
    MarketState,
    LockedPosition
} from "../InterfaceHub/IPendle.sol";

interface IPendleSyTest {

    function deposit(
        address _receiver,
        address _tokenIn,
        uint256 _amountTokenToDeposit,
        uint256 _minSharesOut
    )
        external
        returns (uint256 sharesAmount);

    function exchangeRate()
        external
        view
        returns (uint256);
}

interface IPendleYtTest {

    function userInterest(
        address _user
    )
        external
        view
        returns (
            uint128 lastPYIndex,
            uint128 accruedInterest
        );

    function mintPY(
        address _receiverPT,
        address _receiverYT
    )
        external
        returns (uint256 pyAmount);

    function redeemPY(
        address _receiver
    )
        external
        returns (uint256);

    function redeemDueInterestAndRewards(
        address _user,
        bool _redeemInterest,
        bool _redeemRewards
    )
        external
        returns (
            uint256 interestOut,
            uint256[] memory rewardsOut
        );

    function pyIndexLastUpdatedBlock()
        external
        view
        returns (uint256);

    function pyIndexCurrent()
        external
        returns (uint256);
}

interface IPendleMarketTest {

    function readState(
        address _router
    )
        external
        view
        returns (MarketState memory marketState);

    function mint(
        address receiver,
        uint256 netSyDesired,
        uint256 netPtDesired
    )
        external
        returns (uint256[3] memory);

    function burn(
        address _receiverAddressSy,
        address _receiverAddressPt,
        uint256 _lpToBurn
    )
        external
        returns (
            uint256 syOut,
            uint256 ptOut
        );

    function redeemRewards(
        address _user
    )
        external
        returns (uint256[] memory);

    function userReward(
        address _token,
        address _user
    )
        external
        view
        returns (UserReward memory);
}

interface IPendleLockTest {

    function increaseLockPosition(
        uint128 _additionalAmountToLock,
        uint128 _newExpiry
    )
        external
        returns (uint128 newVeBalance);

    function withdraw()
        external
        returns (uint128);

    function positionData(
        address _user
    )
        external
        view
        returns (LockedPosition memory);
}
