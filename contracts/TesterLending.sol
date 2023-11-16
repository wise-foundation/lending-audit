// SPDX-License-Identifier: WISE

pragma solidity =0.8.21;

import "./WiseLending.sol";

contract TesterLending is WiseLending {

    constructor(
        address _master,
        address _wiseOracleHub,
        address _nftContract,
        address _wethContract
    )
        WiseLending(
            _master,
            _wiseOracleHub,
            _nftContract,
            _wethContract
        )
    {}

    function setPoleTest(
        address _poolAddress,
        uint256 _value
    )
        external
    {
        borrowRatesData[_poolAddress].pole = _value;
    }

    function setUtilisationTest(
        address _poolAddress,
        uint256 _value
    )
        external
    {
        globalPoolData[_poolAddress].utilization = _value;
    }

    function newBorrowRateTest(
        address _tokenAddress
    )
        external
    {
        _calculateNewBorrowRate(
            _tokenAddress
        );
    }

    function setPseudoTotalPoolTest(
        address _tokenAddress,
        uint256 _value
    )
        external
    {
        lendingPoolData[_tokenAddress].pseudoTotalPool = _value;
    }

    function setPseudoTotalBorrowAmountTest(
        address _tokenAddress,
        uint256 _value
    )
        external
    {
        borrowPoolData[_tokenAddress].pseudoTotalBorrowAmount = _value;
    }
}
