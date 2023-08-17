// SPDX-License-Identifier: WISE

pragma solidity =0.8.21;

import "./WiseOracleHub.sol";

contract TesterWiseOracleHub is WiseOracleHub {

    constructor() WiseOracleHub() {}

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
}
