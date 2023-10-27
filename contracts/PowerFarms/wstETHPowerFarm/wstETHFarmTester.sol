// SPDX-License-Identifier: -- WISE --

pragma solidity =0.8.21;

import "./wstETHManager.sol";

contract wstETHFarmTester is wstETHManager {

    constructor(
        address _wiseLendingAddress,
        uint256 _collateralFactor,
        address _powerFarmNFTs
    )
        wstETHManager(
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