// SPDX-License-Identifier: -- WISE --

pragma solidity =0.8.21;

import "forge-std/Test.sol";

import "../../TestInterfaces/IERC20Test.sol";
import "../../TestInterfaces/IStETHTest.sol";
import "../../TestInterfaces/IWstETHTest.sol";
import "../../TestInterfaces/IPendleTest.sol";
import "../../TestInterfaces/IAaveTest.sol";
import "../../TestInterfaces/IWiseLendingTest.sol";
import "../../TestInterfaces/IAaveHubTest.sol";
import "../../TestInterfaces/IOracleHubTest.sol";
import "../../TestInterfaces/INftTest.sol";
import "../../TestInterfaces/IWiseSecurityTest.sol";

import "../../TransferHub/TransferHelper.sol";
import "../../TransferHub/ApprovalHelper.sol";

import "./PendleWstETHFarmTester.sol";
import "../PendlePowerFarmLock/PendlePowerFarmLock.t.sol";
import "../../DerivativeOracles/HybridTokenOracle.sol";

contract PendleWstETHBaseTest is Test, TransferHelper, ApprovalHelper {

    address constant WISE_DEPLOYER = 0x641AD78BAca220C5BD28b51Ce8e0F495e85Fe689;
    address constant PENDLE_WHALE = 0x68fd0a0518b3120d844c5fB8a6f6dEFA4CaD42c5;

    address constant WST_ETH_FEED = 0xC42e9F1Aa22f78bC585e6911424c6B4936674e08;
    address constant ST_ETH_FEED = 0xCfE54B5cD566aB89272946F602D76Ea879CAb4a8;

    address constant AAVE_WETH_ADDRESS = 0x4d5F47FA6A74757f35C14fD3a6Ef8E3C9BC514E8;
    address constant WST_ETH_ADDRESS = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address constant WETH_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant ST_ETH_ADDRESS = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;

    address constant WISE_ORACLE_ADD = 0xD2cAa748B66768aC9c53A5443225Bdf1365dd4B6;
    address constant WISE_SECURITY_ADD = 0x5F8B6c17C3a6EF18B5711f9b562940990658400D;
    address constant WISE_LENDING_ADD = 0x84524bAa1951247b3A2617A843e6eCe915Bb9674;
    address constant AAVE_HUB_ADD = 0x4307d8207f2C429f0dCbd9051b5B1d638c3b7fbB;
    address constant NFT_ADD = 0x9D6d4e2AfAB382ae9B52807a4B36A8d2Afc78b07;
    address constant AAVE_ADD = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;

    address constant PT_PENDLE_ADDRESS = 0x7758896b6AC966BbABcf143eFA963030f17D3EdF;
    address constant SY_PENDLE_ADDRESS = 0xcbC72d92b2dc8187414F6734718563898740C0BC;
    address constant YT_PENDLE_ADDRESS = 0xc3863CCcd012f8E45D72Ec87c5A9C4F77e1C7549;
    address constant PENDLE_MARKET_ADDRESS = 0xD0354D4e7bCf345fB117cabe41aCaDb724eccCa2;
    address constant PENDLE_TOKEN_ADDRESS = 0x808507121B80c02388fAd14726482e061B8da827;

    address constant DUMMY_ADDRESS = 0xA7f676d112CA58a2e5045F22631A8388E9D7D8dE;

    uint256 constant PRECISION_FACTOR_E6 = 1E6;
    uint256 constant PRECISION_FACTOR_E8 = 1E8;
    uint256 constant PRECISION_FACTOR_E13 = 1E13;
    uint256 constant PRECISION_FACTOR_E14 = 1E14;
    uint256 constant PRECISION_FACTOR_E15 = 1E15;
    uint256 constant PRECISION_FACTOR_E16 = 1E16;
    uint256 constant PRECISION_FACTOR_E17 = 1E17;
    uint256 constant PRECISION_FACTOR_E18 = 1E18;

    uint256 constant LTV = 95 * PRECISION_FACTOR_E16;
    uint256 constant FOURTY_PERCENT = 4 * PRECISION_FACTOR_E17;
    uint256 constant POINT_ZERO_FIVE = 5 * PRECISION_FACTOR_E14;
    uint256 constant POINT_TWO = 2 * PRECISION_FACTOR_E15;
    uint256 constant POINT_FIVE = 5 * PRECISION_FACTOR_E15;
    uint256 constant POINT_ZERO_ZERO_ONE = PRECISION_FACTOR_E14;

    uint128 constant WEEK = 7 days;

    uint256 constant NINTY_EIGHT = 98 * PRECISION_FACTOR_E16;

    uint256 constant HUGE_AMOUNT = type(uint256).max;

    address constant ZERO_ADDRESS = address(0x0);

    struct TestData {
        uint256 amountOpen;
        uint256 leverage;
    }

    IWiseLendingTest constant WISE_LENDING = IWiseLendingTest(
        WISE_LENDING_ADD
    );

    IPendleMarketTest constant LP_PENDLE = IPendleMarketTest(
        PENDLE_MARKET_ADDRESS
    );

    IPendleSyTest constant SY_PENDLE = IPendleSyTest(
        SY_PENDLE_ADDRESS
    );

    IPendleYtTest constant YT_PENDLE = IPendleYtTest(
        YT_PENDLE_ADDRESS
    );

    INftTest constant NFT = INftTest(
        NFT_ADD
    );

    IStETHTest constant ST_ETH = IStETHTest(
        ST_ETH_ADDRESS
    );

    IWstETHTest constant WST_ETH = IWstETHTest(
        WST_ETH_ADDRESS
    );

    IOracleHubTest constant ORACLE = IOracleHubTest(
        WISE_ORACLE_ADD
    );

    IWiseSecurityTest constant WISE_SECURITY = IWiseSecurityTest(
        WISE_SECURITY_ADD
    );

    receive()
        external
        payable
    {}

    event ERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes _data
    );

    function onERC721Received(
        address _operator,
        address _from,
        uint256 _tokenId,
        bytes calldata _data
    )
        external
        returns (bytes4)
    {
        emit ERC721Received(
            _operator,
            _from,
            _tokenId,
            _data
        );

        return this.onERC721Received.selector;
    }
}
