// SPDX-License-Identifier: -- WISE --

pragma solidity =0.8.21;

import "./wstETHFarmBase.t.sol";

contract wstETHFarmTest is wstETHFarmBase {

    uint256 internal constant USED_BLOCK = 18061701;

    uint256 public nftIDContract;
    wstETHFarmTester public powerFarm;

    function setUp()
        public
    {
        vm.rollFork(
            USED_BLOCK
        );

        powerFarm = new wstETHFarmTester(
            WISE_LENDING_ADD,
            95 * PRECISION_FACTOR_E16
        );

        vm.prank(
            WISE_DEPLOYER
        );

        WISE_LENDING.setVeryfiedIsolationPool(
            address(powerFarm),
            true
        );
    }

    function testSetUp()
        public
    {
        assertEq(
            powerFarm.collateralFactor(),
            95 * PRECISION_FACTOR_E16
        );

        assertEq(
            powerFarm.borrowTokenAddresses(),
            WETH_ADDRESS
        );

        assertEq(
            powerFarm.aaveTokenAddresses(),
            AAVE_WETH_ADDRESS
        );
    }

    function testEnterFarm12xETH()
        public
    {
        TestData memory data = TestData({
            amount: 200 * PRECISION_FACTOR_E18,
            amountOpen: 10 * PRECISION_FACTOR_E18,
            leverage: 12 * PRECISION_FACTOR_E18
        });

        payable(WISE_DEPLOYER).transfer(
            data.amount
        );

        vm.startPrank(
            WISE_DEPLOYER
        );

        uint256[] memory ids = NFT.walletOfOwner(
            WISE_DEPLOYER
        );

        uint256 nftId = ids[0];

        AAVE_HUB.depositExactAmountETH{
            value: data.amount
        }(
            nftId
        );

        vm.stopPrank();

        powerFarm.enterFarmETH{
            value: data.amountOpen
        }(
            data.leverage
        );

        uint256[] memory positions = NFT.walletOfOwner(
            address(powerFarm)
        );

        nftIDContract = positions[0];

        uint256 debtratio = powerFarm.getLiveDebtRatio(
            nftIDContract
        );

        assertGt(
            debtratio,
            0,
            "Should be greater zero"
        );

        uint256 collatUSD = powerFarm.getTotalWeightedCollateralUSD(
            nftIDContract
        );

        uint256 borrowUSD = powerFarm.getPositionBorrowUSD(
            nftIDContract
        );

        uint256 collatBareUSD = collatUSD
            * PRECISION_FACTOR_E18
            / LTV;

        uint256 borrowToken = ORACLE_HUB.getTokensFromUSD(
            WETH_ADDRESS,
            borrowUSD
        );

        uint256 wethPrice = ORACLE_HUB.latestResolver(
            WETH_ADDRESS
        );

        assertApproxEqRel(
            borrowToken,
            data.amountOpen
                * (data.leverage - PRECISION_FACTOR_E18)
                / PRECISION_FACTOR_E18,
            POINT_ZERO_FIVE,
            "Borrow amount should be eleven times open amount"
        );

        assertApproxEqRel(
            collatBareUSD,
            data.amountOpen
                * data.leverage
                * wethPrice
                / PRECISION_FACTOR_E8
                / PRECISION_FACTOR_E18,
            POINT_ZERO_FIVE,
            "Collateral amount should be very close to 12 times open amount"
        );

        uint256 ethBalContract = address(powerFarm).balance;

        uint256 wethBalContract = WETH.balanceOf(
            address(powerFarm)
        );

        uint256 sethBalContract = ST_ETH.balanceOf(
            address(powerFarm)
        );

        uint256 wsethBalContract = WST_ETH.balanceOf(
            address(powerFarm)
        );

        assertGt(
            2,
            sethBalContract,
            "No sETH token should be left inside the contract"
        );

        assertEq(
            0,
            wsethBalContract,
            "No wsETH token should be left inside the contract"
        );

        assertEq(
            ethBalContract,
            0,
            "No ETH token should be left inside the contract"
        );

        assertEq(
            wethBalContract,
            0,
            "No WETH token should be left inside the contract"
        );
    }

    function testEnterFarm15xWETH()
        public
    {
        TestData memory data = TestData({
            amount: 2000 * PRECISION_FACTOR_E18,
            amountOpen: 100 * PRECISION_FACTOR_E18,
            leverage: 15 * PRECISION_FACTOR_E18
        });

        uint256[] memory ids = NFT.walletOfOwner(
            WISE_DEPLOYER
        );

        uint256 nftId = ids[0];

        payable(WISE_DEPLOYER).transfer(
            data.amount
        );

        vm.startPrank(
            WISE_DEPLOYER
        );

        AAVE_HUB.depositExactAmountETH{
            value: data.amount
        }(
            nftId
        );

        vm.stopPrank();

        WETH.deposit{
            value: data.amountOpen
        }();

        WETH.approve(
            address(powerFarm),
            HUGE_AMOUNT
        );

        powerFarm.enterFarm(
            data.amountOpen,
            data.leverage
        );

        uint256[] memory positions = NFT.walletOfOwner(
            address(powerFarm)
        );

        nftIDContract = positions[0];

        uint256 debtratio = powerFarm.getLiveDebtRatio(
            nftIDContract
        );

        assertGt(
            debtratio,
            0,
            "Should be greater zero"
        );

        uint256 collatUSD = powerFarm.getTotalWeightedCollateralUSD(
            nftIDContract
        );

        uint256 borrowUSD = powerFarm.getPositionBorrowUSD(
            nftIDContract
        );

        uint256 collatBareUSD = collatUSD
            * PRECISION_FACTOR_E18
            / LTV;

        uint256 borrowToken = ORACLE_HUB.getTokensFromUSD(
            WETH_ADDRESS,
            borrowUSD
        );

        uint256 wethPrice = ORACLE_HUB.latestResolver(
            WETH_ADDRESS
        );

        assertApproxEqRel(
            borrowToken,
            data.amountOpen
                * (data.leverage - PRECISION_FACTOR_E18)
                / PRECISION_FACTOR_E18,
            POINT_ZERO_FIVE,
            "Borrow amount should be 14 times open amount"
        );

        assertApproxEqRel(
            collatBareUSD,
            data.amountOpen
                * data.leverage
                * wethPrice
                / PRECISION_FACTOR_E8
                / PRECISION_FACTOR_E18,
            POINT_ZERO_FIVE,
            "Collateral amount should be very close to 15 times open amount"
        );

        uint256 ethBalContract = address(powerFarm).balance;

        uint256 wethBalContract = WETH.balanceOf(
            address(powerFarm)
        );

        uint256 sethBalContract = ST_ETH.balanceOf(
            address(powerFarm)
        );

        uint256 wsethBalContract = WST_ETH.balanceOf(
            address(powerFarm)
        );

        assertGt(
            2,
            sethBalContract,
            "No sETH token should be left inside the contract"
        );

        assertEq(
            0,
            wsethBalContract,
            "No wsETH token should be left inside the contract"
        );

        assertEq(
            ethBalContract,
            0,
            "No ETH token should be left inside the contract"
        );

        assertEq(
            wethBalContract,
            0,
            "No WETH token should be left inside the contract"
        );
    }

    function testLiquidation()
        public
    {
        TestData memory data = TestData({
            amount: 10000 * PRECISION_FACTOR_E18,
            amountOpen: 200 * PRECISION_FACTOR_E18,
            leverage: 15 * PRECISION_FACTOR_E18
        });

        uint256 liquidationAmount = 100000 * PRECISION_FACTOR_E18;

        uint256[] memory idsDeployer = NFT.walletOfOwner(
            WISE_DEPLOYER
        );

        uint256 nftIdDeployer = idsDeployer[0];

        payable(WISE_DEPLOYER).transfer(
            liquidationAmount + data.amount
        );

        vm.prank(
            WISE_DEPLOYER
        );

        AAVE_HUB.depositExactAmountETH{value: data.amount}(
            nftIdDeployer
        );

        powerFarm.enterFarmETH{value: data.amountOpen}(
            data.leverage
        );

        uint256[] memory idsFarm = NFT.walletOfOwner(
            address(powerFarm)
        );

        uint256 nftIdFarm = idsFarm[0];

        powerFarm.setCollfactor(
            92890 * PRECISION_FACTOR_E13
        );

        vm.startPrank(
            WISE_DEPLOYER
        );

        WETH.deposit{
            value: liquidationAmount
        }();

        WETH.approve(
            address(AAVE),
            HUGE_AMOUNT
        );

        AAVE.deposit(
            WETH_ADDRESS,
            liquidationAmount,
            WISE_DEPLOYER,
            0
        );

        IERC20Test(AAVE_WETH_ADDRESS).approve(
            WISE_LENDING_ADD,
            HUGE_AMOUNT
        );

        uint256 borrowSharesUser = WISE_LENDING.getPositionBorrowShares(
            nftIdFarm,
            AAVE_WETH_ADDRESS
        );

        uint256 portionShares = borrowSharesUser
            * FOURTY_PERCENT
            / PRECISION_FACTOR_E18;

        vm.expectRevert();

        WISE_LENDING.liquidatePartiallyFromTokens(
            nftIdFarm,
            nftIdDeployer,
            AAVE_WETH_ADDRESS,
            WST_ETH_ADDRESS,
            portionShares
        );

        IERC20Test(AAVE_WETH_ADDRESS).approve(
            address(powerFarm),
            HUGE_AMOUNT
        );

        uint256 debtRatio = powerFarm.getLiveDebtRatio(
            nftIdFarm
        );

        uint256 wstETH = IERC20Test(WST_ETH_ADDRESS).balanceOf(
            WISE_DEPLOYER
        );

        powerFarm.liquidatePartiallyFromToken(
            nftIdFarm,
            nftIdDeployer,
            portionShares
        );

        vm.stopPrank();

        uint256 debtRatioEnd = powerFarm.getLiveDebtRatio(
            nftIdFarm
        );

        uint256 wstETHEnd = IERC20Test(WST_ETH_ADDRESS).balanceOf(
            WISE_DEPLOYER
        );

        assertGt(
            wstETHEnd - wstETH,
            0,
            "Receiving token amount should be greater than zero."
        );

        assertGt(
            debtRatio,
            debtRatioEnd,
            "Debt ratio should be smaller after liquidation."
        );
    }


    function testClosePositionETH()
        public
    {
        TestData memory data = TestData({
            amount: 1000 * PRECISION_FACTOR_E18,
            amountOpen: 125 * PRECISION_FACTOR_E18,
            leverage: 6 * PRECISION_FACTOR_E18
        });

        uint256[] memory ids = NFT.walletOfOwner(
            WISE_DEPLOYER
        );

        uint256 nftId = ids[0];

        payable(WISE_DEPLOYER).transfer(
            data.amount
        );

        vm.prank(
            WISE_DEPLOYER
        );

        AAVE_HUB.depositExactAmountETH{
            value: data.amount
        }(
            nftId
        );

        uint256 farmKey = powerFarm.enterFarmETH{
            value: data.amountOpen
        }(
            data.leverage
        );

        uint256[] memory idsFarm = NFT.walletOfOwner(
            address(powerFarm)
        );

        uint256 nftIdFarm = idsFarm[0];

        uint256 balETH = address(this).balance;

        powerFarm.exitFarm(
            farmKey,
            0,
            true
        );

        uint256 collatUSD = powerFarm.getTotalWeightedCollateralUSD(
            nftIdFarm
        );

        uint256 borrowUSD = powerFarm.getPositionBorrowUSD(
            nftIdFarm
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

        uint256 ethBalContract = address(powerFarm).balance;

        uint256 wethBalContract = WETH.balanceOf(
            address(powerFarm)
        );

        uint256 sethBalContract = ST_ETH.balanceOf(
            address(powerFarm)
        );

        uint256 wsethBalContract = WST_ETH.balanceOf(
            address(powerFarm)
        );

        uint256 balETHEnd = address(this).balance;

        assertGt(
            2,
            sethBalContract,
            "No sETH token should be left inside the contract"
        );

        assertEq(
            0,
            wsethBalContract,
            "No wsETH token should be left inside the contract"
        );

        assertEq(
            ethBalContract,
            0,
            "No ETH token should be left inside the contract"
        );

        assertEq(
            wethBalContract,
            0,
            "No WETH token should be left inside the contract"
        );

        assertGt(
            balETHEnd - balETH,
            0,
            "User should get some token"
        );
    }


    function testClosePositionWETH()
        public
    {
        TestData memory data = TestData({
            amount: 100000 * PRECISION_FACTOR_E18,
            amountOpen: 600 * PRECISION_FACTOR_E18,
            leverage: 15 * PRECISION_FACTOR_E18
        });

        uint256[] memory ids = NFT.walletOfOwner(
            WISE_DEPLOYER
        );

        uint256 nftId = ids[0];

        payable(WISE_DEPLOYER).transfer(
            data.amount
        );

        vm.prank(
            WISE_DEPLOYER
        );

        AAVE_HUB.depositExactAmountETH{value: data.amount}(
            nftId
        );

        uint256 farmKey = powerFarm.enterFarmETH{value: data.amountOpen}(
            data.leverage
        );

        uint256 balWETH = WETH.balanceOf(
            address(this)
        );

        uint256[] memory idsFarm = NFT.walletOfOwner(
            address(powerFarm)
        );

        uint256 nftIdFarm = idsFarm[0];

        powerFarm.exitFarm(
            farmKey,
            0,
            false
        );

        uint256 collatUSD = powerFarm.getTotalWeightedCollateralUSD(
            nftIdFarm
        );

        uint256 borrowUSD = powerFarm.getPositionBorrowUSD(
            nftIdFarm
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

        uint256 ethBalContract = address(powerFarm).balance;

        uint256 wethBalContract = WETH.balanceOf(
            address(powerFarm)
        );

        uint256 sethBalContract = ST_ETH.balanceOf(
            address(powerFarm)
        );

        uint256 wsethBalContract = WST_ETH.balanceOf(
            address(powerFarm)
        );

        uint256 balWETHEnd = WETH.balanceOf(
            address(this)
        );

        assertGt(
            2,
            sethBalContract,
            "No sETH token should be left inside the contract"
        );

        assertEq(
            0,
            wsethBalContract,
            "No wsETH token should be left inside the contract"
        );

        assertEq(
            ethBalContract,
            0,
            "No ETH token should be left inside the contract"
        );

        assertEq(
            wethBalContract,
            0,
            "No WETH token should be left inside the contract"
        );

        assertGt(
            balWETHEnd - balWETH,
            0,
            "User should get some token"
        );
    }

    function testSecurityWithdraw()
        public
    {
        TestData memory data = TestData({
            amount: 1000 * PRECISION_FACTOR_E18,
            amountOpen: 40 * PRECISION_FACTOR_E18,
            leverage: 5 * PRECISION_FACTOR_E18
        });

        payable(WISE_DEPLOYER).transfer(
            2 * data.amount
        );

        uint256[] memory ids = NFT.walletOfOwner(
            WISE_DEPLOYER
        );

        uint256 nftId = ids[0];

        vm.prank(
            WISE_DEPLOYER
        );

        AAVE_HUB.depositExactAmountETH{
            value: data.amount
        }(
            nftId
        );

        uint256 farmKey = powerFarm.enterFarmETH{
            value: data.amountOpen
        }(
            data.leverage
        );

        uint256[] memory idsFarm = NFT.walletOfOwner(
            address(powerFarm)
        );

        uint256 nftIdFarm = idsFarm[0];

        WETH.deposit{
            value: data.amount
        }();

        WETH.approve(
            address(AAVE),
            HUGE_AMOUNT
        );

        AAVE.deposit(
            WETH_ADDRESS,
            data.amount,
            address(this),
            0
        );

        uint256 borrowShares = WISE_LENDING.getPositionBorrowShares(
            nftIdFarm,
            AAVE_WETH_ADDRESS
        );

        IERC20Test(AAVE_WETH_ADDRESS).approve(
            address(powerFarm),
            HUGE_AMOUNT
        );

        powerFarm.manuallyPaybackShares(
            farmKey,
            borrowShares / 2
        );

        uint256 lendingShares = WISE_LENDING.getPositionLendingShares(
            nftIdFarm,
            WST_ETH_ADDRESS
        );

        uint256 moreThanHalf = lendingShares
            * 60 * PRECISION_FACTOR_E16
            / PRECISION_FACTOR_E18;

        vm.expectRevert(
            ResultsInBadDebt.selector
        );

        powerFarm.manuallyWithdrawShares(
            farmKey,
            moreThanHalf
        );

        uint256 borrowSharesRest = WISE_LENDING.getPositionBorrowShares(
            nftIdFarm,
            AAVE_WETH_ADDRESS
        );

        powerFarm.manuallyPaybackShares(
            farmKey,
            borrowSharesRest
        );

        uint256 balWSTETH = WST_ETH.balanceOf(
            address(this)
        );

        powerFarm.manuallyWithdrawShares(
            farmKey,
            lendingShares
        );

        uint256 balWSTETHEnd = WST_ETH.balanceOf(
            address(this)
        );

        assertApproxEqRel(
            ORACLE_HUB.getTokensFromUSD(
                WETH_ADDRESS,
                ORACLE_HUB.getTokensInUSD(
                    WST_ETH_ADDRESS,
                    balWSTETHEnd - balWSTETH
                )
            ),
            data.amountOpen
                * data.leverage
                / PRECISION_FACTOR_E18,
            POINT_ZERO_FIVE,
            "Returning amount should be very close to 5 times open amount"
        );

        assertEq(
            WISE_LENDING.getPositionLendingShares(
                nftIdFarm,
                WST_ETH_ADDRESS
            ),
            0,
            "User should not have lending shares left."
        );
    }

    function testSecurityPayback()
        public
    {
        TestData memory data = TestData({
            amount: 800 * PRECISION_FACTOR_E18,
            amountOpen: 50 * PRECISION_FACTOR_E18,
            leverage: 7 * PRECISION_FACTOR_E18
        });

        payable(WISE_DEPLOYER).transfer(
            2 * data.amount
        );

        uint256[] memory ids = NFT.walletOfOwner(
            WISE_DEPLOYER
        );

        uint256 nftId = ids[0];

        vm.prank(
            WISE_DEPLOYER
        );

        AAVE_HUB.depositExactAmountETH{
            value: data.amount
        }(
            nftId
        );

        uint256 farmKey = powerFarm.enterFarmETH{
            value: data.amountOpen
        }(
            data.leverage
        );

        uint256[] memory idsFarm = NFT.walletOfOwner(
            address(powerFarm)
        );

        uint256 nftIdFarm = idsFarm[0];

        uint256 borrowShares = WISE_LENDING.getPositionBorrowShares(
            nftIdFarm,
            AAVE_WETH_ADDRESS
        );

        vm.startPrank(
            WISE_DEPLOYER
        );

        WETH.deposit{
            value: data.amount
        }();

        WETH.approve(
            address(AAVE),
            HUGE_AMOUNT
        );

        AAVE.deposit(
            WETH_ADDRESS,
            data.amount,
            WISE_DEPLOYER,
            0
        );

        _safeApprove(
            AAVE_WETH_ADDRESS,
            address(powerFarm),
            HUGE_AMOUNT
        );

        powerFarm.manuallyPaybackShares(
            farmKey,
            borrowShares
        );

        vm.stopPrank();

        uint256 borrowUSDAfter = powerFarm.getPositionBorrowUSD(
            nftIdFarm
        );

        uint256 debtratio = powerFarm.getLiveDebtRatio(
            nftIdFarm
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

    function testUIFunctions()
        public
    {
        uint256 DUMMY_WST_ETH_APY = 35 * PRECISION_FACTOR_E15;

        TestData memory data = TestData({
            amount: 5000 * PRECISION_FACTOR_E18,
            amountOpen: 80 * PRECISION_FACTOR_E18,
            leverage: 11 * PRECISION_FACTOR_E18
        });

        uint256[] memory ids = NFT.walletOfOwner(
            WISE_DEPLOYER
        );

        uint256 nftId = ids[0];

        payable(WISE_DEPLOYER).transfer(
            data.amount
        );

        vm.startPrank(
            WISE_DEPLOYER
        );

        AAVE_HUB.depositExactAmountETH{value: data.amount}(
            nftId
        );

        vm.stopPrank();

        uint256 borrowAmount = data.amountOpen
            * (data.leverage - PRECISION_FACTOR_E18)
            / PRECISION_FACTOR_E18;

        uint256 newRate = powerFarm.getNewBorrowRate(
            borrowAmount
        );

        assertGt(
            newRate,
            0,
            "New borrow rate should be greater than zero."
        );

        (
            uint256 approxNetAPY,
            bool isPositive
        ) = powerFarm.getApproxNetAPY(
            data.amountOpen,
            data.leverage,
            DUMMY_WST_ETH_APY
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

        powerFarm.enterFarmETH{
            value: data.amountOpen
        }(
            data.leverage
        );

        uint256 currentRate = WISE_SECURITY.getBorrowRate(
            AAVE_WETH_ADDRESS
        );

        assertEq(
            currentRate,
            newRate,
            "Contract rate and calculated should be equal."
        );
    }

    function testDepositThreshold()
        public
    {
        TestData memory data = TestData({
            amount: 200 * PRECISION_FACTOR_E18,
            amountOpen: 1 * PRECISION_FACTOR_E18,
            leverage: 2 * PRECISION_FACTOR_E18
        });

        uint256 initialThreshold = powerFarm.minDepositUsdAmount();

        assertGt(
            initialThreshold,
            0,
            "initialThreshold should be greater than zero."
        );

        payable(WISE_DEPLOYER).transfer(
            data.amount
        );

        vm.startPrank(
            WISE_DEPLOYER
        );

        uint256[] memory ids = NFT.walletOfOwner(
            WISE_DEPLOYER
        );

        uint256 nftId = ids[0];

        AAVE_HUB.depositExactAmountETH{
            value: data.amount
        }(
            nftId
        );

        vm.expectRevert(
            AmountTooSmall.selector
        );

        powerFarm.enterFarmETH{
            value: data.amountOpen
        }(
            data.leverage
        );

        WETH.deposit{
            value: data.amountOpen
        }();

        WETH.approve(
            address(powerFarm),
            HUGE_AMOUNT
        );

        vm.expectRevert(
            AmountTooSmall.selector
        );

        powerFarm.enterFarm(
            data.amountOpen,
            data.leverage
        );

        vm.expectRevert(
            NotMaster.selector
        );

        powerFarm.changeMinDeposit(
            0
        );

        vm.stopPrank();

        powerFarm.changeMinDeposit(
            0
        );

        uint256 changedThreshold = powerFarm.minDepositUsdAmount();

        assertEq(
            changedThreshold,
            0,
            "Threshold should be zero."
        );

        vm.startPrank(
            WISE_DEPLOYER
        );

        powerFarm.enterFarmETH{
            value: data.amountOpen
        }(
            data.leverage
        );

        powerFarm.mintReserved();

        powerFarm.enterFarm(
            data.amountOpen,
            data.leverage
        );
    }

    function testDeactivation()
        public
    {
        uint256 DUMMY_INITAL = 1000 * PRECISION_FACTOR_E18;
        uint256 DUMMY_LEVERAGE = 2 * PRECISION_FACTOR_E18;

        vm.prank(
            WISE_DEPLOYER
        );

        vm.expectRevert(
            NotMaster.selector
        );

        powerFarm.shutdownFarm(
            true
        );

        powerFarm.shutdownFarm(
            true
        );

        vm.expectRevert(
            Deactivated.selector
        );

        powerFarm.enterFarmETH(
            DUMMY_LEVERAGE
        );

        vm.expectRevert(
            Deactivated.selector
        );

        powerFarm.enterFarm(
            DUMMY_INITAL,
            DUMMY_LEVERAGE
        );
    }
}