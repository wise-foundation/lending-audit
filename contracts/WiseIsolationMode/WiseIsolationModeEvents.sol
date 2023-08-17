// SPDX-License-Identifier: WISE

pragma solidity =0.8.21;

contract WiseIsolationModeEvents {

    event IsDepositIsolationPool(
        uint256 nftId,
        uint256 timestamp
    );

    event IsWithdrawIsolationPool(
        uint256 nftId,
        uint256 timestamp
    );

    event IsBorrowIsolationPool(
        uint256 nftId,
        uint256 timestamp
    );

    event IsPaybackIsolationPool(
        uint256 nftId,
        uint256 timestamp
    );

    event LiquidatedIsolationPool(
        uint256 nftId,
        address liquidator,
        address[] paybackTokens,
        address receivingToken,
        uint256 paybackUSD,
        uint256 timestamp
    );

    event RegistrationFarm(
        uint256 nftId,
        uint256 index,
        uint256 timestamp
    );

    event UnregistrationFarm(
        uint256 nftId,
        uint256 previousIndex,
        uint256 timestamp
    );
}