// SPDX-License-Identifier: -- WISE --

pragma solidity =0.8.21;

/**
 * @author Christoph Krpoun
 * @author René Hochmuth
 * @author Vitally Marinchenko
 */

/**
 * @dev Pricefeed contract for hybrid token. Takes price feed of underlying token
 * of the pendle farm and combines it with totalSupply and Sy amount inside power
 * farm.
 *
 * NOTE: Sometimes {phaseId} and {getRoundData} needs to be added for other
 * derivative oracles. Depending if underlying pendle farm token has its
 * own heartbeat or not. If self calibration needed see for example wstETH feed
 * contract at:
 * {https://etherscan.io/address/0xC42e9F1Aa22f78bC585e6911424c6B4936674e08#code}
 */

import "../InterfaceHub/IERC20.sol";
import "../InterfaceHub/IPriceFeed.sol";
import "../InterfaceHub/IPendlePowerFarms.sol";

contract HybdridTokenOracle {

    constructor(
        IERC20 _hybridToken,
        IPriceFeed _IPriceFeed,
        string memory description_,
        IPendlePowerFarms _pendlePowerFarm
    )
    {
        FEED = _IPriceFeed;

        HYBRID_TOKEN = _hybridToken;

        PENDLE_FARM = _pendlePowerFarm;

        _description = description_;
    }

    // ---- Interfaces ----

    IERC20 immutable public HYBRID_TOKEN;

    // Pricefeed for underyling power farm token in USD
    IPriceFeed immutable public FEED;

    // Interface of correspoding power farm for hybrid token
    IPendlePowerFarms immutable public PENDLE_FARM;

    // Description of price feed
    string private _description;

    // Price feed decimals
    uint8 constant _decimals = 8;

    function description()
        external
        view
        returns (string memory)
    {
        return _description;
    }

    /**
     * @dev Read function returning latest USD value for hybrid token.
     * Uses answer from underlying token pricefeed and combines it with
     * the {totalSupply} amount of the power farms hybdrid token plus
     * {totalSyAmount} inside the contract.
     */
    function latestAnswer()
        public
        view
        returns (uint256)
    {
        uint256 totalSupply = HYBRID_TOKEN.totalSupply();

        if (totalSupply == 0) {
            return 0;
        }

        (
            ,
            int256 answer,
            ,
            ,
        ) = FEED.latestRoundData();

        return uint256(answer)
            * PENDLE_FARM.oracleSyAmount()
            / totalSupply;
    }

    /**
     * @dev Returns priceFeed decimals.
     */
    function decimals()
        external
        pure
        returns (uint8)
    {
        return _decimals;
    }

    /**
     * @dev Read function mimicking the latest round data
     * for our hybrid token price feed.
     * Needed for latest {latestResolver} implementation
     * of the oracleHub (Former implementation used
     * {latestAnswer}).
     */
    function latestRoundData()
        public
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
