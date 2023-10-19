
// SPDX-License-Identifier: -- WISE --

pragma solidity =0.8.21;

interface IWiseSecurityTest {

    function getPositionLendingAmount(
        uint256 _nftId,
        address _poolToken
    )
        external
        view
        returns (uint256);

    function getBorrowRate(
        address _poolToken
    )
        external
        view
        returns (uint256);
}