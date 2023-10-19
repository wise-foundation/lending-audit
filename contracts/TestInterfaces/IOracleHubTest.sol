// SPDX-License-Identifier: -- WISE --

pragma solidity =0.8.21;

interface IOracleHubTest {

    function getTokensFromUSD(
        address _tokenAddress,
        uint256 _usdValue
    )
        external
        view
        returns (uint256);

    function getTokensInUSD(
        address _tokenAddress,
        uint256 _amount
    )
        external
        view
        returns (uint256);

    function latestResolver(
        address _tokenAddress
    )
        external
        view
        returns (uint256);

}