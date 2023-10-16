// SPDX-License-Identifier: -- WISE --

pragma solidity =0.8.21;

import "./OwnableMaster.sol";

error TooLate();
error TooEarly();

struct CurveSwapStruct {
    uint256 curvePoolTokenIndexFrom;
    uint256 curvePoolTokenIndexTo;
    uint256 curveMetaPoolTokenIndexFrom;
    uint256 curveMetaPoolTokenIndexTo;
    uint256 curvePoolSwapAmount;
    uint256 curveMetaPoolSwapAmount;
}

struct CreatePoolStruct {
    bool allowBorrow;
    address poolToken;
    address curvePool;
    address curveMetaPool;
    address[] underlyingPoolTokens;
    CurveSwapStruct curveSecuritySwaps;
    uint256 poolMulFactor;
    uint256 poolCollFactor;
    uint256 maxDepositAmount;
}

interface IWiseLendingPoolCreator {

    function createPool(
        CreatePoolStruct memory _data
    )
        external;
}

contract TimeLockDecider is OwnableMaster {

    uint256 public proposalCount;
    uint256 public immutable timeLock;
    uint256 public constant MIN_FRAME = 2 days;

    IWiseLendingPoolCreator public WISE_LENDING;

    mapping(uint256 => uint256) public creationTimes;
    mapping(uint256 => CreatePoolStruct) public upcomingPools;

    modifier timeLocked(
        uint256 _creationIndex
    ) {
        uint256 currentTime = block.timestamp;
        uint256 creationTime = creationTimes[
            _creationIndex
        ];

        if (currentTime < creationTime) {
            revert TooEarly();
        }

        if (currentTime > creationTime + MIN_FRAME) {
            revert TooLate();
        }
        _;
    }

    constructor(
        address _master,
        uint256 _timeLock
    )
        OwnableMaster(
            _master
        )
    {
        require(
            _timeLock > MIN_FRAME,
            "TimeLockDecider: TOO_FAST"
        );

        timeLock = _timeLock;
    }

    function setWiseLending(
        address _wiseLending
    )
        external
        onlyMaster
    {
        WISE_LENDING = IWiseLendingPoolCreator(
            _wiseLending
        );
    }

    function preparePool(
        CreatePoolStruct memory _inputParams
    )
        external
        onlyMaster
    {
        uint256 currentCounter = proposalCount;

        upcomingPools[currentCounter] = _inputParams;
        creationTimes[currentCounter] = block.timestamp
            + MIN_FRAME;

        proposalCount = currentCounter + 1;
    }

    function createPool(
        uint256 _creationIndex
    )
        external
        onlyMaster
        timeLocked(_creationIndex)
    {
        WISE_LENDING.createPool(
            upcomingPools[
                _creationIndex
            ]
        );
    }
}