// SPDX-License-Identifier: -- WISE --

pragma solidity =0.8.21;

import "../InterfaceHub/IERC20.sol";
import "../InterfaceHub/IPriceFeed.sol";

import "./Libraries/IUniswapV3Factory.sol";
import "./Libraries/OracleLibrary.sol";

import "../OwnableMaster.sol";

error OracleIsDead();
error OracleAlreadySet();
error SampleTooSmall(
    uint256 size
);
error HeartBeatNotSet();
error ZeroAddressNotAllowed();
error TwapOracleAlreadySet();
error PoolAddressMismatch();
error PoolDoesNotExist();
error OraclesDeviate();
error ChainLinkOracleNotSet();
error TokenAddressMismatch();

abstract contract Declarations is OwnableMaster {

    struct UniTwapPoolInfo {
        address oracle;
        bool isUniPool;
    }

    struct DerivativePartnerInfo{
        address partnerTokenAddress;
        address partnerOracleAddress;
    }

    constructor(
        address _wethAddress,
        address _ethPriceFeed,
        address _uniswapV3Factory
    )
        OwnableMaster(
            msg.sender
        )
    {
        WETH_ADDRESS = _wethAddress;

        _decimalsWETH = IERC20(
            WETH_ADDRESS
        ).decimals();

        ETH_PRICE_FEED = IPriceFeed(
            _ethPriceFeed
        );

        UNI_V3_FACTORY = IUniswapV3Factory(
            _uniswapV3Factory
        );
    }

    // address of WETH token on Mainnet
    address public immutable WETH_ADDRESS;

    // Target Decimals of the returned WETH values.
    uint8 internal immutable _decimalsWETH;

    // ChainLink ETH price feed ETH to USD value.
    IPriceFeed public immutable ETH_PRICE_FEED;

    // Uniswap Factory interface
    IUniswapV3Factory public immutable UNI_V3_FACTORY;

    // Target Decimals of the returned USD values.
    uint8 internal constant _decimalsUSD = 8;

    // Target Decimals of the returned ETH values.
    uint8 internal constant _decimalsETH = 18;

    // Number of last rounds which are checked for heartbeat.
    uint80 internal constant MAX_ROUND_COUNT = 50;

    // Define the number of seconds in a minute.
    uint32 internal constant SECONDS_IN_MINUTE = 60;

    // Define TWAP period in seconds.
    uint32 internal constant TWAP_PERIOD = 30 * SECONDS_IN_MINUTE;

    // Precision factor for ETH values.
    uint256 internal constant PRECISION_FACTOR_E4 = 1E4;

    // Allowed difference between oracle values.
    uint256 internal ALLOWED_DIFFERENCE = 10250;

    // Value address used for empty feed comparison.
    IPriceFeed internal constant ZERO_FEED = IPriceFeed(
        address(0x0)
    );

    // -- Mapping values --

    // Stores decimals of specific ERC20 token.
    mapping(address => uint8) _tokenDecimals;

    // Stores the price feed address from oracle sources.
    mapping(address => IPriceFeed) public priceFeed;

    // Stores the time between chainLink heartbeats.
    mapping(address => uint256) public heartBeat;

    // Mapping underlying feed token for multi token derivate oracle.
    mapping(address => address[]) public underlyingFeedTokens;

    // Stores the uniswap twap pool or derivative info.
    mapping(address => UniTwapPoolInfo) public uniTwapPoolInfo;

    // Stores the derivative partner address of the TWAP.
    mapping(address => DerivativePartnerInfo) public derivativePartnerTwap;
}
