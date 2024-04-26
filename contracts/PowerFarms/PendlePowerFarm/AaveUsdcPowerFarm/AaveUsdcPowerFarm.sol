// SPDX-License-Identifier: -- WISE --

pragma solidity =0.8.24;

/**
 * @author René Hochmuth
 * @author Christoph Krpoun
 * @author Vitally Marinchenko
 */

import "./CommonAaveUsdcPowerFarm.sol";

contract AaveUsdcPowerFarm is CommonAaveUsdcPowerFarm {

    address public constant AAVE_USDC_ADDRESS = address (
        0x724dc807b04555b71ed48a6896b6F41593b8C637
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

        POOL_ASSET_AAVE = AAVE_USDC_ADDRESS;
        FARM_ASSET = NATIVE_USDC_ARBITRUM_ADDRESS;

        _doApprovals(
            _wiseLendingAddress
        );
    }

    function _doApprovals(
        address _wiseLendingAddress
    )
        internal
        override
    {
        _executeCommonApprovals(
            _wiseLendingAddress
        );

        _safeApprove(
            POOL_ASSET_AAVE,
            _wiseLendingAddress,
            MAX_AMOUNT
        );

        _safeApprove(
            FARM_ASSET,
            _wiseLendingAddress,
            MAX_AMOUNT
        );

        _safeApprove(
            FARM_ASSET,
            address(AAVE_HUB),
            MAX_AMOUNT
        );
    }

    /**
     * @dev Internal function executing the
     * collateral deposit by converting ETH
     * into {ENTRY_ASSET}, adding it as collateral and
     * borrowing the flashloan token to pay
     * back {_totalDebtBalancer}.
     */
    function _logicOpenPosition(
        bool _isAave,
        uint256 _nftId,
        uint256 _depositAmount,
        uint256 _totalDebtBalancer,
        uint256 _allowedSpread
    )
        internal
        override
    {
        _executeCommonOpenPosition(
            _isAave,
            _nftId,
            _depositAmount,
            _depositAmount,
            _totalDebtBalancer,
            _allowedSpread
        );
    }

    /**
     * @dev Closes position using balancer flashloans.
     */
    function _logicClosePosition(
        uint256 _nftId,
        uint256 _borrowShares,
        uint256 _lendingShares,
        uint256 _totalDebtBalancer,
        uint256 _allowedSpread,
        address _caller,
        bool,
        bool _isAave
    )
        internal
        override
    {
        (
            uint256 tokenOutAmount,
            uint256 ethValueBefore
        ) = _executeCommonClosePositionUntilRedeem(
            _nftId,
            _borrowShares,
            _lendingShares,
            _isAave
        );

        _executeCommonClosePositionAfterRedeem(
            tokenOutAmount,
            _totalDebtBalancer,
            _allowedSpread,
            ethValueBefore,
            _caller
        );
    }
}
