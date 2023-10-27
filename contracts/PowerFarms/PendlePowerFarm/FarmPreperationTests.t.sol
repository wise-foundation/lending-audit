// SPDX-License-Identifier: -- WISE --

pragma solidity =0.8.21;

import "./HybridToken.sol";
import "./PendleWstETHFarmBase.t.sol";

import "../PowerFarmNFTs/PowerFarmNFTs.sol";

contract FarmPreperationTests is PendleWstETHBaseTest {

    uint256 constant USED_BLOCK = 18161617;

    uint256 public nftIDContract;
    HybdridTokenOracle public hybridOracle;
    PendleWstETHFarmTester public pendleFarm;

    PendleLockerTester public locker;
    HybridToken public farmToken;

    PowerFarmNFTs public powerFarmNFTs;

    function setUp()
        public
    {
        vm.rollFork(
            USED_BLOCK
        );

        locker = new PendleLockerTester();

        powerFarmNFTs = new PowerFarmNFTs(
            "PowerFarmNFTs",
            "PF-NFTs"
        );

        pendleFarm = new PendleWstETHFarmTester(
            WISE_LENDING_ADD,
            address(locker),
            95 * PRECISION_FACTOR_E16,
            address(powerFarmNFTs)
        );

        powerFarmNFTs.setFarmContract(
            address(pendleFarm)
        );

        farmToken = HybridToken(
            address(pendleFarm.HYBRID_TOKEN())
        );

        vm.startPrank(
            WISE_DEPLOYER
        );

        WISE_LENDING.setVeryfiedIsolationPool(
            address(pendleFarm),
            true
        );

        hybridOracle = new HybdridTokenOracle(
            IERC20(address(farmToken)),
            IPriceFeed(WST_ETH_FEED),
            "stETH PPF Oracle",
            IPendlePowerFarms(address(pendleFarm))
        );

        address[] memory underlyingFeeds = new address[](1);

        underlyingFeeds[0] = WST_ETH_ADDRESS;

        ORACLE.addOracle(
            address(farmToken),
            IPriceFeed(address(hybridOracle)),
            underlyingFeeds
        );

        CreatePool memory poolStruct = CreatePool(
            {
                allowBorrow: false,
                poolToken: address(farmToken),
                poolMulFactor: 0,
                poolCollFactor: 6 * PRECISION_FACTOR_E17,
                maxDepositAmount: 10000000 * PRECISION_FACTOR_E18
            }
        );

        WISE_LENDING.createPool(
            poolStruct
        );

        vm.stopPrank();

        locker.addPendleFarm(
            address(pendleFarm)
        );
    }

    function testSyMinting()
        public
    {
        uint256 depositAmount = 4 * PRECISION_FACTOR_E18;

        ST_ETH.submit{value: depositAmount}(
            WISE_DEPLOYER
        );

        _safeApprove(
            ST_ETH_ADDRESS,
            WST_ETH_ADDRESS,
            HUGE_AMOUNT
        );

        WST_ETH.wrap(
            2 * PRECISION_FACTOR_E18
        );

        _safeApprove(
            ST_ETH_ADDRESS,
            SY_PENDLE_ADDRESS,
            HUGE_AMOUNT
        );

        _safeApprove(
            WST_ETH_ADDRESS,
            SY_PENDLE_ADDRESS,
            HUGE_AMOUNT
        );

        SY_PENDLE.deposit(
            address(this),
            ST_ETH_ADDRESS,
            PRECISION_FACTOR_E18,
            0
        );

        uint256 balSyFromStETH = IERC20Test(SY_PENDLE_ADDRESS).balanceOf(
            address(this)
        );

        SY_PENDLE.deposit(
            address(this),
            WST_ETH_ADDRESS,
            PRECISION_FACTOR_E18,
            0
        );

        uint256 balEND = IERC20Test(SY_PENDLE_ADDRESS).balanceOf(
            address(this)
        );

        uint256 balSyFromWstETH = balEND - balSyFromStETH;

        assertGt(
            balSyFromWstETH,
            balSyFromStETH,
            "Should be minted more Sy from wstETH than stETH."
        );

        assertEq(
            balSyFromWstETH,
            PRECISION_FACTOR_E18,
            "Sy should be minted 1:1 with wstETH."
        );
    }

    /*

    function testRegister()
        public
    {
        uint256 dummyDeposit = PRECISION_FACTOR_E18;

        pendleFarm.registrationFarm(
            nftIDContract
        );

        vm.expectRevert();
        WISE_LENDING.depositExactAmountETH{value: dummyDeposit}(
            nftIDContract
        );

        assertEq(
            pendleFarm.registered(nftIDContract),
            true,
            "User should be registerd for pendle farm."
        );
    }

    function testHybridOracle()
        public
    {
        uint256 answer = hybridOracle.latestAnswer();

        assertEq(
            answer,
            0,
            "Answer should be zero"
        );

        string memory description = hybridOracle.description();

        assertEq(
            description,
            "stETH PPF Oracle",
            "Description should be equal stETH PPF Oracle."
        );

        uint256 oracleAnswer = ORACLE.latestResolver(
            address(pendleFarm)
        );

        bool chainlinkDead = ORACLE.chainLinkIsDead(
            address(pendleFarm)
        );

        assertEq(
            oracleAnswer,
            0,
            "Answer from oracle hub should also be zero"
        );

        assertEq(
            chainlinkDead,
            false,
            "Chainlink should be not dead."
        );
    }

    function testHybridPool()
        public
    {
        uint256 mintAmount = 10 * PRECISION_FACTOR_E18;

        pendleFarm.mintTestToken(
            mintAmount
        );

        _safeApprove(
            address(pendleFarm),
            WISE_LENDING_ADD,
            HUGE_AMOUNT
        );

        WISE_LENDING.depositExactAmount(
            nftIDContract,
            address(pendleFarm),
            mintAmount
        );

        uint256 sharePools = WISE_LENDING.getPositionLendingShares(
            nftIDContract,
            address(pendleFarm)
        );

        assertEq(
            sharePools,
            mintAmount,
            "Nft should own shares equal mint amount."
        );
    }

    function testOpenPositionETH()
        public
    {
        TestData memory data = TestData(
            {
                amountOpen: 10 * PRECISION_FACTOR_E18,
                leverage: 10 * PRECISION_FACTOR_E18
            }
        );

        vm.expectRevert(NotRegistered.selector);
        pendleFarm.openPositionETH{value: data.amountOpen}(
            nftIDContract,
            data.leverage
        );


        pendleFarm.registrationFarm(
            nftIDContract
        );

        WISE_LENDING.approve(
            address(pendleFarm),
            AAVE_WETH_ADDRESS,
            HUGE_AMOUNT
        );

        pendleFarm.openPositionETH{value: data.amountOpen}(
            nftIDContract,
            data.leverage
        );

        uint256 debtratio = pendleFarm.getLiveDebtratio(
            nftIDContract
        );

        assertGt(
            debtratio,
            0,
            "Debt ratio should be greater than zero."
        );

        uint256 collatToken = WISE_SECURITY.getPositionLendingAmount(
            nftIDContract,
            address(pendleFarm)
        );

        uint256 collatUSDEquiv = ORACLE.getTokensInUSD(
            address(pendleFarm),
            collatToken
        );

        uint256 farmAmount = data.amountOpen
            * data.leverage
            / PRECISION_FACTOR_E18;

        uint256 borrowFarmAmount = data.amountOpen
            * (data.leverage - PRECISION_FACTOR_E18)
            / PRECISION_FACTOR_E18;

        uint256 farmUSDEquiv = ORACLE.getTokensInUSD(
            WETH_ADDRESS,
            farmAmount
        );

        uint256 borrowFarmUSDEquiv = ORACLE.getTokensInUSD(
            AAVE_WETH_ADDRESS,
            borrowFarmAmount
        );

        uint256 borrowToken = WISE_SECURITY.getPositionBorrowAmount(
            nftIDContract,
            AAVE_WETH_ADDRESS
        );

        uint256 borrowUSDEquiv = ORACLE.getTokensInUSD(
            AAVE_WETH_ADDRESS,
            borrowToken
        );

        assertApproxEqRel(
            borrowUSDEquiv,
            borrowFarmUSDEquiv,
            POINT_ZERO_FIVE,
            "Borrow amount (usd) should be close to leverage amount (usd)."
        );

        assertApproxEqRel(
            farmUSDEquiv,
            collatUSDEquiv,
            POINT_FIVE,
            "Collateral amount (usd) should be close to leverage + initial amount (usd)."
        );

        uint256 pendleBal = IERC20Test(PENDLE_MARKET_ADDRESS).balanceOf(DUMMY_ADDRESS);

        MarketState memory marketState = IPendleMarket(PENDLE_MARKET_ADDRESS).readState(msg.sender);

        uint256 underlyingPTUser = pendleBal
            * PRECISION_FACTOR_E18
            / uint256(marketState.totalLp)
            * uint256(marketState.totalPt)
            / PRECISION_FACTOR_E18;

        uint256 underlyingSYUser = pendleBal
            * PRECISION_FACTOR_E18
            / uint256(marketState.totalLp)
            * uint256(marketState.totalSy)
            / PRECISION_FACTOR_E18;

        uint256 ytBal = IERC20Test(YT_PENDLE_ADDRESS).balanceOf(DUMMY_ADDRESS);

        console.log(pendleBal,"pendleBal");
        console.log(underlyingPTUser,"underlyingPTUser");
        console.log(underlyingSYUser,"underlyingSYUser");
        console.log(ytBal,"ytBal");

        uint256 syValue = pendleFarm.totalSyAmount();
        uint256 impliedSum = underlyingPTUser > ytBal
            ? (ytBal)+underlyingSYUser
            : (underlyingPTUser)+underlyingSYUser;

        console.log(syValue,"syValue");
        console.log(impliedSum,"impliedSum");

    }

    function testMintHybridTokenIrreducibleETH()
        public
    {
        uint256 mintAmount = PRECISION_FACTOR_E18;

        pendleFarm.mintHybridTokenIrreducibleETH{value: mintAmount}();

        uint256 balHybrid = pendleFarm.balanceOf(
            address(this)
        );

        uint256 answerETH = ORACLE.latestResolver(
            WETH_ADDRESS
        );

        uint256 answerHybrid = ORACLE.latestResolver(
            address(pendleFarm)
        );

        uint256 weightedAmount = balHybrid
            * answerHybrid
            / answerETH;

        assertApproxEqRel(
            weightedAmount,
            mintAmount,
            POINT_TWO,
            "Hybrid token amount should be close to mint amount (in USD units)."
        );
    }

    function testMintHybridTokenUnderlying()
        public
    {
        uint256 stakeAmount = 5 * PRECISION_FACTOR_E18;

        uint256 stETHShares = ST_ETH.submit{
            value: stakeAmount
        }(
            address(this)
        );

        uint256 stETHAmount = ST_ETH.getPooledEthByShares(
            stETHShares
        );

        _safeApprove(
            ST_ETH_ADDRESS,
            address(WST_ETH),
            HUGE_AMOUNT
        );

        uint256 wstETHAmount = WST_ETH.wrap(
            stETHAmount
        );

        _safeApprove(
            WST_ETH_ADDRESS,
            address(pendleFarm),
            HUGE_AMOUNT
        );

        pendleFarm.mintHybridTokenUnderlying(
            wstETHAmount
        );

        uint256 balHybrid = pendleFarm.balanceOf(
            address(this)
        );

        assertGt(
            balHybrid,
            0,
            "User should have hybrid token in wallet."
        );
    }
    */
}