// SPDX-License-Identifier: -- WISE --

pragma solidity =0.8.21;

/**
 * @author Christoph Krpoun
 * @author René Hochmuth
 * @author Vitally Marinchenko
 */

import "./OracleHelper.sol";
import "../OwnableMaster.sol";

/**
 * @dev WiseOracleHub is an onchain extension for price feeds (chainLink or others).
 * The master address is owned by a timelock contract which itself is secured by a
 * multisig. Only the master can add new price feed <-> address pairs to the contract.
 *
 * One advantage is the linking of price feeds to their underlying token address.
 * Therefore, users can get the current USD value of a token by just knowing the token
 * address when calling {latestResolver}. It takes the answer from {latestRoundData}
 * for chainLink oracles as recommended from chainLink.
 *
 * NOTE: If you want to propose adding an own developed price feed it is
 * mandatory to wrap its answer into a function mimicking {latestRoundData}
 * (See {latestResolver} implementation).
 *
 * Additionally, the oracleHub provides so called heartbeat checks if a token gets
 * still updated in expected time intervall.
 *
 */

contract WiseOracleHub is OracleHelper, OwnableMaster {

    constructor()
        Declarations()
        OwnableMaster(msg.sender)
    {}

    /**
     * @dev Returns USD values decimals
     * meaning that 1.00 USD <=> 1E18.
     */
    function decimalsUSD()
        external
        pure
        returns (uint8)
    {
        return _decimalsUSD;
    }

    /**
     * @dev Returns priceFeed latest USD value
     * by passing the underlying token address.
     */
    function latestResolver(
        address _tokenAddress
    )
        public
        view
        returns (uint256)
    {
        (
                ,
                int256 answer,
                ,
                ,

            ) = priceFeed[_tokenAddress].latestRoundData();

        return uint256(answer);
    }

    /**
     * @dev Returns priceFeed decimals by
     * passing the underlying token address.
     */
    function decimals(
        address _tokenAddress
    )
        public
        view
        returns (uint8)
    {
        return priceFeed[_tokenAddress].decimals();
    }

    function getTokenDecimals(
        address _tokenAddress
    )
        external
        view
        returns (uint8)
    {
        return _tokenDecimals[_tokenAddress];
    }

    /**
     * @dev Returns USD value of a given token
     * amount in order of 1E18 decimal precision.
     */
    function getTokensInUSD(
        address _tokenAddress,
        uint256 _amount
    )
        external
        view
        returns (uint256)
    {
        uint8 tokenDecimals = _tokenDecimals[
            _tokenAddress
        ];

        return _decimalsUSD < tokenDecimals
            ? _amount
                * latestResolver(_tokenAddress)
                / 10 ** decimals(_tokenAddress)
                / 10 ** (tokenDecimals - _decimalsUSD)
            : _amount
                * 10 ** (_decimalsUSD - tokenDecimals)
                * latestResolver(_tokenAddress)
                / 10 ** decimals(_tokenAddress);
    }

    /**
     * @dev Converts USD value of a token into token amount with a
     * current price. The order of the argument _usdValue is 1E18.
     */
    function getTokensFromUSD(
        address _tokenAddress,
        uint256 _usdValue
    )
        external
        view
        returns (uint256)
    {
        uint8 tokenDecimals = _tokenDecimals[
            _tokenAddress
        ];

        return _decimalsUSD < tokenDecimals
            ? _usdValue
                * 10 ** (tokenDecimals - _decimalsUSD)
                * 10 ** decimals(_tokenAddress)
                / latestResolver(_tokenAddress)
            : _usdValue
                * 10 ** decimals(_tokenAddress)
                / latestResolver(_tokenAddress)
                / 10 ** (_decimalsUSD - tokenDecimals);
    }

    /**
     * @dev Adds priceFeed for a token.
     * Can't overwrite existing mappings.
     * Master is a timelock contract.
     */
    function addOracle(
        address _tokenAddress,
        IPriceFeed _priceFeedAddress,
        address[] memory _underlyingFeedTokens
    )
        external
        onlyMaster
    {
        _addOracle(
            _tokenAddress,
            _priceFeedAddress,
            _underlyingFeedTokens
        );
    }

    /**
     * @dev Adds priceFeeds for tokens.
     * Can't overwrite existing mappings.
     * Master is a timelock contract.
     */
    function addOracleBulk(
        address[] memory _tokenAddresses,
        IPriceFeed[] memory _priceFeedAddresses,
        address[][] memory _underlyingFeedTokens
    )
        external
        onlyMaster
    {
        for (uint8 i = 0; i < _tokenAddresses.length; ++i) {
            _addOracle(
                _tokenAddresses[i],
                _priceFeedAddresses[i],
                _underlyingFeedTokens[i]
            );
        }
    }

    /**
     * @dev Looks at the maximal last 50 rounds and
     * takes second highest value to avoid counting
     * offline time of chainlink as valid heartbeat.
     */
    function recalibratePreview(
        address _tokenAddress
    )
        external
        view
        returns (uint256)
    {
        return _recalibratePreview(
            _tokenAddress
        );
    }

    /**
     * @dev Check if chainLink feed was
     * updated within expected timeFrame.
     * If length of {underlyingFeedTokens}
     * is greater than zero it checks the
     * heartbeat of all base feeds of the
     * derivate oracle.
     */
    function chainLinkIsDead(
        address _tokenAddress
    )
        external
        view
        returns (bool state)
    {
        uint256 length = underlyingFeedTokens[_tokenAddress].length;

        if (length == 0) {
            return _chainLinkIsDead(
                _tokenAddress
            );
        }

        for (uint256 i = 0; i < length; ++i) {

            state = _chainLinkIsDead(
                underlyingFeedTokens[_tokenAddress][i]
            );

            if (state == true) {
                break;
            }
        }

        return state;
    }

    /**
     * @dev Recalibrates expected
     * heartbeat for a pricing feed.
     */
    function recalibrate(
        address _tokenAddress
    )
        external
    {
        _recalibrate(
            _tokenAddress
        );
    }

    /**
     * @dev Bulk function to recalibrate
     * the heartbeat for several tokens.
     */
    function recalibrateBulk(
        address[] memory _tokenAddresses
    )
        external
    {
        for (uint256 i = 0; i < _tokenAddresses.length; ++i) {
            _recalibrate(
                _tokenAddresses[i]
            );
        }
    }
}
