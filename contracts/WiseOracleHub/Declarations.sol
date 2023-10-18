// SPDX-License-Identifier: -- WISE --

pragma solidity =0.8.21;

import "../InterfaceHub/IERC20.sol";
import "../InterfaceHub/IPriceFeed.sol";

error OracleIsDead();
error OracleAlreadySet();
error SampleTooSmall(
    uint256 size
);

contract Declarations {

    // -- Constant values --

    // Target Decimals of the returned USD values.
    uint8 internal constant _decimalsUSD = 18;

    // Number of last rounds which are checked for heartbeat.
    uint80 internal  constant MAX_ROUND_COUNT = 50;

    // Value address used for empty feed comparison.
    IPriceFeed internal constant ZERO_FEED = IPriceFeed(
        address(0x0)
    );

    // -- Mapping values --

    // Stores decimals of specific ERC20 token.
    mapping(address => uint8) internal _tokenDecimals;

    // Stores the price feed address from oracle sources.
    mapping(address => IPriceFeed) public priceFeed;

    // Stores the time between chainLink heartbeats.
    mapping(address => uint256) public heartBeat;

    // Mapping underlying feed token for multi token derivate oracle
    mapping(address => address[]) public underlyingFeedTokens;
}