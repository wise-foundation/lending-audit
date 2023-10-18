// SPDX-License-Identifier: -- WISE --

pragma solidity =0.8.21;

import "./wstETHManager.sol";

contract wstETHFarmTester is wstETHManager {

    constructor(
        address _wiseLendingAddress,
        uint256 _collateralFactor
    )
        wstETHManager(
            "keyNFT",
            "keyNFT",
            "meta-path",
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