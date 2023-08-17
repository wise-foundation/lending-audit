// SPDX-License-Identifier: -- WISE --

pragma solidity =0.8.21;

/**
 * @author Christoph Krpoun
 * @author René Hochmuth
 * @author Vitally Marinchenko
 */

import "./WiseLiquidationHelper.sol";

contract WiseLiquidation is WiseLiquidationHelper {

    constructor(
        address _master,
        address _lendingAddress,
        address _oracleHubAddress,
        address _wiseSecurityAddress
    )
        Declarations(
            _master,
            _lendingAddress,
            _oracleHubAddress,
            _wiseSecurityAddress
        )
    {}

}
