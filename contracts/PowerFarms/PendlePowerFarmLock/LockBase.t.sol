// SPDX-License-Identifier: -- WISE --

pragma solidity =0.8.21;

import "forge-std/Test.sol";

import "../../TestInterfaces/IERC20Test.sol";
import "../../TestInterfaces/IPendleTest.sol";
import "../../TestInterfaces/IStETHTest.sol";

import "../../TransferHub/TransferHelper.sol";
import "../../TransferHub/ApprovalHelper.sol";

import "../PendlePowerFarm/PendleWstETHFarmTester.sol";

contract LockBaseTest is Test, ApprovalHelper, TransferHelper {

    address constant WISE_DEPLOYER = 0x641AD78BAca220C5BD28b51Ce8e0F495e85Fe689;
    address constant DUMMY_ADDRESS = 0xA7f676d112CA58a2e5045F22631A8388E9D7D8dE;
    address constant LIDO_COLLATOR = 0x388C818CA8B9251b393131C08a736A67ccB19297;

    address constant PENDLE_WHALE = 0x68fd0a0518b3120d844c5fB8a6f6dEFA4CaD42c5;

    address constant WISE_ORACLE_ADD = 0xD2cAa748B66768aC9c53A5443225Bdf1365dd4B6;
    address constant WISE_LENDING_ADD = 0x84524bAa1951247b3A2617A843e6eCe915Bb9674;

    address constant LOCK_CONTRACT = 0x4f30A9D41B80ecC5B94306AB4364951AE3170210;
    address constant PENDLE_LP = 0xD0354D4e7bCf345fB117cabe41aCaDb724eccCa2;
    address constant PENDLE_TOKEN = 0x808507121B80c02388fAd14726482e061B8da827;
    address constant YT_PENDLE_ST_ETH = 0xc3863CCcd012f8E45D72Ec87c5A9C4F77e1C7549;
    address constant SY_PENDLE_ST_ETH = 0xcbC72d92b2dc8187414F6734718563898740C0BC;

    address constant WETH_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant ST_ETH_ADDRESS = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
    address constant WST_ETH_ADDRESS = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;

    uint128 constant MIN_LOCK_TIME = 1 weeks;

    uint256 constant PRECISION_FACTOR_E16 = 1E16;
    uint256 constant PRECISION_FACTOR_E18 = 1E18;

    uint256 constant HUGE_AMOUNT = type(uint256).max;

    IPendleLockTest constant VE_PENDLE = IPendleLockTest(
        LOCK_CONTRACT
    );

    IPendleYtTest constant YT_PENDLE = IPendleYtTest(
        YT_PENDLE_ST_ETH
    );

    IPendleMarketTest constant LP_PENDLE = IPendleMarketTest(
        PENDLE_LP
    );
}