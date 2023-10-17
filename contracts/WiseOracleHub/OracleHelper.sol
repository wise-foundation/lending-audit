// SPDX-License-Identifier: -- WISE --

pragma solidity =0.8.21;

import "./Declarations.sol";

abstract contract OracleHelper is Declarations {

    /**
     * @dev Adds priceFeed for a given token.
     */
    function _addOracle(
        address _tokenAddress,
        IPriceFeed _priceFeedAddress,
        address[] calldata _underlyingFeedTokens
    )
        internal
    {
        if (priceFeed[_tokenAddress] > ZERO_FEED) {
            revert OracleAlreadySet();
        }

        priceFeed[_tokenAddress] = _priceFeedAddress;

        _tokenDecimals[_tokenAddress] = IERC20(
            _tokenAddress
        ).decimals();

        underlyingFeedTokens[_tokenAddress] = _underlyingFeedTokens;
    }

    /**
     * @dev Stores expected heartbeat
     * value for a pricing feed token.
     */
    function _recalibrate(
        address _tokenAddress
    )
        internal
    {
        heartBeat[_tokenAddress] = _recalibratePreview(
            _tokenAddress
        );
    }

    /**
     * @dev Check if chainLink feed was
     * updated within expected timeFrame
     * for single {_tokenAddress}.
     */
    function _chainLinkIsDead(
        address _tokenAddress
    )
        internal
        view
        returns (bool)
    {
        uint80 latestRoundId = getLatestRoundId(
            _tokenAddress
        );

        uint256 upd = _getRoundTimestamp(
            _tokenAddress,
            latestRoundId
        );

        unchecked {
            upd = block.timestamp < upd
                ? block.timestamp
                : block.timestamp - upd;

            return upd > heartBeat[_tokenAddress];
        }
    }

    /**
     * @dev Recalibrates expected
     * heartbeat for a pricing feed.
     */
    function _recalibratePreview(
        address _tokenAddress
    )
        internal
        view
        returns (uint256)
    {
        uint80 latestRoundId = getLatestRoundId(
            _tokenAddress
        );

        uint256 latestTimestamp = _getRoundTimestamp(
            _tokenAddress,
            latestRoundId
        );

        uint80 iterationCount = _getIterationCount(
            latestRoundId
        );

        if (iterationCount < 3) {
            revert SampleTooSmall(
                {
                    size: iterationCount
                }
            );
        }

        uint256 currentDiff;
        uint256 currentBiggest;
        uint256 currentSecondBiggest;

        for (uint80 i = 1; i < iterationCount;) {

            uint256 currentTimestamp = _getRoundTimestamp(
                _tokenAddress,
                latestRoundId - i
            );

            currentDiff = latestTimestamp
                - currentTimestamp;

            latestTimestamp = currentTimestamp;

            if (currentDiff >= currentBiggest) {

                currentSecondBiggest = currentBiggest;
                currentBiggest = currentDiff;

            } else if (currentDiff > currentSecondBiggest) {
                currentSecondBiggest = currentDiff;
            }

            unchecked {
                ++i;
            }
        }

        return currentSecondBiggest;
    }

    /**
     * @dev Determines number of iterations
     * needed during heartbeat recalibration.
     */
    function _getIterationCount(
        uint80 _latestAggregatorRoundId
    )
        internal
        pure
        returns (uint80 res)
    {
        res = _latestAggregatorRoundId < MAX_ROUND_COUNT
            ? _latestAggregatorRoundId
            : MAX_ROUND_COUNT;
    }

    /**
     * @dev Fetches timestamp of a byteshifted
     * aggregatorRound with specific _roundId.
     */
    function _getRoundTimestamp(
        address _tokenAddress,
        uint80 _roundId
    )
        internal
        view
        returns (uint256)
    {
        (
            ,
            ,
            ,
            uint256 timestamp
            ,
        ) = priceFeed[_tokenAddress].getRoundData(
                _roundId
            );

        return timestamp;
    }

    /**
     * @dev Routing latest round data from chainLink.
     * Returns latestRoundData by passing underlying token address.
     */
    function getLatestRoundId(
        address _tokenAddress
    )
        public
        view
        returns (
            uint80 roundId
        )
    {
        (
            roundId
            ,
            ,
            ,
            ,
        ) = priceFeed[_tokenAddress].latestRoundData();
    }
}