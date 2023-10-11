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
        uint256 i;
        uint256 l = _tokenAddresses.length;

        for (i; i < l;) {
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
}
