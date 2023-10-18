// SPDX-License-Identifier: -- WISE --

pragma solidity =0.8.21;

import "./wstETHFarmBase.t.sol";


interface IBal {

    function flashLoan(
        IFlashLoanRecipient recipient,
        IERC20[] memory tokens,
        uint256[] memory amounts,
        bytes memory userData
    )
        external;
}

contract wstETHFarmTestExtra is wstETHFarmBase {

    uint256 internal constant USED_BLOCK = 18061701;

    uint256 public nftIDContract;
    wstETHFarmTester public powerFarm;

    address payable[] internal users;

    address internal alice;
    address internal bob;

    function setUp()
        public
    {
        vm.rollFork(
            USED_BLOCK
        );

        users = createUsers(5);

        alice = users[0];

        vm.label(
            alice,
            "Alice"
        );

        vm.deal(
            alice,
            100 ether
        );

        bob = users[1];

        vm.label(
            bob,
            "Bob"
        );

        vm.deal(
            bob,
            100 ether
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

    function testDebtRatio()
        public
    {
        uint256 totalSupply = NFT.totalSupply();

        uint256 ratio = powerFarm.getLiveDebtRatio(
            totalSupply + 1
        );

        assertEq(
            ratio,
            0,
            "Debt ratio should be 0"
        );

        powerFarm.doApprovals();
    }

    function testSetBaseURL()
        public
    {
        string memory baseURL = powerFarm.baseURI();

        assertEq(
            baseURL,
            "meta-path",
            "Base URL should be correct"
        );

        string memory newBase = "meta-path-2";

        powerFarm.setBaseURI(
            newBase
        );

        string memory newBaseURL = powerFarm.baseURI();

        assertEq(
            newBaseURL,
            newBase,
            "Updated BaseURL should be correct"
        );
    }

    function testSetBaseExtension()
        public
    {
        string memory baseExtension = powerFarm.baseExtension();

        assertEq(
            baseExtension,
            "",
            "Base extension should be correct"
        );

        string memory newExtension = ".json";

        powerFarm.setBaseExtension(
            newExtension
        );

        string memory updatedExtension = powerFarm.baseExtension();

        assertEq(
            updatedExtension,
            newExtension,
            "Base extension should be updated"
        );
    }

    function testGetLeverageAmount()
        public
    {
        uint256 input = 1 ether;
        uint256 leverage = 2E18;
        uint256 amount = powerFarm.getLeverageAmount(
            input,
            leverage
        );

        assertGt(
            amount,
            0,
            "Should be above 0"
        );

        uint256 expectedValue = input
            * leverage
            / PRECISION_FACTOR_E18;

        assertEq(
            amount,
            expectedValue,
            "Should be correct"
        );
    }

    function testApproveMintFuzzy(
        uint256 _inputFuzzy
    )
        public
    {
        if (_inputFuzzy == 0) {
            vm.expectRevert(
                InvalidKey.selector
            );

            powerFarm.approveMint(
                alice,
                _inputFuzzy
            );
        } else {
            vm.expectRevert(
                "ERC721: invalid token ID"
            );

            powerFarm.approveMint(
                alice,
                _inputFuzzy
            );
        }
    }

    function testApproveMint()
        public
    {
        vm.expectRevert(
            InvalidKey.selector
        );

        powerFarm.mintReserved();

        vm.expectRevert(
            InvalidKey.selector
        );

        powerFarm.approveMint(
            alice,
            0
        );

        vm.expectRevert(
            "ERC721: invalid token ID"
        );

        powerFarm.approveMint(
            alice,
            1
        );

        TestData memory data = TestData({
            amount: 5000 * PRECISION_FACTOR_E18,
            amountOpen: 1 * PRECISION_FACTOR_E18,
            leverage: 10 * PRECISION_FACTOR_E18
        });

        executeRoutine(data);

        vm.startPrank(
            WISE_DEPLOYER
        );

        uint256 key = powerFarm.enterFarmETH{
            value: data.amountOpen
        }(
            data.leverage
        );

        vm.expectRevert(
            "ERC721: invalid token ID"
        );

        powerFarm.approveMint(
            alice,
            0
        );

        vm.stopPrank();

        vm.expectRevert(
            InvalidKey.selector
        );

        powerFarm.approveMint(
            alice,
            0
        );

        vm.expectRevert(
            "ERC721: invalid token ID"
        );

        powerFarm.approveMint(
            alice,
            1
        );

        vm.startPrank(
            WISE_DEPLOYER
        );

        vm.expectRevert(
            "ERC721: invalid token ID"
        );

        powerFarm.approveMint(
            alice,
            0
        );

        vm.expectRevert(
            "ERC721: invalid token ID"
        );

        powerFarm.approve(
            alice,
            key
        );

        powerFarm.approveMint(
            alice,
            key
        );

        address approvedAlice = powerFarm.getApproved(
            key
        );

        assertEq(
            approvedAlice,
            alice,
            "Approved should be Alice"
        );

        assertEq(
            powerFarm.ownerOf(key),
            WISE_DEPLOYER,
            "Owner should be correct"
        );

        powerFarm.approveMint(
            bob,
            key
        );

        address approvedBob = powerFarm.getApproved(
            key
        );

        assertEq(
            approvedBob,
            bob,
            "Approved should be Bob"
        );

        vm.expectRevert(
            InvalidKey.selector
        );

        powerFarm.mintReserved();

        powerFarm.approveMint(
            alice,
            key
        );

        powerFarm.approveMint(
            bob,
            key
        );

        powerFarm.approve(
            alice,
            key
        );

        address approvedAliceAgain = powerFarm.getApproved(
            key
        );

        assertEq(
            approvedAliceAgain,
            alice,
            "Approved should be alice"
        );

        vm.expectRevert(
            InvalidKey.selector
        );

        powerFarm.mintReserved();
    }

    function executeRoutine(TestData memory data)
        public
    {
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
    }

    function testUIFunctionsExtra()
        public
    {
        TestData memory data = TestData({
            amount: 5000 * PRECISION_FACTOR_E18,
            amountOpen: 80 * PRECISION_FACTOR_E18,
            leverage: 11 * PRECISION_FACTOR_E18
        });

        executeRoutine(data);

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
            0,
            0
        );

        assertEq(
            approxNetAPY,
            0,
            "Approx net APY should be 0"
        );

        assertEq(
            isPositive,
            false,
            "Net APY should be negative."
        );

        vm.expectRevert(
            InvalidKey.selector
        );

        powerFarm.mintReserved();

        uint256 key = powerFarm.enterFarmETH{
            value: data.amountOpen
        }(
            data.leverage
        );

        powerFarm.mintReserved();

        bool checkAlice = powerFarm.isOwner(
            key,
            alice
        );

        assertEq(
            checkAlice,
            false,
            "Owner should not match"
        );

        uint256 out = powerFarm.getMinAmountOut(
            key,
            0.95E18
        );

        assertGt(
            out,
            0,
            "Min amount out should be greater than zero."
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

    function testChangeRefAddress()
        public
    {
        vm.startPrank(
            WISE_DEPLOYER
        );

        vm.expectRevert(
            NotMaster.selector
        );

        powerFarm.changeRefAddress(
            WISE_DEPLOYER
        );

        vm.stopPrank();

        address refAddressBefore = powerFarm.referralAddress();

        powerFarm.changeRefAddress(
            WISE_DEPLOYER
        );

        address refAddressAfter = powerFarm.referralAddress();

        assertNotEq(
            refAddressBefore,
            refAddressAfter,
            "Referral address should change"
        );

        assertEq(
            refAddressAfter,
            WISE_DEPLOYER,
            "Referral address should change to correct one"
        );
    }

    function testMaxLeverage()
        public
    {
        uint256 NORMAL_LEVERAGE = 15 * PRECISION_FACTOR_E18;
        uint256 TOO_HIGH_LEVERAGE = 16 * PRECISION_FACTOR_E18;

        vm.startPrank(
            WISE_DEPLOYER
        );

        vm.expectRevert(
            LeverageTooHigh.selector
        );

        powerFarm.enterFarmETH{
            value: 1 ether
        }(
            TOO_HIGH_LEVERAGE
        );

        vm.expectRevert(
            "wstETHManager: WRONG_TOKEN"
        );

        powerFarm.tokenURI(
            0
        );

        vm.expectRevert(
            "wstETHManager: WRONG_TOKEN"
        );

        powerFarm.tokenURI(
            1
        );

        powerFarm.enterFarmETH{
            value: 1 ether
        }(
            NORMAL_LEVERAGE
        );

        powerFarm.mintReserved();

        uint256 firstToken = 1;

        string memory tokenURI = powerFarm.tokenURI(
            firstToken
        );

        assertEq(
            tokenURI,
            "meta-path1",
            "Expected correct tokenURI"
        );

        vm.stopPrank();

        powerFarm.setBaseURI("");

        string memory newTokenURI = powerFarm.tokenURI(
            firstToken
        );

        assertEq(
            newTokenURI,
            "",
            "Expected empty tokenURI"
        );

        powerFarm.setBaseURI(
            "https://wise-token.com/"
        );

        string memory wiseTokenURI = powerFarm.tokenURI(
            firstToken
        );

        assertEq(
            wiseTokenURI,
            "https://wise-token.com/1",
            "Expected WISE tokenURI"
        );
    }

    function testLowAmount()
        public
    {
        uint256 TOO_HIGH_LEVERAGE = 15 * PRECISION_FACTOR_E18;

        vm.startPrank(
            WISE_DEPLOYER
        );

        vm.expectRevert(
            AmountTooSmall.selector
        );

        powerFarm.enterFarmETH{
            value: 0.1 ether
        }(
            TOO_HIGH_LEVERAGE
        );
    }

    function testAttack()
        public
    {
        TestData memory data = TestData({
            amount: 200 * PRECISION_FACTOR_E18,
            amountOpen: 3 * PRECISION_FACTOR_E18,
            leverage: 8 * PRECISION_FACTOR_E18
        });

        executeRoutine(data);

        vm.startPrank(
            WISE_DEPLOYER
        );

        address balancerVaultAdd = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
        address aavewethAddress = 0x4d5F47FA6A74757f35C14fD3a6Ef8E3C9BC514E8;
        address wstethAddress = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
        address randomUser = 0x9404f4B0846A2cD5c659c1edD52BA60abF1F10F4;

        // open first position
        uint256 farmKey1 = powerFarm.enterFarmETH{
            value: data.amountOpen
        }(
            data.leverage
        );

        uint256 nonExistingKey = 0;

        bool noOwner = powerFarm.isOwner(
            nonExistingKey,
            randomUser
        );

        assertEq(
            noOwner,
            true
        );

        bool trueOwner = powerFarm.isOwner(
            farmKey1,
            WISE_DEPLOYER
        );

        assertEq(
            trueOwner,
            true,
            "Owner should be correct"
        );

        vm.expectRevert(
            "ERC721: invalid token ID"
        );

        bool falseOwner = powerFarm.isOwner(
            farmKey1,
            randomUser
        );

        assertEq(
            falseOwner,
            false,
            "Owner should not match"
        );

        uint256 farmNFT1 = powerFarm.farmingKeys(
            farmKey1
        );

        bytes memory userData = abi.encode(
            farmNFT1,
            0,
            WISE_LENDING.getPositionLendingShares(
                farmNFT1,
                wstethAddress
            ),
            WISE_LENDING.getPositionBorrowShares(
                farmNFT1,
                aavewethAddress
            ),
            0,
            randomUser,
            true
        );

        IBal balalancerInstance = IBal(
            balancerVaultAdd
        );

        IERC20[] memory tokens = new IERC20[](1);
        tokens[0] = IERC20(WETH_ADDRESS);

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 21E18;

        vm.expectRevert(
            AccessDenied.selector
        );

        balalancerInstance.flashLoan(
            IFlashLoanRecipient(
                address(powerFarm)
            ),
            tokens,
            amounts,
            userData
        );

        uint256 balanceBefore = address(WISE_DEPLOYER).balance;

        powerFarm.exitFarm(
            farmKey1,
            23E18,
            true
        );

        uint256 balanceAfter = address(WISE_DEPLOYER).balance;

        assertGt(
            balanceAfter,
            balanceBefore,
            "Balance should increase for initial key holder"
        );
    }

    function testNFTReuse()
        public
    {
        TestData memory data = TestData({
            amount: 200 * PRECISION_FACTOR_E18,
            amountOpen: 1 * PRECISION_FACTOR_E18,
            leverage: 12 * PRECISION_FACTOR_E18
        });

        executeRoutine(data);

        vm.startPrank(
            WISE_DEPLOYER
        );

        // open first position
        uint256 farmKey1 = powerFarm.enterFarmETH{
            value: data.amountOpen
        }(
            data.leverage
        );

        // try to open again
        vm.expectRevert(
            AlreadyReserved.selector
        );

        // should fail again
        powerFarm.enterFarmETH{
            value: data.amountOpen
        }(
            data.leverage
        );

        powerFarm.mintReserved();

        // open second position
        uint256 farmKey2 = powerFarm.enterFarmETH{
            value: data.amountOpen
        }(
            data.leverage
        );

        uint256[] memory farmNFTs = NFT.walletOfOwner(
            address(powerFarm)
        );

        uint256[] memory farmKeys = powerFarm.walletOfOwner(
            WISE_DEPLOYER
        );

        assertEq(
            farmKeys.length,
            2,
            "Expected 2 keys after opening 2 positions"
        );

        assertEq(
            farmKeys[0],
            farmKey1,
            "Expected first key to match"
        );

        assertEq(
            farmKeys[1],
            farmKey2,
            "Expected second key to match"
        );

        // console.log(farmNFTs[0], 'farmNFTs');
        // console.log(farmNFTs[1], 'farmNFTs');

        uint256 expectedLendingNFT = 16;
        uint256 expectedLendingNFTReuse = 17;

        assertEq(
            powerFarm.farmingKeys(
                farmKey1
            ),
            expectedLendingNFT,
            "NFT #16 should be associated with key #1"
        );

        assertEq(
            powerFarm.farmingKeys(
                farmKey2
            ),
            expectedLendingNFTReuse,
            "NFT #17 should be associated with key #2"
        );

        assertEq(
            powerFarm.farmingKeys(
                farmKey2
            ),
            farmNFTs[1],
            "NFT #17 should be associated with key #2"
        );

        assertEq(
            farmNFTs.length,
            2,
            "Only 2 WiseLending NFTs expected"
        );

        assertEq(
            powerFarm.totalMinted(),
            1,
            "Only 1 farmKey minted expected"
        );

        assertEq(
            powerFarm.totalReserved(),
            1,
            "Only 1 farmKey reserved expected"
        );

        powerFarm.mintReserved();

        assertEq(
            powerFarm.totalMinted(),
            2,
            "2 farmKey minted expected after mint"
        );

        assertEq(
            powerFarm.totalReserved(),
            0,
            "0 farmKey reserved expected after mint"
        );

        assertEq(
            powerFarm.availableNFTCount(),
            0,
            "No NFTs should be available for reuse"
        );

        uint256 exitFarmKey = farmKey2;

        assertEq(
            powerFarm.farmingKeys(
                exitFarmKey
            ),
            expectedLendingNFTReuse
        );

        assertEq(
            powerFarm.farmingKeys(
                exitFarmKey
            ),
            farmNFTs[1],
            "NFT #17 should be associated with key #2"
        );

        // close second position
        powerFarm.exitFarm(
            exitFarmKey,
            0,
            true
        );

        assertEq(
            powerFarm.availableNFTCount(),
            1,
            "1 NFT should be available for reuse"
        );

        assertEq(
            powerFarm.farmingKeys(
                exitFarmKey
            ),
            0,
            "NFT should be removed from key association"
        );

        assertEq(
            powerFarm.availableNFTs(1),
            expectedLendingNFTReuse,
            "NFT #17 should be available for reuse"
        );

        vm.stopPrank();

        vm.prank(
            alice
        );

        // open another position after closure
        uint256 aliceKey = powerFarm.enterFarmETH{
            value: data.amountOpen
        }(
            data.leverage
        );

        uint256[] memory farmNFTsAgain = NFT.walletOfOwner(
            address(powerFarm)
        );

        assertEq(
            farmNFTsAgain.length,
            2,
            "Amount of WiseLendingNFTs should not change"
        );

        assertEq(
            powerFarm.totalReserved(),
            1,
            "Reserved would be 1"
        );

        assertEq(
            powerFarm.totalMinted(),
            2,
            "But amount of keys minted would stay"
        );

        assertEq(
            aliceKey,
            3,
            "Alice should get key #3"
        );

        assertEq(
            powerFarm.availableNFTCount(),
            0,
            "0 NFT should be available for reuse"
        );

        assertEq(
            powerFarm.farmingKeys(
                aliceKey
            ),
            expectedLendingNFTReuse,
            "NFT #17 should been reused"
        );

        assertEq(
            powerFarm.availableNFTCount(),
            0,
            "No available NFT should present"
        );

        assertEq(
            powerFarm.availableNFTs(1),
            expectedLendingNFTReuse,
            "But record remains in the mapping"
        );

        vm.startPrank(
            bob
        );

        // open another position after Alice
        uint256 bobsKey = powerFarm.enterFarmETH{
            value: data.amountOpen
        }(
            data.leverage
        );

        assertEq(
            powerFarm.farmingKeys(
                bobsKey
            ),
            expectedLendingNFTReuse + 1,
            "Bob should get NFT #18"
        );

        // close Bobs position
        powerFarm.exitFarm(
            bobsKey,
            0,
            true
        );

        assertEq(
            powerFarm.farmingKeys(
                bobsKey
            ),
            0,
            "NFT should be removed from key association"
        );

        assertEq(
            powerFarm.availableNFTCount(),
            1,
            "1 NFT should be available for reuse"
        );

        assertEq(
            powerFarm.availableNFTs(1),
            expectedLendingNFTReuse + 1,
            "NFT #18 should be available for reuse"
        );
    }
}