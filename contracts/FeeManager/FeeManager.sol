// SPDX-License-Identifier: -- WISE --

pragma solidity =0.8.21;

/**
 * @author Christoph Krpoun
 * @author René Hochmuth
 * @author Vitally Marinchenko
 */

import "./FeeManagerHelper.sol";

/**
 * @dev Purpose of this contract is to organize fee distribution from wiseLending.
 * The feeManager aquires fee token in form of shares from each pool and can call them
 * with "claimWiseFees()" for each pool.
 *
 * Furthermore, this contracts has two different incentive
 * structures which can be used to bootstrap the WISE ecosystem (beneficial and incnetiveOwner roles).
 *
 * Additionally, this contract keeps track of the bad debt of each postion and has a simple mechanism
 * to pay them back via incentives. The incentive amount is funded by the gathered fees.
 */

contract FeeManager is FeeManagerHelper {

    constructor(
        address _master,
        address _aaveAddress,
        address _wiseLendingAddress,
        address _oracleHubAddress,
        address _wiseSecurityAddress,
        address _positionNFTAddress
    )
        DeclarationsFeeManager(
            _master,
            _aaveAddress,
            _wiseLendingAddress,
            _oracleHubAddress,
            _wiseSecurityAddress,
            _positionNFTAddress
        )
    {}

    /**
     * @dev Allows to adjust the paid out incentive
     * percentage for user to reduce bad debt.
     */
    function setRepayBadDebtIncentive(
        uint256 _percent
    )
        external
        onlyMaster
    {
        _checkValue(
            _percent
        );

        paybackIncentive = _percent;
    }

    /**
     * @dev Maps underlying token with corresponding aToken.
     * Sets bool to identify pool token as aToken.
     */
    function setAaveFlag(
        address _poolToken,
        address _underlyingToken
    )
        external
        onlyMaster
    {
        isAaveToken[_poolToken] = true;
        underlyingToken[_poolToken] = _underlyingToken;
    }

    /**
     * @dev Function to adjust pool fee. Fee can not be greater than 100%
     * or lower than 1%. Can be adjusted for each pool individually.
     */
    function setPoolFee(
        address _poolToken,
        uint256 _newFee
    )
        external
        onlyMaster
    {
        _checkValue(
            _newFee
        );

        WISE_LENDING.setPoolFee(
            _poolToken,
            _newFee
        );
    }

    /**
     * @dev Function to propose new incentive master. This role can increase
     * the incentive amount for both incentive mappings. These are two roles
     * for incentivising external persons e.g. developers.
     */
    function proposeIncentiveMaster(
        address _proposedIncentiveMaster
    )
        external
        onlyIncentiveMaster
    {
        proposedIncentiveMaster = _proposedIncentiveMaster;
    }

    /**
     * @dev Claim proposed incentive master by proposed entity.
     */
    function claimOwnershipIncentiveMaster()
        external
    {
        if (msg.sender != proposedIncentiveMaster) {
            revert NotAllowed();
        }

        incentiveMaster = proposedIncentiveMaster;
        proposedIncentiveMaster = ZERO_ADDRESS;
    }

    /**
     * @dev Increase function for increasing incentive amount for entity A.
     * Only callable by incentive master.
     */
    function increaseIncentiveA(
        uint256 _value
    )
        external
        onlyIncentiveMaster
    {
        incentiveUSD[incentiveOwnerA] += _value;
    }

    /**
     * @dev Increase function for increasing incentive amount for entity B.
     * Only callable by incentive master.
     */
    function increaseIncentiveB(
        uint256 _value
    )
        external
        onlyIncentiveMaster
    {
        incentiveUSD[incentiveOwnerB] += _value;
    }

    /**
     * @dev Function to claim all gathered incetives.
     */
    function claimIncentivesBulk()
        external
    {
        address tokenAddress;
        uint256 l = getPoolTokenAddressesLength();

        for (uint8 i = 0; i < l; ++i) {

            tokenAddress = poolTokenAddresses[i];

            if (isAaveToken[tokenAddress] == true) {
                tokenAddress = underlyingToken[
                    tokenAddress
                ];
            }

            claimIncentives(
                tokenAddress
            );
        }
    }

    /**
     * @dev Claims gathered incentives for a specific token.
     */
    function claimIncentives(
        address _feeToken
    )
        public
    {
        _safeTransfer(
            _feeToken,
            msg.sender,
            gatheredIncentiveToken[msg.sender][_feeToken]
        );

        delete gatheredIncentiveToken[msg.sender][_feeToken];
    }

    /**
     * @dev Function chaning incentiveOwnerA!. Only callable by
     * incentiveOwnerA.
     */
    function changeIncentiveUSDA(
        address _newOwner
    )
        external
    {
        if (msg.sender != incentiveOwnerA) {
            revert NotAllowed();
        }

        incentiveUSD[_newOwner] = incentiveUSD[
            incentiveOwnerA
        ];

        delete incentiveUSD[
            incentiveOwnerA
        ];

        incentiveOwnerA = _newOwner;
    }

    /**
     * @dev Function chaning incentiveOwnerB!. Only callable by
     * incentiveOwnerB.
     */
    function changeIncentiveUSDB(
        address _newOwner
    )
        external
    {
        if (msg.sender != incentiveOwnerB) {
            revert NotAllowed();
        }

        incentiveUSD[_newOwner] = incentiveUSD[
            incentiveOwnerB
        ];

        delete incentiveUSD[incentiveOwnerB];

        incentiveOwnerB = _newOwner;
    }

    /**
     * @dev Function adding new pool token to pool token list.
     * Called during pool creation and only callable by wiseLending
     * contract.
     */
    function addPoolTokenAddress(
        address _poolToken
    )
        external
        onlyWiseLending
    {
        poolTokenAddresses.push(
            _poolToken
        );

        poolTokenAdded[_poolToken] = true;

        emit PoolTokenAdded(
            _poolToken,
            block.timestamp
        );
    }

    /**
     * @dev Function to add pool token manualy. Only
     * callable by feeManager master.
     */
    function addPoolTokenAddressManual(
        address _poolToken
    )
        external
        onlyMaster
    {
        if (poolTokenAdded[_poolToken] == true) {
            revert PoolAlreadyAdded();
        }

        poolTokenAddresses.push(
            _poolToken
        );

        poolTokenAdded[_poolToken] = true;

        emit PoolTokenAdded(
            _poolToken,
            block.timestamp
        );
    }

    /**
     * @dev Function to remove pool token manualy from pool
     * token list. Only callable by feeManager master.
     */
    function removePoolTokenManual(
        address _poolToken
    )
        external
        onlyMaster
    {
        uint256 len = getPoolTokenAddressesLength();
        uint256 lastEntry = len - 1;

        for (uint8 i = 0; i < len; ++i) {

            if (_poolToken != poolTokenAddresses[i]) {
                continue;
            }

            poolTokenAddresses[i] = poolTokenAddresses[lastEntry];
            poolTokenAddresses.pop();
            poolTokenAdded[_poolToken] = false;

            break;
        }
    }

    /**
     * @dev Increase function for total bad debt of
     * wiseLending. Only callable by wiseSecurity contract
     * during liquidation.
     */
    function increaseTotalBadDebtLiquidation(
        uint256 _amount
    )
        external
        onlyWiseSecurity
    {
        _increaseTotalBadDebt(
            _amount
        );

        emit BadDebtIncreasedLiquidation(
            _amount,
            block.timestamp
        );
    }

    /**
     * @dev Increase function for bad debt of a position.
     * Only callable by wiseSecurity contract during liquidation.
     */
    function setBadDebtUserLiquidation(
        uint256 _nftId,
        uint256 _amount
    )
        external
        onlyWiseSecurity
    {
        _setBadDebtPosition(
            _nftId,
            _amount
        );

        emit SetBadDebtPosition(
            _nftId,
            _amount,
            block.timestamp
        );
    }

    /**
     * @dev Set function to declare an address as beneficial for
     * a fee token. Address can claim gathered fee token as long as
     * it is declared as beneficial. Only setable by master.
     */
    function setBeneficial(
        address _user,
        address[] memory _feeTokens
    )
        external
        onlyMaster
    {
        for (uint8 i = 0; i < _feeTokens.length; ++i) {
            _setAllowedTokens(
                _user,
                _feeTokens[i],
                true
            );
        }

        emit SetBeneficial(
            _user,
            _feeTokens,
            block.timestamp
        );
    }

    /**
     * @dev Set function to remove an address as beneficial for
     * a fee token. Only setable by master.
     */
    function revokeBeneficial(
        address _user,
        address[] memory _feeTokens
    )
        external
        onlyMaster
    {
        for (uint8 i = 0; i < _feeTokens.length; ++i) {
            _setAllowedTokens(
                _user,
                _feeTokens[i],
                false
            );
        }

        emit RevokeBeneficial(
            _user,
            _feeTokens,
            block.timestamp
        );
    }

    /**
     * @dev Claim all fees from wiseLending and send them to feeManager.
     */
    function claimWiseFeesBulk()
        external
    {
        uint256 l = getPoolTokenAddressesLength();

        for (uint8 i = 0; i < l; ++i) {
            claimWiseFees(
                poolTokenAddresses[i]
            );
        }
    }

    /**
     * @dev Claim fees from wiseLending and send them to feeManager for
     * a specific pool.
     */
    function claimWiseFees(
        address _poolToken
    )
        public
    {
        address underlyingTokenAddress = _poolToken;

        uint256 shares = WISE_LENDING.getPositionLendingShares(
            FEE_MANAGER_NFT,
            _poolToken
        );

        if (shares == 0) {
            return;
        }

        uint256 tokenAmount = WISE_LENDING.withdrawExactShares(
            FEE_MANAGER_NFT,
            _poolToken,
            shares
        );

        if (isAaveToken[_poolToken] == true) {

            underlyingTokenAddress = underlyingToken[
                _poolToken
            ];

            AAVE.withdraw(
                underlyingTokenAddress,
                tokenAmount,
                address(this)
            );
        }

        if (totalBadDebtUSD == 0) {

            tokenAmount = _distributeIncentives(
                tokenAmount,
                _poolToken,
                underlyingTokenAddress
            );
        }

        _increaseFeeTokens(
            underlyingTokenAddress,
            tokenAmount
        );

        emit ClaimedFeesWise(
            underlyingTokenAddress,
            tokenAmount,
            block.timestamp
        );
    }

    /**
     * @dev Function for beneficial to claim gathered fees. Can only
     * claim fees for which the beneficial is allowed. Can only claim
     * token which are inside the feeManager.
     */
    function claimFeesBeneficial(
        address _feeToken,
        uint256 _amount
    )
        external
    {
        address caller = msg.sender;

        if (totalBadDebtUSD > 0) {
            revert ExistingBadDebt();
        }

        if (allowedTokens[caller][_feeToken] == false) {
            revert NotAllowed();
        }

        _decreaseFeeTokens(
            _feeToken,
            _amount
        );

        _safeTransfer(
            _feeToken,
            caller,
            _amount
        );

        emit ClaimedFeesBeneficial(
            caller,
            _feeToken,
            _amount,
            block.timestamp
        );
    }

    /**
     * @dev Function for paying back bad debt of a position. Caller
     * chooses postion, token and receive token. Only gathered fee token
     * can be distributed as receive token. Caller gets 5% more
     * in USDC value as incentive.
     */
    function payBackBadDebtForToken(
        uint256 _nftId,
        address _paybackToken,
        address _receivingToken,
        uint256 _shares
    )
        external
        returns (
            uint256 paybackAmount,
            uint256 receivingAmount
        )
    {
        updatePositionCurrentBadDebt(
            _nftId
        );

        if (badDebtPosition[_nftId] == 0) {
            return (
                0,
                0
            );
        }

        paybackAmount = WISE_LENDING.paybackAmount(
            _paybackToken,
            _shares
        );

        WISE_LENDING.corePaybackFeeManager(
            _paybackToken,
            _nftId,
            paybackAmount,
            _shares
        );

        _updateUserBadDebt(
            _nftId
        );

        receivingAmount = getReceivingToken(
            _paybackToken,
            _receivingToken,
            paybackAmount
        );

        _decreaseFeeTokens(
            _receivingToken,
            receivingAmount
        );

        _safeTransferFrom(
            _paybackToken,
            msg.sender,
            address(WISE_LENDING),
            paybackAmount
        );

        _safeTransfer(
            _receivingToken,
            msg.sender,
            receivingAmount
        );

        emit PayedBackBadDebt(
            _nftId,
            msg.sender,
            _paybackToken,
            _receivingToken,
            paybackAmount,
            block.timestamp
        );
    }

    /**
     * @dev Function for paying back bad debt of a position. Caller
     * chooses postion, token and receive token. Caller gets no
     * receive token!
     */
    function paybackBadDebtForFree(
        uint256 _nftId,
        address _paybackToken,
        uint256 _shares
    )
        external
        returns (uint256 paybackAmount)
    {
        updatePositionCurrentBadDebt(
            _nftId
        );

        if (badDebtPosition[_nftId] == 0) {
            return 0;
        }

        paybackAmount = WISE_LENDING.paybackAmount(
            _paybackToken,
            _shares
        );

        WISE_LENDING.corePaybackFeeManager(
            _paybackToken,
            _nftId,
            paybackAmount,
            _shares
        );

        _updateUserBadDebt(
            _nftId
        );

        _safeTransferFrom(
            _paybackToken,
            msg.sender,
            address(WISE_LENDING),
            paybackAmount
        );

        emit PayedBackBadDebtFree(
            _nftId,
            msg.sender,
            _paybackToken,
            paybackAmount,
            block.timestamp
        );
    }

    /**
     * @dev Returning the number of pool token
     * addresses saved inside the feeManager.
     */
    function getPoolTokenAddressesLength()
        public
        view
        returns (uint256)
    {
        return poolTokenAddresses.length;
    }

    /**
     * @dev Returns the pool token address
     * at the _index postion of the array.
     */
    function getPoolTokenAdressesByIndex(
        uint256 _index
    )
        external
        view
        returns (address)
    {
        return poolTokenAddresses[_index];
    }

    /**
     * @dev Bulk function for updating pools - loops through
     * all pools saved inside the poolTokenAddresses array.
     */
    function syncAllPools()
        external
    {
        for (uint256 i = 0; i < poolTokenAddresses.length; ++i) {
            WISE_LENDING.syncManually(
                poolTokenAddresses[i]
            );
        }
    }
}
