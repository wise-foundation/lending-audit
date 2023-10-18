// SPDX-License-Identifier: -- WISE --

pragma solidity =0.8.21;

interface IStETHTest {

    function submit(
        address _referral
    )
        external
        payable
        returns (uint256);

    function getPooledEthByShares(
        uint256 _sharesAmount
    )
    external
    view
    returns (uint256);

}