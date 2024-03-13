// SPDX-License-Identifier: -- WISE --

pragma solidity =0.8.24;

import "@ironblocks/firewall-consumer/contracts/FirewallConsumer.sol";
import "../PowerFarms/PendlePowerFarmController/PendlePowerFarmController.sol";

contract Create2Deployer is FirewallConsumer {

    address public immutable VE_PENDLE_CONTRACT;
    address public immutable PENDLE_TOKEN;
    address public immutable VOTER_CONTRACT;
    address public immutable VOTER_REWARDS_CLAIMER_ADDRESS;
    address public immutable WISE_ORACLE_HUB;

    constructor(
        address _vePendleContract,
        address _pendleToken,
        address _voterContract,
        address _voterRewardsClaimerAddress,
        address _wiseOracleHub
    )
    {
        VE_PENDLE_CONTRACT = _vePendleContract;
        PENDLE_TOKEN = _pendleToken;
        VOTER_CONTRACT = _voterContract;
        VOTER_REWARDS_CLAIMER_ADDRESS = _voterRewardsClaimerAddress;
        WISE_ORACLE_HUB = _wiseOracleHub;
    }

    function deploy(
        uint256 _salt
    )
        external firewallProtected
        returns (address)
    {
        return _actualDeploy(
            _salt
        );
    }

    function _actualDeploy(
        uint256 _salt
    )
        private
        returns (address)
    {
        PendlePowerFarmController controller = new PendlePowerFarmController{
            salt: bytes32(_salt)
        }(
            VE_PENDLE_CONTRACT,
            PENDLE_TOKEN,
            VOTER_CONTRACT,
            VOTER_REWARDS_CLAIMER_ADDRESS,
            WISE_ORACLE_HUB
        );

        return address(controller);
    }
}
