// SPDX-License-Identifier: -- WISE --

pragma solidity =0.8.21;

import "../InterfaceHub/IERC20.sol";
import "../InterfaceHub/IPriceFeed.sol";

error SampleTooSmall(
    uint256 size
);

error OracleAlreadySet(
    IPriceFeed feed
);

contract Declarations {

    // -- Constant values --

    // Target Decimals of the returned USD values.
    uint8 constant _decimalsUSD = 18;

    // Number of last rounds which are checked for heartbeat.
    uint80 constant MAX_ROUND_COUNT = 50;

    // Value address used for empty feed comparison.
    IPriceFeed constant ZERO_FEED = IPriceFeed(
        address(0x0)
    );

    // -- Mapping values --

    // Stores decimals of specific ERC20 token.
    mapping(address => uint8) _tokenDecimals;

    // Stores the price feed address from oracle sources.
    mapping(address => IPriceFeed) public priceFeed;

    // Stores the time between chainLink heartbeats.
    mapping(address => uint256) public heartBeat;

    // Mapping underlying feed token for multi token derivate oracle
    mapping(address => address[]) public underlyingFeedTokens;
}