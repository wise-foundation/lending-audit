// SPDX-License-Identifier: -- WISE --

pragma solidity =0.8.24;

import "forge-std/Test.sol";
import "./DeployLibrary.sol";
import "./Create2Deployer.sol";

contract Create2DeployerTest is Test {

    Create2Deployer public deployer;

    address public RANDOM_ADDRESS = address(100);
    uint64 nonce = 100;

    function setUp()
        public
    {}

    function testDeployCreate2()
        public
    {
        address lockerMainnet = _deployLockerOnEthMain();
        address lockerArbitrum = _deployLockerOnArbMain();

        console.log(
            "lockerMainnet:",
            lockerMainnet
        );

        console.log(
            "lockerArbitrum:",
            lockerArbitrum
        );

        assertEq(
            lockerMainnet,
            lockerArbitrum,
            "locker addresses should be the same"
        );
    }

    function _deployLockerOnArbMain()
        internal
        returns (address)
    {
        vm.createSelectFork(
            vm.rpcUrl("arbitrum")
        );

        deal(
            RANDOM_ADDRESS,
            1 ether
        );

        vm.startPrank(
            RANDOM_ADDRESS
        );

        vm.setNonce(
            RANDOM_ADDRESS,
            nonce
        );

        deployer = new Create2Deployer(
            DeployLibrary.VE_PENDLE_CONTRACT,
            DeployLibrary.PENDLE_TOKEN,
            DeployLibrary.VOTER_CONTRACT,
            DeployLibrary.VOTER_REWARDS_CLAIMER_ADDRESS,
            DeployLibrary.WISE_ORACLE_HUB
        );

        address locker2 = deployer.deploy(0);

        return locker2;
    }

    function _deployLockerOnEthMain()
        internal
        returns (address)
    {
        vm.createSelectFork(
            vm.rpcUrl("mainnet")
        );

        deal(
            RANDOM_ADDRESS,
            1 ether
        );

        vm.startPrank(
            RANDOM_ADDRESS
        );

        vm.setNonce(
            RANDOM_ADDRESS,
            nonce
        );

        deployer = new Create2Deployer(
            DeployLibrary.VE_PENDLE_CONTRACT,
            DeployLibrary.PENDLE_TOKEN,
            DeployLibrary.VOTER_CONTRACT,
            DeployLibrary.VOTER_REWARDS_CLAIMER_ADDRESS,
            DeployLibrary.WISE_ORACLE_HUB
        );

        address locker = deployer.deploy(0);

        vm.stopPrank();
        return locker;
    }
}
