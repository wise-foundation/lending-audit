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
        address[] memory _underlyingFeedTokens
    )
        internal
    {
        if (priceFeed[_tokenAddress] == ZERO_FEED) {
            priceFeed[_tokenAddress] = _priceFeedAddress;

            _tokenDecimals[_tokenAddress] = IERC20(
                _tokenAddress
            ).decimals();

            underlyingFeedTokens[_tokenAddress] = _underlyingFeedTokens;

            return;
        }

        revert OracleAlreadySet(
            {
                feed: priceFeed[_tokenAddress]
            }
        );
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
        uint256 upd = latestRoundData(
            _tokenAddress
        );

        unchecked {
            upd = block.timestamp > upd
                ? block.timestamp - upd
                : block.timestamp;

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
        uint80 latestAggregatorRoundId = _getLatestAggregatorRoundId(
            _tokenAddress
        );

        uint80 iterationCount = _getIterationCount(
            latestAggregatorRoundId
        );

        if (iterationCount < 2) {
            revert SampleTooSmall(
                {
                    size: iterationCount
                }
            );
        }

        uint16 phaseId = _getPhaseId(
            _tokenAddress
        );

        uint256 latestTimestamp = _getRoundTimestamp(
            _tokenAddress,
            phaseId,
            latestAggregatorRoundId
        );

        uint256 currentDiff;
        uint256 currentBiggest;
        uint256 currentSecondBiggest;

        for (uint80 i = 1; i < iterationCount;) {

            uint256 currentTimestamp = _getRoundTimestamp(
                _tokenAddress,
                phaseId,
                latestAggregatorRoundId - i
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
     * aggregatorRound with specific phaseId.
     */
    function _getRoundTimestamp(
        address _tokenAddress,
        uint16 _phaseId,
        uint80 _aggregatorRoundId
    )
        internal
        view
        returns (uint256)
    {
        (
            ,
            ,
            ,
            uint256 timestamp,
        ) = priceFeed[_tokenAddress].getRoundData(
                getRoundIdByByteShift(
                    _phaseId,
                    _aggregatorRoundId
                )
            );

        return timestamp;
    }

    /**
     * @dev Determines info for the heartbeat update
     * mechanism for chainlink oracles, roundIds.
     */
    function _getLatestAggregatorRoundId(
        address _tokenAddress
    )
        internal
        view
        returns (uint80)
    {
        (   uint80 roundId,
            ,
            ,
            ,
        ) = priceFeed[_tokenAddress].latestRoundData();

        return roundId;
    }

    /**
     * @dev Determines info for the heartbeat update
     * mechanism for chainlink oracles, shifted roundIds.
     */
    function getRoundIdByByteShift(
        uint16 _phaseId,
        uint80 _aggregatorRoundId
    )
        public
        pure
        returns (uint80)
    {
        return uint80(
            (uint256(_phaseId) << 64) | _aggregatorRoundId
        );
    }

    /**
     * @dev Routing phaseId from chainLink.
     * Returns phaseId by passing underlying token address.
     */
    function _getPhaseId(
        address _tokenAddress
    )
        internal
        view
        returns (uint16)
    {
        return priceFeed[_tokenAddress].phaseId();
    }

    /**
     * @dev Routing latest round data from chainLink.
     * Returns latestRoundData by passing underlying token address.
     */
    function latestRoundData(
        address _tokenAddress
    )
        public
        view
        returns (uint256 upd)
    {
        (   ,
            ,
            ,
            upd
            ,
        ) = priceFeed[_tokenAddress].latestRoundData();
    }
}