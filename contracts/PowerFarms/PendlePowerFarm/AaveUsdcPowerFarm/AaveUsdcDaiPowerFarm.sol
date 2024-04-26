// SPDX-License-Identifier: -- WISE --

pragma solidity =0.8.24;

/**
 * @author René Hochmuth
 * @author Christoph Krpoun
 * @author Vitally Marinchenko
 */

import "./CommonAaveUsdcPowerFarm.sol";

contract AaveUsdcDaiPowerFarm is CommonAaveUsdcPowerFarm {

    address public constant AAVE_DAI_ADDRESS = address(
        0x82E64f49Ed5EC1bC6e43DAD4FC8Af9bb3A2312EE
    );

    address public constant DAI_ADDRESS = address(
        0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1
    );

    constructor(
        address _wiseLendingAddress,
        address _pendleChildTokenAddress,
        address _pendleRouter,
        address _entryAsset,
        address _pendleSy,
        address _underlyingMarket,
        address _routerStatic,
        address _dexAddress,
        uint256 _collateralFactor,
        address _powerFarmNFTs
    )
        GenericPowerManager(
            _wiseLendingAddress,
            _pendleChildTokenAddress,
            _pendleRouter,
            _entryAsset,
            _pendleSy,
            _underlyingMarket,
            _routerStatic,
            _dexAddress,
            _collateralFactor,
            _powerFarmNFTs
        )
    {
        collateralFactorRole = msg.sender;

        POOL_ASSET_AAVE = AAVE_DAI_ADDRESS;
        FARM_ASSET = DAI_ADDRESS;

        _doApprovals(
            _wiseLendingAddress
        );
    }
}
