// SPDX-License-Identifier: -- WISE --

pragma solidity =0.8.21;

import "./LockBase.t.sol";
import "../PowerFarmNFTs/PowerFarmNFTs.sol";

contract LockTest is LockBaseTest {

    PowerFarmNFTs public powerFarmNFTs;

    uint256 constant USED_BLOCK = 18161617;
    uint128 constant WEEK = 7 days;

    PendleWstETHFarmTester public pendleFarm;

    function isValidWTime(
        uint256 _time
    )
        internal
        pure
        returns (bool)
    {
        return _time % WEEK == 0;
    }

    function getWeekStartTimestamp(
        uint128 _timestamp
    )
        internal
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

        powerFarmNFTs = new PowerFarmNFTs(
            "PowerFarmNFTs",
            "PF-NFTs"
        );

        pendleFarm = new PendleWstETHFarmTester(
            WISE_LENDING_ADD,
            DUMMY_ADDRESS,
            95 * PRECISION_FACTOR_E16,
            address(powerFarmNFTs)
        );

        // pendleFarm.approveHybridToken();
    }

    function testLockPendle()
        public
    {
        uint256 balPendle = IERC20Test(PENDLE_TOKEN).balanceOf(
            PENDLE_WHALE
        );

        vm.prank(PENDLE_WHALE);
        _safeTransfer(
            PENDLE_TOKEN,
            address(this),
            balPendle / 100
        );

        _safeApprove(
            PENDLE_TOKEN,
            LOCK_CONTRACT,
            HUGE_AMOUNT
        );

        uint256 expiryTime = block.timestamp
            + 2 * MIN_LOCK_TIME;

        bool correct = isValidWTime(
            expiryTime
        );

        assertEq(
            correct,
            false,
            "Normal blocktime not a multiple of weeks in general."
        );

        expiryTime = getWeekStartTimestamp(uint128(block.timestamp))
            + 2 * MIN_LOCK_TIME;

        correct = isValidWTime(
            expiryTime
        );

        assertEq(
            correct,
            true,
            "After normalizing to week start should be correct."
        );

        uint256 balVe = VE_PENDLE.increaseLockPosition(
            uint128(balPendle / 100),
            uint128(expiryTime)
        );

        assertGt(
            balVe,
            0,
            "User should have vePendle after locking."
        );
    }

    function testClaimRewards()
        public
    {
        /*
        uint256 depositAmount = 100
            * PRECISION_FACTOR_E18;
        */

        /*
        uint256 lpAmount = pendleFarm.getLPZeroPriceImpactETH{
            value: depositAmount
        }();

        uint256 ytToken = IERC20Test(YT_PENDLE_ST_ETH).balanceOf(
            address(this)
        );
        */

        // console.log("lpAmount",lpAmount);
        // console.log("ytToken",ytToken);

        uint256 latestIndex = YT_PENDLE.pyIndexLastUpdatedBlock();

        skip(
            WEEK
        );

        vm.roll(
            block.number + 46500
        );

        YT_PENDLE.pyIndexCurrent();

        uint256 latestIndexAfter = YT_PENDLE.pyIndexLastUpdatedBlock();

        console.log("latestIndex",latestIndex);
        console.log("latestIndexAfter",latestIndexAfter);

        /*
        uint256[] memory pendle = LP_PENDLE.redeemRewards(
            address(this)
        );
        */

        (
            uint256 interestOut
            ,
            // uint256[] memory rewardOut

        ) = YT_PENDLE.redeemDueInterestAndRewards(
            address(this),
            true,
            true
        );

        uint256 balPendle = IERC20Test(PENDLE_TOKEN).balanceOf(
            address(this)
        );

        uint256 syBal = IERC20Test(SY_PENDLE_ST_ETH).balanceOf(
            address(this)
        );

        console.log("syBal",syBal);
        console.log("balPendle",balPendle);
        console.log("interestOut",interestOut);
    }
}
