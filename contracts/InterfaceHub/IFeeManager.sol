// SPDX-License-Identifier: -- WISE --

pragma solidity =0.8.21;

interface IFeeManager {

    function setBadDebtUserLiquidation(
        uint256 _nftId,
        uint256 _amount
    )
        external;

    function increaseTotalBadDebtLiquidation(
        uint256 _amount
    )
        external;

    function FEE_MASTER_NFT_ID()
        external
        returns (uint256);

    function addPoolTokenAddress(
        address _poolToken
    )
        external;

    function getPoolTokenAdressesByIndex(
        uint256 _index
    )
        external
        view
        returns (address);

    function getPoolTokenAddressesLength()
        external
        view
        returns (uint256);
}