// SPDX-License-Identifier: -- WISE --

pragma solidity =0.8.21;

import "./Types.sol";
import "../OwnableMaster.sol";

import "../InterfaceHub/IWiseOracleHub.sol";
import "../InterfaceHub/IWiseLending.sol";
import "../TransferHub/TransferHelper.sol";
import "../InterfaceHub/IWiseSecurity.sol";
import "../InterfaceHub/IWiseLiquidation.sol";
import "../InterfaceHub/IPositionNFTs.sol";
import "../InterfaceHub/IFeeManager.sol";

error AlreadyInitalized();

contract DeclarationsLiquidationBot is OwnableMaster, TransferHelper {

    // Note:
    // ETH-main: 0xB3f5503f93d5Ef84b06993a1975B9D21B962892F
    // ETH-goerli: 0xc1C6805B857Bef1f412519C4A842522431aFed39
    address public immutable AUTOMATE_ADDRESS;
    address private immutable GELATO_ADDRESS;

    IOps public immutable OPS;
    ITaskTreasuryUpgradable public immutable TASK_TREASURY;

    IWiseLending public immutable WISE_LENDING;
    IWiseSecurity public immutable WISE_SECURITY;
    IWiseLiquidation public immutable WISE_LIQUIDATION;
    IWiseOracleHub public immutable ORACLE_HUB;
    IPositionNFTs public immutable POSITION_NFT;
    IFeeManager public immutable FEE_MANAGER;

    uint8 public taskCounter;
    uint256 public liquidationPercent;
    uint256 public immutable NFT_BOT;

    bytes32 public updateTask;

    mapping(uint8 => bytes32) public taskIds;
    mapping(address => uint256) public thresholdPriceDeviation;
    mapping(address => uint256) public intervallUpdate;

    mapping(uint256 => string) functionNamesResolver;

    uint8 constant MAX_ANZ_RESOLVER = 10;
    uint256 constant BASE_INTERVAL = 100;
    uint256 constant FEE_PERCENT = 1E17;
    uint256 constant PRECISION_FACTOR_E18 = 1E18;
    uint256 constant MAX_AMOUNT = type(uint256).max;
    uint256 constant MAX_USD_LIQUIDATION_FEE = 500 * PRECISION_FACTOR_E18;
    uint256 constant THRESHOLD = 200 * PRECISION_FACTOR_E18;

    bytes32 constant EMPTY_BYTES32 = bytes32("");
    bytes constant EMPTY_BYTES = abi.encodePacked(int(0));

    address internal constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    constructor(
        address _automateAddress,
        address _wiseLendingAddress
    )
        OwnableMaster(
            msg.sender
        )
    {
        AUTOMATE_ADDRESS =_automateAddress;

        liquidationPercent = 0.4 ether;

        OPS = IOps(AUTOMATE_ADDRESS);
        TASK_TREASURY = OPS.taskTreasury();

        GELATO_ADDRESS = OPS.gelato();

        WISE_LENDING = IWiseLending(
            _wiseLendingAddress
        );

        WISE_SECURITY = IWiseSecurity(
            WISE_LENDING.WISE_SECURITY()
        );

        WISE_LIQUIDATION = IWiseLiquidation(
            _wiseLendingAddress
        );

        ORACLE_HUB = IWiseOracleHub(
            WISE_LENDING.WISE_ORACLE()
        );

        FEE_MANAGER = IFeeManager(
            WISE_LENDING.FEE_MANAGER()
        );

        POSITION_NFT = IPositionNFTs(
            WISE_LENDING.POSITION_NFT()
        );

        NFT_BOT = POSITION_NFT.mintPositionForUser(
            address(this)
        );

        functionNamesResolver[0] = "resolverLiqudation1()";
        functionNamesResolver[1] = "resolverLiqudation2()";
        functionNamesResolver[2] = "resolverLiqudation3()";
        functionNamesResolver[3] = "resolverLiqudation4()";
        functionNamesResolver[4] = "resolverLiqudation5()";
        functionNamesResolver[5] = "resolverLiqudation6()";
        functionNamesResolver[6] = "resolverLiqudation7()";
        functionNamesResolver[7] = "resolverLiqudation8()";
        functionNamesResolver[8] = "resolverLiqudation9()";
        functionNamesResolver[9] = "resolverLiqudation10()";
    }

    event ERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes _data
    );

    function onERC721Received(
        address _operator,
        address _from,
        uint256 _tokenId,
        bytes calldata _data
    )
        external
        returns (bytes4)
    {
        emit ERC721Received(
            _operator,
            _from,
            _tokenId,
            _data
        );

        return this.onERC721Received.selector;
    }
}