// SPDX-License-Identifier: -- WISE --

pragma solidity =0.8.21;


import "./sDaiFarm.sol";

contract sDaiFarmTester is SDaiFarm {

    constructor(
        address _wiseLendingAddress,
        uint256 _collateralFactor
    )
        SDaiFarm(
            _wiseLendingAddress,
            _collateralFactor
        )
    {}

    function setCollfactor(
        uint256 _newCollfactor
    )
        external
    {
        collateralFactor = _newCollfactor;
    }
}