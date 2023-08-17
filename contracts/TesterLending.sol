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
        address poolAddress,
        uint256 _value
    )
        external
    {
        borrowRatesData[poolAddress].pole = _value;
    }

    function setUtilisationTest(
        address poolAddress,
        uint256 _value
    )
        external
    {
        globalPoolData[poolAddress].utilization = _value;
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

    function getTimestampScaling(
        address _poolToken
    )
        external
        view
        returns (uint256)
    {
        return _getTimeStampScaling(
            _poolToken
        );
    }

    function syncSeveralPools(
        address[] memory _pools
    )
        external
    {
        for (uint i = 0; i < _pools.length; ++i) {
            _cleanUp(
                _pools[i]
            );

            _updatePseudoTotalAmounts(
                _pools[i]
            );

            _newBorrowRate(
                _pools[i]
            );
        }
    }
}
