// SPDX-License-Identifier: -- WISE --

pragma solidity =0.8.21;

import "./PendleWstETHFarmBase.t.sol";
import "../PowerFarmNFTs/PowerFarmNFTs.sol";

contract PendleFarmBasicsTest is PendleWstETHBaseTest {

    uint256 constant USED_BLOCK = 18161617;

    HybridToken public farmToken;
    PowerFarmNFTs public powerFarmNFTs;
    HybdridTokenOracle public hybridOracle;
    PendleLockerTester public locker;
    PendleWstETHFarmTester public pendleFarm;


    uint256 public globalRewards;

    function getWeekStartTimestamp(
        uint128 _timestamp
    )
        public
        pure
        returns (uint128)
    {
        return (_timestamp / WEEK) * WEEK;
    }

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

        vm.startPrank(WISE_DEPLOYER);

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

    function testLockerSetup()
        public
    {
        assertEq(
            address(locker.SY_FARM(address(pendleFarm))),
            SY_PENDLE_ADDRESS
        );

        assertEq(
            address(locker.YT_FARM(address(pendleFarm))),
            YT_PENDLE_ADDRESS
        );

        assertEq(
            address(locker.LP_FARM(address(pendleFarm))),
            PENDLE_MARKET_ADDRESS
        );

        assertEq(
            locker.getBalanceLP(address(pendleFarm)),
            0
        );

        assertEq(
            locker.getBalanceYT(address(pendleFarm)),
            0
        );

        uint256 lenMarketRewards = locker.getFarmRewardTokensMarketLength(
            address(pendleFarm)
        );

        assertEq(
            lenMarketRewards,
            1
        );

        uint256 lenYtRewards = locker.getFarmRewardTokensYtLength(
            address(pendleFarm)
        );

        assertEq(
            lenYtRewards,
            0
        );

        address tokenMarket = locker.farmRewardTokensMarket(
            address(pendleFarm),
            0
        );

        assertEq(
            tokenMarket,
            PENDLE_TOKEN_ADDRESS
        );
    }

    function testLockerDedicatedMsg()
        public
    {
        assertEq(
            locker.allowedCaller(address(this)),
            false
        );

        locker.addAllowedCaller(
            address(this)
        );

        assertEq(
            locker.allowedCaller(address(this)),
            true
        );

        locker.removeAlowedCaller(
            address(this)
        );

        assertEq(
            locker.allowedCaller(address(this)),
            false
        );
    }

    function testLockerBalanceUpdate()
        public
    {
        uint256 depositAmount = PRECISION_FACTOR_E18;

        pendleFarm.depositPendleTest{value: depositAmount}(
            address(this)
        );

        uint256 balYt = IERC20(YT_PENDLE_ADDRESS).balanceOf(
            address(pendleFarm)
        );

        uint256 balPt = IERC20(PT_PENDLE_ADDRESS).balanceOf(
            address(pendleFarm)
        );

        assertEq(
            balYt,
            0,
            "There should be no yt left in farm"
        );

        assertEq(
            balPt,
            0,
            "There should be no pt left in farm"
        );


        uint256 lockerYt =  locker.getBalanceYT(
            address(pendleFarm)
        );

        uint256 lockerLp = locker.getBalanceLP(
            address(pendleFarm)
        );

        assertGt(
            lockerYt,
            0,
            "Locker should have yt token"
        );

        assertGt(
            lockerLp,
            0,
            "Locker should have lp token"
        );
    }

    function testUpdateFarmState()
        public
    {
        uint256 depositAmount = PRECISION_FACTOR_E18;

        (
            uint256 hybridTokens,
            uint256 wstETHAmount

        ) = pendleFarm.depositPendleTest{value: depositAmount}(
            address(this)
        );

        uint256 hybridUSDEquiv = ORACLE.getTokensInUSD(
            address(farmToken),
            hybridTokens
        );

        uint256 depositAmountUsdEquiv = ORACLE.getTokensInUSD(
            address(WETH_ADDRESS),
            depositAmount
        );

        console.log("depositAmountUsdEquiv", depositAmountUsdEquiv);
        console.log("hybridUSDEquiv", hybridUSDEquiv);

        assertApproxEqRel(
            depositAmountUsdEquiv,
            hybridUSDEquiv,
            POINT_FIVE,
            "USD equiv hybrid token and deposit amount should be nearly equal."
        );

        (
            bool ptGreater,
            uint256 totalYtAmount,
            uint256 totalSyAmount,
            uint256 totalPtAmount,
            uint256 totalLpAmount,
            uint256 contractPtAmount
        ) = pendleFarm.farmState();

        uint256 lockerYt =  locker.getBalanceYT(
            address(pendleFarm)
        );

        uint256 lockerLp = locker.getBalanceLP(
            address(pendleFarm)
        );

        assertEq(
            totalYtAmount,
            lockerYt,
            "Locker and farm should have same yt amount"
        );

        assertEq(
            lockerLp,
            totalLpAmount,
            "Locker and farm should have same lp amount"
        );

        assertEq(
            ptGreater,
            false,
            "pt and yt should be equal"
        );

        assertEq(
            contractPtAmount,
            0,
            "There should be no pt inside the farm"
        );

        assertApproxEqRel(
            totalSyAmount,
            wstETHAmount,
            POINT_ZERO_ZERO_ONE,
            "Sy and wstETH amount should be close to identical (view wei diff okay)."
        );

        assertApproxEqRel(
            totalYtAmount,
            totalPtAmount,
            POINT_ZERO_ZERO_ONE,
            "Yt and Pt should be close to identical (view wei diff okay)."
        );
    }

    function testLockPendle()
        public
    {
        uint256 depositAmount = 5 * PRECISION_FACTOR_E18;
        uint256 lockAmount = 100 * PRECISION_FACTOR_E18;

        uint128 WEEKS_30 = 30;

        pendleFarm.depositPendleTest{value: depositAmount}(
            address(this)
        );

        uint256 balPendle = IERC20Test(PENDLE_TOKEN_ADDRESS).balanceOf(
            PENDLE_WHALE
        );

        vm.prank(
            PENDLE_WHALE
        );

        _safeTransfer(
            PENDLE_TOKEN_ADDRESS,
            address(this),
            balPendle / 100
        );

        _safeApprove(
            PENDLE_TOKEN_ADDRESS,
            address(locker),
            HUGE_AMOUNT
        );

        uint256 lockedAmount = locker.getLockAmount();

        assertEq(
            lockedAmount,
            0,
            "Should not have locked pendle at the beginning."
        );

        locker.lockPendle(
            lockAmount,
            WEEKS_30
        );

        uint256 lockedAmountAfter = locker.getLockAmount();

        uint256 expiry = locker.getExpiry();

        uint256 startSeconds = getWeekStartTimestamp(
            uint128(block.timestamp)
        );

        assertEq(
            startSeconds + WEEKS_30 * WEEK,
            expiry,
            "Duration for lock is set correctly."
        );

        assertEq(
            lockedAmountAfter,
            lockAmount,
            "Lock amount should equals locked amount."
        );
    }

    function testLockerRewards()
        public
    {
        uint256[] memory rewardsMarket;
        uint256[] memory rewardsYt;

        uint256 depositAmount = 100 * PRECISION_FACTOR_E18;

        pendleFarm.depositPendleTest{value: depositAmount}(
            address(this)
        );

        rewardsMarket = locker.getFarmRewardsMarket(
            address(pendleFarm)
        );

        rewardsYt = locker.getFarmRewardsYield(
            address(pendleFarm)
        );

        uint256 interest = locker.getFarmInterest(
            address(pendleFarm)
        );

        assertEq(
            interest,
            0,
            "Should be no yt interest at the beginning."
        );

        uint256 lastPYIndex;

        (
            lastPYIndex,

        ) = YT_PENDLE.userInterest(
            address(pendleFarm)
        );

        console.log("lastPYIndex",lastPYIndex );
        console.log("other index", YT_PENDLE.pyIndexLastUpdatedBlock());

        assertEq(
            rewardsYt.length,
            0,
            "Pendle wstETH farm should not have yt rewards."
        );

        assertEq(
            rewardsMarket[0],
            0,
            "Should be no market rewards at the beginning."
        );

        skip(
            WEEK
        );

        vm.roll(
            block.number + 46500
        );

        YT_PENDLE.pyIndexCurrent();

        rewardsMarket = locker.getFarmRewardsMarket(
            address(pendleFarm)
        );

        UserReward memory userReward;

        userReward = LP_PENDLE.userReward(
            PENDLE_TOKEN_ADDRESS,
            address(locker)
        );

        console.log(
            "rewards",
            userReward.index
        );

        console.log(
            "rewardsMarket",
            rewardsMarket[0]
        );

        (
            lastPYIndex,

        ) = YT_PENDLE.userInterest(
            address(pendleFarm)
        );

        console.log("lastPYIndex",lastPYIndex );

        uint256[] memory rewards = locker.claimMarketRewards(
            address(pendleFarm)
        );

        console.log("rewards vom claimen", rewards[0]);

        userReward = LP_PENDLE.userReward(
            PENDLE_TOKEN_ADDRESS,
            address(locker)
        );

        console.log("rewards end", userReward.index);
    }

    function testLockNoBoost()
        public
    {
        uint256 depositAmount = 100 * PRECISION_FACTOR_E18;

        pendleFarm.depositPendleTest{
            value: depositAmount
        }(
            address(this)
        );

        skip(
           5 * WEEK
        );

        vm.roll(
           block.number + 5 * 46500
        );

        uint256[] memory rewards = locker.claimMarketRewards(
            address(pendleFarm)
        );

        console.log("rewards vom claimen",rewards[0]);
    }

    function testLockWithBoost()
        public
    {
        uint256 depositAmount = 100 * PRECISION_FACTOR_E18;
        uint256 lockAmount = 1000 * PRECISION_FACTOR_E18;

        uint128 WEEKS_30 = 30;

        uint256 balPendle = IERC20Test(PENDLE_TOKEN_ADDRESS).balanceOf(
            PENDLE_WHALE
        );

        vm.prank(PENDLE_WHALE);

        _safeTransfer(
            PENDLE_TOKEN_ADDRESS,
            address(this),
            balPendle / 100
        );

        _safeApprove(
            PENDLE_TOKEN_ADDRESS,
            address(locker),
            HUGE_AMOUNT
        );

        locker.lockPendle(
            lockAmount,
            WEEKS_30
        );

        pendleFarm.depositPendleTest{
            value: depositAmount
        }(
            address(this)
        );

        skip(
            5 * WEEK
        );

        vm.roll(
           block.number + 5 * 46500
        );

        uint256[] memory rewards = locker.claimMarketRewards(
            address(pendleFarm)
        );

        console.log("rewards vom claimen",rewards[0]);
    }

    function testCoreBurnFunction()
        public
    {
        uint256 depositAmount = 100 * PRECISION_FACTOR_E18;

        (
            uint256 hybridToken,

        ) = pendleFarm.depositPendleTest{
            value: depositAmount
        }(
            address(this)
        );

        (
            uint256 wsEthAmount,
            ,
            // uint256 pyAmount,
            // bool ptGreater

        ) = pendleFarm.burnHybridTokenUnderlying(
            hybridToken / 100
        );


        uint256 amount = WST_ETH.unwrap(
            wsEthAmount
        );

        assertGt(
            depositAmount / 100,
            amount,
            "User should not get more ETH back than deposited (portion)"
        );
    }
}
