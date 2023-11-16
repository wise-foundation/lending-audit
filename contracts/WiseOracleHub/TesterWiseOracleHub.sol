// SPDX-License-Identifier: -- WISE --

pragma solidity =0.8.21;

import "./WiseOracleHub.sol";

contract TesterWiseOracleHub is WiseOracleHub {

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
        external
    {
        for (uint256 i = 0; i < _tokenAddresses.length; ++i) {
            setHeartBeat(
                _tokenAddresses[i],
                _values[i]
            );
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
