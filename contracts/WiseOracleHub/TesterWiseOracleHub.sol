// SPDX-License-Identifier: -- WISE --

pragma solidity =0.8.24;

import "@ironblocks/firewall-consumer/contracts/FirewallConsumer.sol";
import "./WiseOracleHub.sol";

contract TesterWiseOracleHub is FirewallConsumer, WiseOracleHub {

    constructor(
        address _wethAddrss,
        address _ethPricingFeed,
        address _uniswapFactoryV3
    )
        WiseOracleHub(
            _wethAddrss,
            _ethPricingFeed,
            _uniswapFactoryV3
        )
    {
    }

    function setHeartBeatBulk(
        address[] memory _tokenAddresses,
        uint256[] memory _values
    )
        external firewallProtected
    {
        uint256 i;
        uint256 l = _tokenAddresses.length;

        while (i < l) {
            setHeartBeat(
                _tokenAddresses[i],
                _values[i]
            );

            unchecked {
                ++i;
            }
        }
    }

    function setHeartBeat(
        address _tokenAddress,
        uint256 _value
    )
        public
    {
        heartBeat[_tokenAddress] = _value;
    }

    function setAllowedDifference(
        uint256 _value
    )
        public
    {
        ALLOWED_DIFFERENCE = _value;
    }
}
