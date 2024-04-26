// SPDX-License-Identifier: -- WISE --

pragma solidity =0.8.24;

/**
 * @author René Hochmuth
 * @author Christoph Krpoun
 * @author Vitally Marinchenko
 */

import "./CommonAaveUsdcPowerFarm.sol";

contract AaveUsdcUsdtPowerFarm is CommonAaveUsdcPowerFarm {

    address public constant AAVE_USDT_ADDRESS = address(
        0x6ab707Aca953eDAeFBc4fD23bA73294241490620
    );

    address public constant USDT_ADDRESS = address(
        0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9
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

        POOL_ASSET_AAVE = AAVE_USDT_ADDRESS;
        FARM_ASSET = USDT_ADDRESS;

        _doApprovals(
            _wiseLendingAddress
        );
    }
}
