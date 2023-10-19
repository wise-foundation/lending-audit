
// SPDX-License-Identifier: -- WISE --

pragma solidity =0.8.21;

interface IWstETHTest {

    function wrap(
        uint256 _stETHAmount
    )
        external
        returns (uint256);

    function unwrap(
        uint256 _wstETHAmount
    )
        external
        returns (uint256);

    function getStETHByWstETH(
        uint256 _wstETHAmount
    )
        external
        view
        returns (uint256);
}