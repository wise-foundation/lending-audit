// SPDX-License-Identifier: -- WISE --

pragma solidity =0.8.21;

contract USDEquivalent {

    int256 returnValue;
    uint8 dec;
    address public tokenAddress;

    constructor(
        int256 _defaultValue,
        uint8 _decimals,
        address _tokenAddress
    ) {
        returnValue = _defaultValue;
        dec = _decimals;
        tokenAddress = _tokenAddress;
    }

    function setValue(
        int256 _newValue
    )
        external
    {
        returnValue = _newValue;
    }

    //make sure to change value with this when you change decimals to scale it to what it should be
    function setDecimals(
        uint8 _newDecimals
    )
        external
    {
        dec = _newDecimals;
    }

    function latestAnswer()
        external
        view
        returns (int256)
    {
        return returnValue;
    }

    function decimals()
        external
        view
        returns (uint8)
    {
        return dec;
    }
}
