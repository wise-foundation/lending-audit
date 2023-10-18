// SPDX-License-Identifier: -- WISE --

pragma solidity =0.8.21;

interface IPowerFarmGlobals {

    function totalSyAmount()
        external
        view
        returns (uint256);

    function totalSupply()
        external
        view
        returns (uint256);
}