// SPDX-License-Identifier: -- WISE --

pragma solidity =0.8.21;


import "./sDaiFarmManager.sol";

contract sDaiFarmTester is sDaiFarmManager {

    constructor(
        address _wiseLendingAddress,
        uint256 _collateralFactor,
        address _powerFarmNFTs
    )
        sDaiFarmManager(
            _wiseLendingAddress,
            _collateralFactor,
            _powerFarmNFTs
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