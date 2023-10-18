// SPDX-License-Identifier: -- WISE --

pragma solidity =0.8.21;

import "./sDaiFarmBase.t.sol";

contract sDaiFarmTest is SDaiFarmTestBase {

    uint256 internal constant USED_BLOCK = 18061701;

    uint256 public nftIDContract;

    sDaiFarmTester public sDaiFarm;

    function setUp()
        public
    {
        vm.rollFork(
            USED_BLOCK
        );

        NFT.mintPosition();

        uint256[] memory positions = NFT.walletOfOwner(
            address(this)
        );

        nftIDContract = positions[0];

        sDaiFarm = new sDaiFarmTester(
            WISE_LENDING_ADD,
            95 * PRECISION_FACTOR_E16
        );

        vm.prank(WISE_DEPLOYER);

        WISE_LENDING.setVeryfiedIsolationPool(
            address(sDaiFarm),
            true
        );
    }

    function testSetUp()
        public
    {
        assertEq(
            sDaiFarm.collateralFactor(),
            95 * PRECISION_FACTOR_E16
        );

        assertEq(
            sDaiFarm.borrowTokenAddresses(0),
            DAI_ADDRESS
        );

        assertEq(
            sDaiFarm.borrowTokenAddresses(1),
            USDC_ADDRESS
        );

        assertEq(
            sDaiFarm.borrowTokenAddresses(2),
            USDT_ADDRESS
        );

        assertEq(
            sDaiFarm.aaveTokenAddresses(0),
            AAVE_DAI_ADDRESS
        );

        assertEq(
            sDaiFarm.aaveTokenAddresses(1),
            AAVE_USDC_ADDRESS
        );

        assertEq(
            sDaiFarm.aaveTokenAddresses(2),
            AAVE_USDT_ADDRESS
        );
    }

    function testRegisterFarm()
        public
    {
        vm.expectRevert(OutOfBound.selector);
        sDaiFarm.registrationFarm(
            nftIDContract,
            5
        );

        sDaiFarm.registrationFarm(
            nftIDContract,
            1
        );

        assertEq(
            sDaiFarm.nftToIndex(nftIDContract),
            1
        );

        vm.expectRevert(PositionLocked.selector);
        sDaiFarm.registrationFarm(
            nftIDContract,
            1
        );

        sDaiFarm.unregistrationFarm(
            nftIDContract
        );

        assertEq(
            sDaiFarm.nftToIndex(nftIDContract),
            0
        );

        sDaiFarm.unregistrationFarm(
            nftIDContract
        );

        WISE_LENDING.depositExactAmountETH
            {value: PRECISION_FACTOR_E18}
            (nftIDContract);

        vm.expectRevert(PositionNotEmpty.selector);
        sDaiFarm.registrationFarm(
            nftIDContract,
            2
        );
    }

    function testOpenPosition10xDAI()
        public
    {
        TestData memory data = TestData({
            amount: 100000 * PRECISION_FACTOR_E18,
            amountOpen: 2000 * PRECISION_FACTOR_E18,
            leverage: 10 * PRECISION_FACTOR_E18
        });

        vm.prank(DAI_WHALE);
        _safeTransfer(
            DAI_ADDRESS,
            WISE_DEPLOYER,
            data.amount
        );

        vm.prank(DAI_WHALE);
        _safeTransfer(
            DAI_ADDRESS,
            address(this),
            data.amountOpen
        );

        uint256[] memory ids = NFT.walletOfOwner(
            WISE_DEPLOYER
        );

        uint256 nftId = ids[0];

        vm.startPrank(
            WISE_DEPLOYER
        );

        _safeApprove(
            DAI_ADDRESS,
            AAVE_HUB_ADD,
            HUGE_AMOUNT
        );

        AAVE_HUB.depositExactAmount(
            nftId,
            DAI_ADDRESS,
            data.amount
        );

        vm.stopPrank();

        _safeApprove(
            DAI_ADDRESS,
            address(sDaiFarm),
            HUGE_AMOUNT
        );

        sDaiFarm.registrationFarm(
            nftIDContract,
            0
        );

        uint256 bal = DAI.balanceOf(
            address(this)
        );

        WISE_LENDING.approve(
            address(sDaiFarm),
            AAVE_DAI_ADDRESS,
            HUGE_AMOUNT
        );

        sDaiFarm.openPosition(
            nftIDContract,
            bal,
            data.leverage,
            0
        );

        uint256 debtratio = sDaiFarm.getLiveDebtRatio(
            nftIDContract
        );

        assertGt(
            debtratio,
            0,
            "Should be greater zero"
        );

        uint256 collatUSD = sDaiFarm.getTotalWeightedCollateralUSD(
            nftIDContract
        );

        uint256 borrowUSD = sDaiFarm.getPositionBorrowUSD(
            nftIDContract
        );

        uint256 collatBareUSD = collatUSD
            * PRECISION_FACTOR_E18
            / LTV;

        uint256 borrowToken = ORACLE_HUB.getTokensFromUSD(
            DAI_ADDRESS,
            borrowUSD
        );

        uint256 daiPrice = ORACLE_HUB.latestResolver(
            DAI_ADDRESS
        );

        assertApproxEqRel(
            borrowToken,
            data.amountOpen
                * (data.leverage - PRECISION_FACTOR_E18)
                / PRECISION_FACTOR_E18,
            POINT_ZERO_FIVE,
            "borrow amount should be nine times open amount"
        );

        assertApproxEqRel(
            collatBareUSD,
            data.amountOpen
                * data.leverage
                * daiPrice
                / PRECISION_FACTOR_E8
                / PRECISION_FACTOR_E18,
            POINT_ZERO_FIVE,
            "collateral amount should be very close to 10 times open amount"
        );

        vm.expectRevert(PositionNotEmpty.selector);
        sDaiFarm.unregistrationFarm(
            nftIDContract
        );

        uint256 daiBalContract = DAI.balanceOf(
            address(sDaiFarm)
        );

        assertEq(
            daiBalContract,
            0,
            "No DAI token should be left inside the contract"
        );
    }

    function testOpenPosition7xUSDC()
        public
    {
        TestData memory data = TestData({
            amount: 100000 * PRECISION_FACTOR_E6,
            amountOpen: 1000 * PRECISION_FACTOR_E18,
            leverage: 7 * PRECISION_FACTOR_E18
        });

        vm.prank(USDC_WHALE);
        _safeTransfer(
            USDC_ADDRESS,
            WISE_DEPLOYER,
            data.amount
        );

        vm.prank(DAI_WHALE);
        _safeTransfer(
            DAI_ADDRESS,
            address(this),
            data.amountOpen
        );

        uint256[] memory ids = NFT.walletOfOwner(
            WISE_DEPLOYER
        );

        uint256 nftId = ids[0];

        vm.startPrank(
            WISE_DEPLOYER
        );

        _safeApprove(
            USDC_ADDRESS,
            AAVE_HUB_ADD,
            HUGE_AMOUNT
        );

        AAVE_HUB.depositExactAmount(
            nftId,
            USDC_ADDRESS,
            data.amount
        );

        vm.stopPrank();

        _safeApprove(
            DAI_ADDRESS,
            address(sDaiFarm),
            HUGE_AMOUNT
        );

        sDaiFarm.registrationFarm(
            nftIDContract,
            1
        );

        uint256 bal = DAI.balanceOf(
            address(this)
        );

        WISE_LENDING.approve(
            address(sDaiFarm),
            AAVE_USDC_ADDRESS,
            HUGE_AMOUNT
        );

        sDaiFarm.openPosition(
            nftIDContract,
            bal,
            data.leverage,
            0
        );

        uint256 debtratio = sDaiFarm.getLiveDebtRatio(
            nftIDContract
        );

        console.log("debtratio", debtratio);

        assertGt(
            debtratio,
            0,
            "Should be greater zero"
        );

        uint256 collatUSD = sDaiFarm.getTotalWeightedCollateralUSD(
            nftIDContract
        );

        uint256 borrowUSD = sDaiFarm.getPositionBorrowUSD(
            nftIDContract
        );

        uint256 collatBareUSD = collatUSD
            * PRECISION_FACTOR_E18
            / LTV;

        uint256 daiPrice = ORACLE_HUB.latestResolver(
            DAI_ADDRESS
        );

        assertApproxEqRel(
            borrowUSD,
            data.amountOpen
                * (data.leverage - PRECISION_FACTOR_E18)
                * daiPrice
                / PRECISION_FACTOR_E8
                / PRECISION_FACTOR_E18,
            POINT_ZERO_FIVE,
            "borrow amount should be 6 times open amount"
        );

        assertApproxEqRel(
            collatBareUSD,
            data.amountOpen
                * data.leverage
                * daiPrice
                / PRECISION_FACTOR_E8
                / PRECISION_FACTOR_E18,
            POINT_ZERO_FIVE,
            "collateral amount should be very close to 7 times open amount"
        );

        vm.expectRevert(PositionNotEmpty.selector);
        sDaiFarm.unregistrationFarm(
            nftIDContract
        );

        uint256 daiBalContract = DAI.balanceOf(
            address(sDaiFarm)
        );

        uint256 usdcBalContract = USDC.balanceOf(
            address(sDaiFarm)
        );

        assertEq(
            daiBalContract,
            0,
            "No DAI token should be left inside the contract"
        );

        assertEq(
            usdcBalContract,
            0,
            "No USDC token should be left inside the contract"
        );
    }

    function testOpenPosition14xUSDT()
        public
    {
        TestData memory data = TestData({
            amount: 5000000 * PRECISION_FACTOR_E6,
            amountOpen: 50000 * PRECISION_FACTOR_E18,
            leverage: 14 * PRECISION_FACTOR_E18
        });

        vm.prank(USDT_WHALE);
        _safeTransfer(
            USDT_ADDRESS,
            WISE_DEPLOYER,
            data.amount
        );

        vm.prank(DAI_WHALE);
        _safeTransfer(
            DAI_ADDRESS,
            address(this),
            data.amountOpen
        );

        uint256[] memory ids = NFT.walletOfOwner(
            WISE_DEPLOYER
        );

        uint256 nftId = ids[0];

        vm.startPrank(
            WISE_DEPLOYER
        );

        _safeApprove(
            USDT_ADDRESS,
            AAVE_HUB_ADD,
            0
        );

        _safeApprove(
            USDT_ADDRESS,
            AAVE_HUB_ADD,
            HUGE_AMOUNT
        );

        AAVE_HUB.depositExactAmount(
            nftId,
            USDT_ADDRESS,
            data.amount
        );

        vm.stopPrank();

        _safeApprove(
            DAI_ADDRESS,
            address(sDaiFarm),
            HUGE_AMOUNT
        );

        sDaiFarm.registrationFarm(
            nftIDContract,
            2
        );

        uint256 bal = DAI.balanceOf(
            address(this)
        );

        WISE_LENDING.approve(
            address(sDaiFarm),
            AAVE_USDT_ADDRESS,
            HUGE_AMOUNT
        );

        sDaiFarm.openPosition(
            nftIDContract,
            bal,
            data.leverage,
            0
        );

        uint256 debtratio = sDaiFarm.getLiveDebtRatio(
            nftIDContract
        );

        console.log("debtratio", debtratio);

        assertGt(
            debtratio,
            0,
            "Should be greater zero"
        );

        uint256 collatUSD = sDaiFarm.getTotalWeightedCollateralUSD(
            nftIDContract
        );

        uint256 borrowUSD = sDaiFarm.getPositionBorrowUSD(
            nftIDContract
        );

        uint256 collatBareUSD = collatUSD
            * PRECISION_FACTOR_E18
            / LTV;

        uint256 daiPrice = ORACLE_HUB.latestResolver(
            DAI_ADDRESS
        );

        assertApproxEqRel(
            borrowUSD,
            data.amountOpen
                * (data.leverage - PRECISION_FACTOR_E18)
                * daiPrice
                / PRECISION_FACTOR_E8
                / PRECISION_FACTOR_E18,
            POINT_ZERO_FIVE,
            "borrow amount should be 13 times open amount"
        );

        assertApproxEqRel(
            collatBareUSD,
            data.amountOpen
                * data.leverage
                * daiPrice
                / PRECISION_FACTOR_E8
                / PRECISION_FACTOR_E18,
            POINT_TWO,
            "collateral amount should be very close to 14 times open amount"
        );

        vm.expectRevert(PositionNotEmpty.selector);
        sDaiFarm.unregistrationFarm(
            nftIDContract
        );

        uint256 daiBalContract = DAI.balanceOf(
            address(sDaiFarm)
        );

        uint256 usdcBalContract = USDC.balanceOf(
            address(sDaiFarm)
        );

        uint256 usdtBalContract = USDT.balanceOf(
            address(sDaiFarm)
        );

        assertEq(
            daiBalContract,
            0,
            "No DAI token should be left inside the contract"
        );

        assertEq(
            usdcBalContract,
            0,
            "No USDC token should be left inside the contract"
        );

        assertEq(
            usdtBalContract,
            0,
            "No USDT token should be left inside the contract"
        );
    }

    function testClosePositionDAI()
        public
    {
        TestData memory data = TestData({
            amount: 100000 * PRECISION_FACTOR_E18,
            amountOpen: 1250 * PRECISION_FACTOR_E18,
            leverage: 10 * PRECISION_FACTOR_E18
        });

        vm.prank(DAI_WHALE);
        _safeTransfer(
            DAI_ADDRESS,
            WISE_DEPLOYER,
            data.amount
        );

        vm.prank(DAI_WHALE);
        _safeTransfer(
            DAI_ADDRESS,
            address(this),
            data.amountOpen
        );

        uint256[] memory ids = NFT.walletOfOwner(
            WISE_DEPLOYER
        );

        uint256 nftId = ids[0];

        vm.startPrank(
            WISE_DEPLOYER
        );

        _safeApprove(
            DAI_ADDRESS,
            AAVE_HUB_ADD,
            HUGE_AMOUNT
        );

        AAVE_HUB.depositExactAmount(
            nftId,
            DAI_ADDRESS,
            data.amount
        );

        vm.stopPrank();

        _safeApprove(
            DAI_ADDRESS,
            address(sDaiFarm),
            HUGE_AMOUNT
        );

        sDaiFarm.registrationFarm(
            nftIDContract,
            0
        );

        uint256 bal = DAI.balanceOf(
            address(this)
        );

        WISE_LENDING.approve(
            address(sDaiFarm),
            AAVE_DAI_ADDRESS,
            HUGE_AMOUNT
        );

        WISE_LENDING.approve(
            address(sDaiFarm),
            SDAI_ADDRESS,
            HUGE_AMOUNT
        );

        sDaiFarm.openPosition(
            nftIDContract,
            bal,
            data.leverage,
            0
        );

        sDaiFarm.closingPosition(
            nftIDContract,
            0
        );

        uint256 collatUSD = sDaiFarm.getTotalWeightedCollateralUSD(
            nftIDContract
        );

        uint256 borrowUSD = sDaiFarm.getPositionBorrowUSD(
            nftIDContract
        );

        assertEq(
            collatUSD,
            0,
            "Collateral amount should be zero after closing"
        );

        assertEq(
            borrowUSD,
            0,
            "Borrow amount should be zero after closing"
        );

        sDaiFarm.unregistrationFarm(
            nftIDContract
        );

        uint256 daiBalContract = DAI.balanceOf(
            address(sDaiFarm)
        );

        assertEq(
            daiBalContract,
            0,
            "No DAI token should be left inside contract"
        );
    }

    function testClosePostionUSDC()
        public
    {
        TestData memory data = TestData({
            amount: 100000 * PRECISION_FACTOR_E6,
            amountOpen: 800 * PRECISION_FACTOR_E18,
            leverage: 7 * PRECISION_FACTOR_E18
        });

        vm.prank(USDC_WHALE);
        _safeTransfer(
            USDC_ADDRESS,
            WISE_DEPLOYER,
            data.amount
        );

        vm.prank(DAI_WHALE);
        _safeTransfer(
            DAI_ADDRESS,
            address(this),
            data.amountOpen
        );

        uint256[] memory ids = NFT.walletOfOwner(
            WISE_DEPLOYER
        );

        uint256 nftId = ids[0];

        vm.startPrank(
            WISE_DEPLOYER
        );

        _safeApprove(
            USDC_ADDRESS,
            AAVE_HUB_ADD,
            HUGE_AMOUNT
        );

        AAVE_HUB.depositExactAmount(
            nftId,
            USDC_ADDRESS,
            data.amount
        );

        vm.stopPrank();

        _safeApprove(
            DAI_ADDRESS,
            address(sDaiFarm),
            HUGE_AMOUNT
        );

        sDaiFarm.registrationFarm(
            nftIDContract,
            1
        );

        uint256 bal = DAI.balanceOf(
            address(this)
        );

        WISE_LENDING.approve(
            address(sDaiFarm),
            AAVE_USDC_ADDRESS,
            HUGE_AMOUNT
        );

        WISE_LENDING.approve(
            address(sDaiFarm),
            SDAI_ADDRESS,
            HUGE_AMOUNT
        );

        sDaiFarm.openPosition(
            nftIDContract,
            bal,
            data.leverage,
            0
        );

        sDaiFarm.closingPosition(
            nftIDContract,
            0
        );

        uint256 collatUSD = sDaiFarm.getTotalWeightedCollateralUSD(
            nftIDContract
        );

        uint256 borrowUSD = sDaiFarm.getPositionBorrowUSD(
            nftIDContract
        );

        assertEq(
            collatUSD,
            0,
            "Collateral amount should be zero after closing"
        );

        assertEq(
            borrowUSD,
            0,
            "Borrow amount should be zero after closing"
        );

        sDaiFarm.unregistrationFarm(
            nftIDContract
        );

        uint256 daiBalContract = DAI.balanceOf(
            address(sDaiFarm)
        );

        uint256 usdcBalContract = USDC.balanceOf(
            address(sDaiFarm)
        );

        assertEq(
            daiBalContract,
            0,
            "No DAI token should be left inside contract"
        );

        assertEq(
            usdcBalContract,
            0,
            "No USDC token should be left inside contract"
        );
    }

    function testClosePositionUSDT()
        public
    {
        TestData memory data = TestData({
            amount: 5000000 * PRECISION_FACTOR_E6,
            amountOpen: 1100 * PRECISION_FACTOR_E18,
            leverage: 5 * PRECISION_FACTOR_E18
        });

        vm.prank(USDT_WHALE);
        _safeTransfer(
            USDT_ADDRESS,
            WISE_DEPLOYER,
            data.amount
        );

        vm.prank(DAI_WHALE);
        _safeTransfer(
            DAI_ADDRESS,
            address(this),
            data.amountOpen
        );

        uint256[] memory ids = NFT.walletOfOwner(
            WISE_DEPLOYER
        );

        uint256 nftId = ids[0];

        vm.startPrank(
            WISE_DEPLOYER
        );

        _safeApprove(
            USDT_ADDRESS,
            AAVE_HUB_ADD,
            0
        );

        _safeApprove(
            USDT_ADDRESS,
            AAVE_HUB_ADD,
            HUGE_AMOUNT
        );

        AAVE_HUB.depositExactAmount(
            nftId,
            USDT_ADDRESS,
            data.amount
        );

        vm.stopPrank();

        _safeApprove(
            DAI_ADDRESS,
            address(sDaiFarm),
            HUGE_AMOUNT
        );

        sDaiFarm.registrationFarm(
            nftIDContract,
            2
        );

        uint256 bal = DAI.balanceOf(
            address(this)
        );

        WISE_LENDING.approve(
            address(sDaiFarm),
            AAVE_USDT_ADDRESS,
            HUGE_AMOUNT
        );

        WISE_LENDING.approve(
            address(sDaiFarm),
            SDAI_ADDRESS,
            HUGE_AMOUNT
        );

        sDaiFarm.openPosition(
            nftIDContract,
            bal,
            data.leverage,
            0
        );

        sDaiFarm.closingPosition(
            nftIDContract,
            HUGE_AMOUNT
        );

        uint256 collatUSD = sDaiFarm.getTotalWeightedCollateralUSD(
            nftIDContract
        );

        uint256 borrowUSD = sDaiFarm.getPositionBorrowUSD(
            nftIDContract
        );

        assertEq(
            collatUSD,
            0,
            "Collateral amount should be zero after closing"
        );

        assertEq(
            borrowUSD,
            0,
            "Borrow amount should be zero after closing"
        );

        sDaiFarm.unregistrationFarm(
            nftIDContract
        );

        uint256 daiBalContract = DAI.balanceOf(
            address(sDaiFarm)
        );

        uint256 usdcBalContract = USDC.balanceOf(
            address(sDaiFarm)
        );

        uint256 usdtBalContract = USDT.balanceOf(
            address(sDaiFarm)
        );

        assertEq(
            daiBalContract,
            0,
            "No DAI token should be left inside contract"
        );

        assertEq(
            usdcBalContract,
            0,
            "No USDC token should be left inside contract"
        );

        assertEq(
            usdtBalContract,
            0,
            "No USDT token should be left inside contract"
        );
    }

    function testLiquidation()
        public
    {
        TestData memory data = TestData({
            amount: 1000000 * PRECISION_FACTOR_E18,
            amountOpen: 2000 * PRECISION_FACTOR_E18,
            leverage: 14 * PRECISION_FACTOR_E18
        });

        uint256 liquidationAmount = 1000000 * PRECISION_FACTOR_E18;

        vm.prank(DAI_WHALE);
        _safeTransfer(
            DAI_ADDRESS,
            WISE_DEPLOYER,
            data.amount + liquidationAmount
        );

        vm.prank(DAI_WHALE);
        _safeTransfer(
            DAI_ADDRESS,
            address(this),
            data.amountOpen
        );

        uint256[] memory ids = NFT.walletOfOwner(
            WISE_DEPLOYER
        );

        uint256 nftId = ids[0];

        vm.startPrank(
            WISE_DEPLOYER
        );

        _safeApprove(
            DAI_ADDRESS,
            AAVE_HUB_ADD,
            HUGE_AMOUNT
        );

        AAVE_HUB.depositExactAmount(
            nftId,
            DAI_ADDRESS,
            data.amount
        );

        vm.stopPrank();

        _safeApprove(
            DAI_ADDRESS,
            address(sDaiFarm),
            HUGE_AMOUNT
        );

        sDaiFarm.registrationFarm(
            nftIDContract,
            0
        );

        uint256 bal = DAI.balanceOf(
            address(this)
        );

        WISE_LENDING.approve(
            address(sDaiFarm),
            AAVE_DAI_ADDRESS,
            HUGE_AMOUNT
        );

        sDaiFarm.openPosition(
            nftIDContract,
            bal,
            data.leverage,
            0
        );

        sDaiFarm.setCollfactor(
            92815 * PRECISION_FACTOR_E13
        );

        vm.startPrank(
            WISE_DEPLOYER
        );

        DAI.approve(
            AAVE_ADD,
            HUGE_AMOUNT
        );

        AAVE.deposit(
            DAI_ADDRESS,
            liquidationAmount,
            WISE_DEPLOYER,
            0
        );

        IERC20Test(AAVE_DAI_ADDRESS).approve(
            WISE_LENDING_ADD,
            HUGE_AMOUNT
        );

        uint256 borrowSharesUser = WISE_LENDING.getPositionBorrowShares(
            nftIDContract,
            AAVE_DAI_ADDRESS
        );

        uint256 portionShares = borrowSharesUser
            * FOURTY_PERCENT
            / PRECISION_FACTOR_E18;

        vm.expectRevert(PositionLocked.selector);
        WISE_LENDING.liquidatePartiallyFromTokens(
            nftIDContract,
            nftId,
            AAVE_DAI_ADDRESS,
            SDAI_ADDRESS,
            portionShares
        );

        IERC20Test(AAVE_DAI_ADDRESS).approve(
            address(sDaiFarm),
            HUGE_AMOUNT
        );

        uint256 debtratio = sDaiFarm.getLiveDebtRatio(
            nftIDContract
        );

        uint256 balsDAI = IERC20Test(SDAI_ADDRESS).balanceOf(
            WISE_DEPLOYER
        );

        sDaiFarm.liquidatePartiallyFromToken(
            nftIDContract,
            nftId,
            portionShares
        );

        vm.stopPrank();

        uint256 debtratioEnd = sDaiFarm.getLiveDebtRatio(
            nftIDContract
        );

        uint256 balsDAIEnd = IERC20Test(SDAI_ADDRESS).balanceOf(
            WISE_DEPLOYER
        );

        assertGt(
            balsDAIEnd - balsDAI,
            0,
            "Receiving token amount should be greater than zero."
        );

        assertGt(
            debtratio,
            debtratioEnd,
            "Debt ratio should be smaller after liquidation."
        );
    }

    function testUIFunctions()
        public
    {
        uint256 DUMMY_SDAI_APY = 5 * PRECISION_FACTOR_E16;

        TestData memory data = TestData({
            amount: 100000 * PRECISION_FACTOR_E6,
            amountOpen: 8000 * PRECISION_FACTOR_E18,
            leverage: 10 * PRECISION_FACTOR_E18
        });

        vm.prank(USDC_WHALE);
        _safeTransfer(
            USDC_ADDRESS,
            WISE_DEPLOYER,
            data.amount
        );

        vm.prank(DAI_WHALE);
        _safeTransfer(
            DAI_ADDRESS,
            address(this),
            data.amountOpen
        );

        uint256[] memory ids = NFT.walletOfOwner(
            WISE_DEPLOYER
        );

        uint256 nftId = ids[0];

        vm.startPrank(
            WISE_DEPLOYER
        );

        _safeApprove(
            USDC_ADDRESS,
            AAVE_HUB_ADD,
            HUGE_AMOUNT
        );

        AAVE_HUB.depositExactAmount(
            nftId,
            USDC_ADDRESS,
            data.amount
        );

        vm.stopPrank();

        _safeApprove(
            DAI_ADDRESS,
            address(sDaiFarm),
            HUGE_AMOUNT
        );

        sDaiFarm.registrationFarm(
            nftIDContract,
            1
        );

        uint256 bal = DAI.balanceOf(
            address(this)
        );

        WISE_LENDING.approve(
            address(sDaiFarm),
            AAVE_USDC_ADDRESS,
            HUGE_AMOUNT
        );

        WISE_LENDING.approve(
            address(sDaiFarm),
            SDAI_ADDRESS,
            HUGE_AMOUNT
        );

        uint256 borrowAmount = data.amountOpen
            * (data.leverage - PRECISION_FACTOR_E18)
            / PRECISION_FACTOR_E18;

        uint256 convertedToUSDC = ORACLE_HUB.getTokensFromUSD(
            USDC_ADDRESS,
            ORACLE_HUB.getTokensInUSD(
                DAI_ADDRESS,
                borrowAmount
            )
        );

        uint256 newRate = sDaiFarm.getNewBorrowRate(
            convertedToUSDC,
            AAVE_USDC_ADDRESS
        );

        assertGt(
            newRate,
            0,
            "New borrow rate should be greater than zero."
        );

        (
            uint256 approxNetAPY,
            bool isPositive

        ) = sDaiFarm.getApproxNetAPY(
            data.amountOpen,
            data.leverage,
            DUMMY_SDAI_APY,
            AAVE_USDC_ADDRESS
        );

        assertGt(
            approxNetAPY,
            20 * PRECISION_FACTOR_E16,
            "Approx net APY should be greater than 20 %"
        );

        assertEq(
            isPositive,
            true,
            "Net APY should be positiv."
        );

        sDaiFarm.openPosition(
            nftIDContract,
            bal,
            data.leverage,
            0
        );

        uint256 currentRate = WISE_SECURITY.getBorrowRate(
            AAVE_USDC_ADDRESS
        );

        assertEq(
            currentRate,
            newRate,
            "Contract rate and calculated should be equal."
        );
    }

    function testDeactivation()
        public
    {
        uint256 DUMMY_INITAL = 1000 * PRECISION_FACTOR_E6;

        uint256 DUMMY_LEVERAGE = 2 * PRECISION_FACTOR_E18;

        vm.prank(
            WISE_DEPLOYER
        );

        vm.expectRevert(NotMaster.selector);
        sDaiFarm.shutdownFarm(
            true
        );

        sDaiFarm.shutdownFarm(
            true
        );

        vm.expectRevert(Deactivated.selector);
        sDaiFarm.registrationFarm(
            nftIDContract,
            2
        );

        vm.expectRevert(Deactivated.selector);
        sDaiFarm.openPosition(
            nftIDContract,
            DUMMY_INITAL,
            DUMMY_LEVERAGE,
            0
        );

    }

    function testSecurityPayback()
        public
    {
        TestData memory data = TestData({
            amount: 100000 * PRECISION_FACTOR_E18,
            amountOpen: 5000 * PRECISION_FACTOR_E18,
            leverage: 7 * PRECISION_FACTOR_E18
        });

        vm.prank(DAI_WHALE);
        _safeTransfer(
            DAI_ADDRESS,
            WISE_DEPLOYER,
            2 * data.amount
        );

        vm.prank(DAI_WHALE);
        _safeTransfer(
            DAI_ADDRESS,
            address(this),
            data.amountOpen
        );

        uint256[] memory ids = NFT.walletOfOwner(
            WISE_DEPLOYER
        );

        uint256 nftId = ids[0];

        vm.startPrank(
            WISE_DEPLOYER
        );

        _safeApprove(
            DAI_ADDRESS,
            AAVE_HUB_ADD,
            HUGE_AMOUNT
        );

        _safeApprove(
            DAI_ADDRESS,
            AAVE_ADD,
            HUGE_AMOUNT
        );

        AAVE_HUB.depositExactAmount(
            nftId,
            DAI_ADDRESS,
            data.amount
        );

        vm.stopPrank();

        _safeApprove(
            DAI_ADDRESS,
            address(sDaiFarm),
            HUGE_AMOUNT
        );

        sDaiFarm.registrationFarm(
            nftIDContract,
            0
        );

        uint256 bal = DAI.balanceOf(
            address(this)
        );

        WISE_LENDING.approve(
            address(sDaiFarm),
            AAVE_DAI_ADDRESS,
            HUGE_AMOUNT
        );

        sDaiFarm.openPosition(
            nftIDContract,
            bal,
            data.leverage,
            0
        );

        uint256 borrowShares = WISE_LENDING.getPositionBorrowShares(
            nftIDContract,
            AAVE_DAI_ADDRESS
        );

        uint256 balDAI = DAI.balanceOf(
            WISE_DEPLOYER
        );

        vm.startPrank(
            WISE_DEPLOYER
        );

        AAVE.deposit(
            DAI_ADDRESS,
            balDAI,
            WISE_DEPLOYER,
            0
        );

        _safeApprove(
            AAVE_DAI_ADDRESS,
            address(sDaiFarm),
            HUGE_AMOUNT
        );

        sDaiFarm.manuallyPaybackShares(
            nftIDContract,
            borrowShares
        );

        vm.stopPrank();

        uint256 borrowUSDAfter = sDaiFarm.getPositionBorrowUSD(
            nftIDContract
        );

        uint256 debtratio = sDaiFarm.getLiveDebtRatio(
            nftIDContract
        );

        assertEq(
            borrowUSDAfter,
            0,
            "No borrow amount should be left."
        );

        assertEq(
            debtratio,
            0,
            "Debt ratio should be zero"
        );
    }

    function testSecurityWithdraw()
        public
    {
        TestData memory data = TestData({
            amount: 100000 * PRECISION_FACTOR_E18,
            amountOpen: 4000 * PRECISION_FACTOR_E18,
            leverage: 10 * PRECISION_FACTOR_E18
        });

        vm.prank(DAI_WHALE);
        _safeTransfer(
            DAI_ADDRESS,
            WISE_DEPLOYER,
            2 * data.amount
        );

        vm.prank(DAI_WHALE);
        _safeTransfer(
            DAI_ADDRESS,
            address(this),
            data.amountOpen
        );

        uint256[] memory ids = NFT.walletOfOwner(
            WISE_DEPLOYER
        );

        uint256 nftId = ids[0];

        vm.startPrank(
            WISE_DEPLOYER
        );

        _safeApprove(
            DAI_ADDRESS,
            AAVE_HUB_ADD,
            HUGE_AMOUNT
        );

        _safeApprove(
            DAI_ADDRESS,
            AAVE_ADD,
            HUGE_AMOUNT
        );

        AAVE_HUB.depositExactAmount(
            nftId,
            DAI_ADDRESS,
            data.amount
        );

        vm.stopPrank();

        _safeApprove(
            DAI_ADDRESS,
            address(sDaiFarm),
            HUGE_AMOUNT
        );

        sDaiFarm.registrationFarm(
            nftIDContract,
            0
        );

        uint256 bal = DAI.balanceOf(
            address(this)
        );

        WISE_LENDING.approve(
            address(sDaiFarm),
            AAVE_DAI_ADDRESS,
            HUGE_AMOUNT
        );

        sDaiFarm.openPosition(
            nftIDContract,
            bal,
            data.leverage,
            0
        );

        uint256 balDAI = DAI.balanceOf(
            WISE_DEPLOYER
        );

        vm.startPrank(
            WISE_DEPLOYER
        );

        AAVE.deposit(
            DAI_ADDRESS,
            balDAI,
            WISE_DEPLOYER,
            0
        );

        _safeApprove(
            AAVE_DAI_ADDRESS,
            address(sDaiFarm),
            HUGE_AMOUNT
        );

        uint256 borrowShares = WISE_LENDING.getPositionBorrowShares(
            nftIDContract,
            AAVE_DAI_ADDRESS
        );

        sDaiFarm.manuallyPaybackShares(
            nftIDContract,
            borrowShares / 2
        );

        vm.stopPrank();

        uint256 lendingShares = WISE_LENDING.getPositionLendingShares(
            nftIDContract,
            SDAI_ADDRESS
        );

        uint256 moreThanHalf = lendingShares
            * 55 * PRECISION_FACTOR_E16
            / PRECISION_FACTOR_E18;

        WISE_LENDING.approve(
            address(sDaiFarm),
            SDAI_ADDRESS,
            HUGE_AMOUNT
        );

        vm.expectRevert(ResultsInBadDebt.selector);
        sDaiFarm.manuallyWithdrawShares(
            nftIDContract,
            moreThanHalf
        );

        uint256 borrowSharesRest = WISE_LENDING.getPositionBorrowShares(
            nftIDContract,
            AAVE_DAI_ADDRESS
        );

        vm.prank(WISE_DEPLOYER);
        sDaiFarm.manuallyPaybackShares(
            nftIDContract,
            borrowSharesRest
        );

        uint256 balSDAI = IERC20Test(SDAI_ADDRESS).balanceOf(
            address(this)
        );

        sDaiFarm.manuallyWithdrawShares(
            nftIDContract,
            lendingShares
        );

        uint256 balSDAIEnd = IERC20Test(SDAI_ADDRESS).balanceOf(
            address(this)
        );

        uint256 diffInDai = ORACLE_HUB.getTokensFromUSD(
            DAI_ADDRESS,
            ORACLE_HUB.getTokensInUSD(
                SDAI_ADDRESS,
                balSDAIEnd - balSDAI
            )
        );

        assertApproxEqRel(
            diffInDai,
            data.amountOpen
                * data.leverage
                / PRECISION_FACTOR_E18,
            POINT_ZERO_FIVE,
            "Returning amount should be very close to 10 times open amount"
        );

        assertEq(
            WISE_LENDING.getPositionLendingShares(
                nftIDContract,
                SDAI_ADDRESS
            ),
            0,
            "User should not have lending shares left."
        );
    }
}


