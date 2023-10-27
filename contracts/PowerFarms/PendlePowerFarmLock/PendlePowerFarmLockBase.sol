// SPDX-License-Identifier: -- WISE --

pragma solidity =0.8.21;

import "../../OwnableMaster.sol";
import "../../TransferHub/TransferHelper.sol";
import "../../TransferHub/ApprovalHelper.sol";

import "../../InterfaceHub/IERC20.sol";
import "../../InterfaceHub/IPendle.sol";
import "../../InterfaceHub/IPendlePowerFarms.sol";

error SwapFailed();
error NotAllowed();
error AlreadySet();
error NotExpired();
error NotEnoughLocked();
error LockTimeTooShort();
error SwapChecksFailed();

contract PendlePowerFarmLockBase is
    TransferHelper,
    ApprovalHelper,
    OwnableMaster
{
    address constant VE_PENDLE_CONTRACT = 0x4f30A9D41B80ecC5B94306AB4364951AE3170210;
    address constant PENDLE_TOKEN = 0x808507121B80c02388fAd14726482e061B8da827;
    address constant PENDLE_ROUTER_ADDRESS = 0x0000000001E4ef00d069e71d6bA041b0A16F7eA0;

    mapping(address => bool) public allowedCaller;
    mapping(address => bool) public registerdPendleFarm;

    mapping(address => uint256) public balanceLP;
    mapping(address => uint256) public balanceYT;

    mapping(address => address[]) public farmRewardTokensYt;
    mapping(address => address[]) public farmRewardTokensMarket;

    mapping(address => IPendleSy) public SY_FARM;
    mapping(address => IPendleYt) public YT_FARM;
    mapping(address => IPendleMarket) public LP_FARM;
    mapping(address => IPendlePowerFarms) public POWER_FARM;

    address[] public pendlePowerFarms;

    uint128 constant WEEK = 7 days;

    IPendleLock immutable public PENDLE_LOCK;

    bytes4 constant SELECTOR_MINT_SY_FROM_TOKEN = 0x443e6512;

    struct SwapData {
        SwapType swapType;
        address extRouter;
        bytes extCalldata;
        bool needScale;
    }

    enum SwapType {
        NONE,
        KYBERSWAP,
        ONE_INCH,
        // ETH_WETH not used in Aggregator
        ETH_WETH
    }

    struct TokenInput {
        // Token/Sy data
        address tokenIn;
        uint256 netTokenIn;
        address tokenMintSy;
        address bulk;
        // aggregator data
        address pendleSwap;
        SwapData swapData;
    }

    constructor()
        OwnableMaster(
            msg.sender
        )
    {
        PENDLE_LOCK = IPendleLock(
            VE_PENDLE_CONTRACT
        );
    }

    modifier onlyAllowedPF() {
        _onlyAllowedPF();
        _;
    }

    function _onlyAllowedPF()
        private
        view
    {
        if (registerdPendleFarm[msg.sender] == false) {
            revert NotAllowed();
        }
    }
}
