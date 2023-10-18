// SPDX-License-Identifier: -- WISE --

pragma solidity =0.8.21;

import "forge-std/Test.sol";

import "../../WiseLending.sol";

import "../../TestInterfaces/IWiseLendingTest.sol";
import "../../TestInterfaces/IAaveHubTest.sol";
import "../../TestInterfaces/IOracleHubTest.sol";
import "../../TestInterfaces/INftTest.sol";
import "../../TestInterfaces/IERC20Test.sol";
import "../../TestInterfaces/IWiseSecurityTest.sol";

import "../../TransferHub/TransferHelper.sol";
import "../../TransferHub/ApprovalHelper.sol";

import "./sDaiFarm.sol";

contract SDaiFarmTestBase is Test, TransferHelper, ApprovalHelper {

    address public WISE_DEPLOYER = 0x641AD78BAca220C5BD28b51Ce8e0F495e85Fe689;

    address public DAI_WHALE = 0xaD0135AF20fa82E106607257143d0060A7eB5cBf;
    address public USDC_WHALE = 0xCc0378Ac521F07d25A7bB6f8192936b94E91bFff;
    address public USDT_WHALE = 0x68841a1806fF291314946EebD0cdA8b348E73d6D;

    address public constant WISE_ORACLE_ADD = 0xD2cAa748B66768aC9c53A5443225Bdf1365dd4B6;
    address public constant WISE_SECURITY_ADD = 0x5F8B6c17C3a6EF18B5711f9b562940990658400D;
    address public constant WISE_LENDING_ADD = 0x84524bAa1951247b3A2617A843e6eCe915Bb9674;
    address public constant AAVE_HUB_ADD = 0x4307d8207f2C429f0dCbd9051b5B1d638c3b7fbB;
    address public constant NFT_ADD = 0x9D6d4e2AfAB382ae9B52807a4B36A8d2Afc78b07;

    address public constant SDAI_ADDRESS = 0x83F20F44975D03b1b09e64809B757c47f942BEeA;
    address public constant DSS_PSM_ADD = 0x89B78CfA322F6C5dE0aBcEecab66Aee45393cC5A;

    address public constant DAI_ADDRESS = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public constant USDT_ADDRESS = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address public constant USDC_ADDRESS = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    address public constant AAVE_DAI_ADDRESS = 0x018008bfb33d285247A21d44E50697654f754e63;
    address public constant AAVE_USDT_ADDRESS = 0x23878914EFE38d27C4D67Ab83ed1b93A74D4086a;
    address public constant AAVE_USDC_ADDRESS = 0x98C23E9d8f34FEFb1B7BD6a91B7FF122F4e16F5c;

    uint256 public constant PRECISION_FACTOR_E6 = 1E6;
    uint256 public constant PRECISION_FACTOR_E8 = 1E8;
    uint256 public constant PRECISION_FACTOR_E14 = 1E14;
    uint256 public constant PRECISION_FACTOR_E15 = 1E15;
    uint256 public constant PRECISION_FACTOR_E16 = 1E16;
    uint256 public constant PRECISION_FACTOR_E17 = 1E17;
    uint256 public constant PRECISION_FACTOR_E18 = 1E18;

    uint256 public constant LTV = 95 * PRECISION_FACTOR_E16;
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

    INftTest public constant NFT = INftTest(
        NFT_ADD
    );

    IOracleHubTest public constant ORACLE_HUB = IOracleHubTest(
        WISE_ORACLE_ADD
    );

    IERC20Test public DAI = IERC20Test(
        DAI_ADDRESS
    );

    IERC20Test public USDT = IERC20Test(
        USDT_ADDRESS
    );

    IERC20Test public USDC = IERC20Test(
        USDC_ADDRESS
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