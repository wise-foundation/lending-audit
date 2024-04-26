// SPDX-License-Identifier: -- WISE --

pragma solidity =0.8.24;

/**
 * @author René Hochmuth
 */

/**
 * @dev PriceFeed contract for Lp-Token with USD
 * chainLink feed to get a feed measured in ETH.
 * Takes chainLink oracle value and multiplies it
 * with the corresponding TWAP and other chainLink oracles.
 */

import "../InterfaceHub/IPendle.sol";
import "../InterfaceHub/IPriceFeed.sol";
import "../InterfaceHub/IOraclePendle.sol";
import "../InterfaceHub/IWiseOracleHub.sol";
import {
    PendleLpOracleLib,
    IPMarket
} from "@pendle/core-v2/contracts/oracles/PendleLpOracleLib.sol";

error CardinalityNotSatisfied();
error OldestObservationNotSatisfied();
error InvalidDecimals();

contract PendleLpOracle {

    address internal constant ZERO_ADDRESS = address(0);
    uint256 internal constant DEFAULT_DECIMALS = 18;

    constructor(
        address _pendleMarketAddress,
        address _wiseOracleHub,
        address _twapCheckAsset,
        IPriceFeed _priceFeedChainLinkEth,
        IOraclePendle _oraclePendlePt,
        string memory _oracleName,
        uint32 _twapDuration
    )
    {
        PENDLE_MARKET_ADDRESS = _pendleMarketAddress;

        FEED_ASSET = _priceFeedChainLinkEth;

        if (FEED_ASSET.decimals() != DEFAULT_DECIMALS) {
            revert InvalidDecimals();
        }

        TWAP_DURATION = _twapDuration;
        ORACLE_PENDLE_PT = _oraclePendlePt;

        PENDLE_MARKET = IPendleMarket(
            _pendleMarketAddress
        );

        name = _oracleName;

        WISE_ORACLE = IWiseOracleHub(
            _wiseOracleHub
        );

        TWAP_CHECK_ASSET = _twapCheckAsset;

        (
            address _pendleSy,,
        ) = PENDLE_MARKET.readTokens();

        PENDLE_SY = IPendleSy(
            _pendleSy
        );
    }

    address public immutable PENDLE_MARKET_ADDRESS;
    IPendleMarket public immutable PENDLE_MARKET;

    // Pricefeed for asset in ETH and TWAP for PtToken.
    IPendleSy public immutable PENDLE_SY;
    IPriceFeed public immutable FEED_ASSET;
    IOraclePendle public immutable ORACLE_PENDLE_PT;
    IWiseOracleHub public immutable WISE_ORACLE;

    uint8 internal constant FEED_DECIMALS = 18;
    // -- Precision factor for computations --
    uint256 internal constant PRECISION_FACTOR_E18 = 1E18;

    // -- Twap duration in seconds --
    uint32 public immutable TWAP_DURATION;

    // - Constant numbers
    uint256 internal constant EXCHANGE_RATE_MULTIPLIER = 99;
    uint256 internal constant EXCHANGE_RATE_DENOMINATOR = 100;

    // -- Farm description --
    string public name;

    // -- Check Twap Asset
    address public immutable TWAP_CHECK_ASSET;

    function getDiscountValue()
        public
        view
        returns (uint256)
    {
        return WISE_ORACLE.latestResolverTwap(
            TWAP_CHECK_ASSET
        );
    }

    function getReportedExchangeRate()
        public
        view
        returns (uint256)
    {
        return PENDLE_SY.exchangeRate();
    }

    /**
     * @dev Read function returning latest ETH value for PtToken.
     * Uses answer from USD chainLink pricefeed and combines it with
     * the result from ethInUsd for one token of PtToken.
     */
    function latestAnswer()
        public
        view
        returns (uint256)
    {
        (
            ,
            int256 answerFeed,
            ,
            ,
        ) = FEED_ASSET.latestRoundData();

        (
            bool increaseCardinalityRequired,
            ,
            bool oldestObservationSatisfied
        ) = ORACLE_PENDLE_PT.getOracleState(
            PENDLE_MARKET_ADDRESS,
            TWAP_DURATION
        );

        if (increaseCardinalityRequired == true) {
            revert CardinalityNotSatisfied();
        }

        if (oldestObservationSatisfied == false) {
            revert OldestObservationNotSatisfied();
        }

        uint256 lpRate = _getLpToAssetRateWrapper(
            IPMarket(PENDLE_MARKET_ADDRESS),
            TWAP_DURATION
        );

        uint256 discountValue = PRECISION_FACTOR_E18;
        uint256 exchangeRateValue = PRECISION_FACTOR_E18;

        if (TWAP_CHECK_ASSET > ZERO_ADDRESS) {
            discountValue = getDiscountValue();
            exchangeRateValue = getReportedExchangeRate();
        }

        uint256 lpValueNormal = lpRate
            * uint256(answerFeed)
            / PRECISION_FACTOR_E18;

        if (discountValue > exchangeRateValue) {
            return lpValueNormal;
        }

        uint256 scaledexchangeRate = exchangeRateValue
            * EXCHANGE_RATE_MULTIPLIER
            / EXCHANGE_RATE_DENOMINATOR;

        if (discountValue < scaledexchangeRate) {
            return lpValueNormal
                * EXCHANGE_RATE_MULTIPLIER
                / EXCHANGE_RATE_DENOMINATOR;
        }

        return lpRate
            * uint256(answerFeed)
            / PRECISION_FACTOR_E18
            * discountValue
            / exchangeRateValue;
    }

    function _getLpToAssetRateWrapper(
        IPMarket _market,
        uint32 _duration
    )
        internal
        view
        returns (uint256)
    {
        return PendleLpOracleLib.getLpToAssetRate(
            _market,
            _duration
        );
    }

    /**
     * @dev Returns priceFeed decimals.
     */
    function decimals()
        external
        pure
        returns (uint8)
    {
        return FEED_DECIMALS;
    }

    /**
     * @dev Read function returning the latest answer
     * so wise oracle hub can fetch it
     */
    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return (
            roundId,
            int256(latestAnswer()),
            startedAt,
            updatedAt,
            answeredInRound
        );
    }
}
