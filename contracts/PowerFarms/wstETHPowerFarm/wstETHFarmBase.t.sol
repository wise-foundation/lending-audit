// SPDX-License-Identifier: -- WISE --

pragma solidity =0.8.21;

import "forge-std/Test.sol";

import "../../TestInterfaces/IERC20Test.sol";
import "../../TestInterfaces/IAaveTest.sol";
import "../../TestInterfaces/IWiseLendingTest.sol";
import "../../TestInterfaces/IAaveHubTest.sol";
import "../../TestInterfaces/IOracleHubTest.sol";
import "../../TestInterfaces/INftTest.sol";
import "../../TestInterfaces/IWiseSecurityTest.sol";

import "../../TransferHub/TransferHelper.sol";
import "../../TransferHub/ApprovalHelper.sol";

import "./wstETHFarmTester.sol";

contract wstETHFarmBase is Test, TransferHelper, ApprovalHelper {

    address public WISE_DEPLOYER = 0x641AD78BAca220C5BD28b51Ce8e0F495e85Fe689;

    address internal constant AAVE_WETH_ADDRESS = 0x4d5F47FA6A74757f35C14fD3a6Ef8E3C9BC514E8;
    address internal constant WST_ETH_ADDRESS = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address internal constant WETH_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address internal constant ST_ETH_ADDRESS = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;

    address public constant WISE_ORACLE_ADD = 0xD2cAa748B66768aC9c53A5443225Bdf1365dd4B6;
    address public constant WISE_SECURITY_ADD = 0x5F8B6c17C3a6EF18B5711f9b562940990658400D;
    address public constant WISE_LENDING_ADD = 0x84524bAa1951247b3A2617A843e6eCe915Bb9674;
    address public constant AAVE_HUB_ADD = 0x4307d8207f2C429f0dCbd9051b5B1d638c3b7fbB;
    address public constant NFT_ADD = 0x9D6d4e2AfAB382ae9B52807a4B36A8d2Afc78b07;
    address public constant AAVE_ADD = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;

    uint256 public constant PRECISION_FACTOR_E6 = 1E6;
    uint256 public constant PRECISION_FACTOR_E8 = 1E8;
    uint256 public constant PRECISION_FACTOR_E13 = 1E13;
    uint256 public constant PRECISION_FACTOR_E14 = 1E14;
    uint256 public constant PRECISION_FACTOR_E15 = 1E15;
    uint256 public constant PRECISION_FACTOR_E16 = 1E16;
    uint256 public constant PRECISION_FACTOR_E17 = 1E17;
    uint256 public constant PRECISION_FACTOR_E18 = 1E18;

    uint256 public constant LTV = 95 * PRECISION_FACTOR_E16;
    uint256 public constant FOURTY_PERCENT = 4 * PRECISION_FACTOR_E17;
    uint256 public constant POINT_ZERO_FIVE = 5 * PRECISION_FACTOR_E14;
    uint256 public constant POINT_TWO = 2 * PRECISION_FACTOR_E15;

    uint256 public constant HUGE_AMOUNT = type(uint256).max;

    struct TestData {
        uint256 amount;
        uint256 amountOpen;
        uint256 leverage;
    }

    IWiseSecurityTest public constant WISE_SECURITY = IWiseSecurityTest(
        WISE_SECURITY_ADD
    );

    IWiseLendingTest public constant WISE_LENDING = IWiseLendingTest(
        WISE_LENDING_ADD
    );

    IAaveHubTest public constant AAVE_HUB = IAaveHubTest(
        AAVE_HUB_ADD
    );

    IAaveTest public constant AAVE = IAaveTest(
        AAVE_ADD
    );

    INftTest public constant NFT = INftTest(
        NFT_ADD
    );

    IOracleHubTest public constant ORACLE_HUB = IOracleHubTest(
        WISE_ORACLE_ADD
    );

    IERC20Test public constant WETH = IERC20Test(
        WETH_ADDRESS
    );

    IERC20Test public constant WST_ETH = IERC20Test(
        WST_ETH_ADDRESS
    );

    IERC20Test public constant ST_ETH = IERC20Test(
        ST_ETH_ADDRESS
    );

    receive()
        external
        payable
    {}
}