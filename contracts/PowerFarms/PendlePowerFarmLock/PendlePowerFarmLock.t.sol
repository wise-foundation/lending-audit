// SPDX-License-Identifier: -- WISE --

pragma solidity =0.8.21;

import "./PendlePowerFarmLock.sol";

contract PendleLockerTester is PendlePowerFarmLock {

    constructor()
        PendlePowerFarmLock()
    {
    }

    function claimMarketRewards(
        address _powerFarm
    )
        external
        returns (uint256[] memory)
    {
        return LP_FARM[_powerFarm].redeemRewards(
            address(this)
        );
    }
}