// SPDX-License-Identifier: -- WISE --

pragma solidity =0.8.21;

error NotCorrectFarm();
error MintToZeroAddress();
error AllowanceBelowZero();
error BurnExceedsBalance();
error BurnFromZeroAddress();
error TransferZeroAddress();
error InsufficientAllowance();
error ApproveWithZeroAddress();
error TransferAmountExceedsBalance();

contract HybridToken {

    // Name of hybrid token used for pendle power farm
    string private _name;

    // Symbol of hybrid token used for pendle power farm
    string private _symbol;

    // Total supply of power farm token
    uint256 private _totalSupply;

    // Pendle pofer farm to which the token belongs
    address public correspondingFarm;

    // Mapping accounting balance of {address}
    mapping(address => uint256) private _balances;

    // Mapping accounting allowance of {address} for {spender}
    mapping(address => mapping(address => uint256)) private _allowances;

    // Miscellaneous constants
    uint256 internal constant UINT256_MAX = type(uint256).max;
    address internal constant ZERO_ADDRESS_TOKEN = address(0);

    modifier onlyFarm() {
        _onlyFarm();
        _;
    }

    function _onlyFarm()
        private
        view
    {
        if (msg.sender != correspondingFarm) {
            revert NotCorrectFarm();
        }
    }

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    constructor(
        address _powerFarm
    )
    {
        _name = "_tokenName";
        _symbol = "_symbolName";

        correspondingFarm = _powerFarm;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name()
        external
        view
        returns (string memory)
    {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol()
        external
        view
        returns (string memory)
    {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the default value returned by this function, unless
     * it's overridden.
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals()
        external
        pure
        returns (uint8)
    {
        return 18;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply()
        public
        view
        returns (uint256)
    {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(
        address _account
    )
        external
        view
        returns (uint256)
    {
        return _balances[_account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(
        address _to,
        uint256 _amount
    )
        external
        returns (bool)
    {
        _transfer(
            _msgSender(),
            _to,
            _amount
        );

        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(
        address _owner,
        address _spender
    )
        public
        view
        returns (uint256)
    {
        return _allowances[_owner][_spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * NOTE: If `amount` is the maximum `uint256`, the allowance is not updated on
     * `transferFrom`. This is semantically equivalent to an infinite approval.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(
        address _spender,
        uint256 _amount
    )
        external
        returns (bool)
    {
        _approve(
            _msgSender(),
            _spender,
            _amount
        );

        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * NOTE: Does not update the allowance if the current allowance
     * is the maximum `uint256`.
     *
     * Requirements:
     *
     * - `from` and `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     * - the caller must have allowance for ``from``'s tokens of at least
     * `amount`.
     */
    function transferFrom(
        address _from,
        address _to,
        uint256 _amount
    )
        external
        returns (bool)
    {
        _spendAllowance(
            _from,
            _msgSender(),
            _amount
        );

        _transfer(
            _from,
            _to,
            _amount
        );

        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(
        address _spender,
        uint256 _addedValue
    )
        external
        returns (bool)
    {
        address owner = _msgSender();

        _approve(
            owner,
            _spender,
            allowance(owner, _spender) + _addedValue
        );

        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(
        address _spender,
        uint256 _subtractedValue
    )
        external
        returns (bool)
    {
        address owner = _msgSender();

        uint256 currentAllowance = allowance(
            owner,
            _spender
        );

        if (currentAllowance < _subtractedValue) {
            revert AllowanceBelowZero();
        }

        unchecked {
            _approve(
                owner,
                _spender,
                currentAllowance - _subtractedValue
            );
        }

        return true;
    }

    /**
     * @dev External wrapper for mint function. Can only be called
     * by corresponding power farm.
     */
    function mint(
        address _account,
        uint256 _amount
    )
        external
        onlyFarm
    {
        _mint(
            _account,
            _amount
        );
    }

    /**
     * @dev External wrapper for burn function. Can only be called
     * by corresponding power farm.
     */
    function burn(
        address _account,
        uint256 _amount
    )
        external
        onlyFarm
    {
        _burn(
            _account,
            _amount
        );
    }

    /**
     * @dev Moves `amount` of tokens from `from` to `to`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     */
    function _transfer(
        address _from,
        address _to,
        uint256 _amount
    )
        internal
    {
        if (_from == ZERO_ADDRESS_TOKEN || _to == ZERO_ADDRESS_TOKEN) {
            revert TransferZeroAddress();

        }

        uint256 fromBalance = _balances[_from];

        if (fromBalance < _amount) {
            revert TransferAmountExceedsBalance();
        }

        unchecked {
            _balances[_from] = fromBalance - _amount;
            _balances[_to] += _amount;
        }

        emit Transfer(
            _from,
            _to,
            _amount
        );
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function _mint(
        address _account,
        uint256 _amount
    )
        internal
    {
        if (_account == ZERO_ADDRESS_TOKEN) {
            revert MintToZeroAddress();
        }

        _totalSupply += _amount;

        unchecked {
            _balances[_account] += _amount;
        }

        emit Transfer(
            ZERO_ADDRESS_TOKEN,
            _account,
            _amount
        );
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(
        address _account,
        uint256 _amount
    )
        internal
    {
        if (_account == ZERO_ADDRESS_TOKEN) {
            revert BurnFromZeroAddress();
        }

        uint256 accountBalance = _balances[_account];

        if (accountBalance < _amount) {
            revert BurnExceedsBalance();
        }

        unchecked {
            _balances[_account] = accountBalance - _amount;
            _totalSupply -= _amount;
        }

        emit Transfer(
            _account,
            ZERO_ADDRESS_TOKEN,
            _amount
        );
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(
        address _owner,
        address _spender,
        uint256 _amount
    )
        internal
    {
        if (_owner == ZERO_ADDRESS_TOKEN || _spender == ZERO_ADDRESS_TOKEN) {
            revert ApproveWithZeroAddress();
        }

        _allowances[_owner][_spender] = _amount;

        emit Approval(
            _owner,
            _spender,
            _amount
        );
    }

    /**
     * @dev Updates `owner` s allowance for `spender` based on spent `amount`.
     *
     * Does not update the allowance amount in case of infinite allowance.
     * Revert if not enough allowance is available.
     *
     * Might emit an {Approval} event.
     */
    function _spendAllowance(
        address _owner,
        address _spender,
        uint256 _amount
    )
        internal
    {
        uint256 currentAllowance = allowance(
            _owner,
            _spender
        );

        if (currentAllowance != UINT256_MAX) {

            if (currentAllowance < _amount) {
                revert InsufficientAllowance();
            }

            unchecked {
                _approve(
                    _owner,
                    _spender,
                    currentAllowance - _amount
                );
            }
        }
    }

    /**
     * @dev Internal wrapper for msg.sender call.
     */
    function _msgSender()
        internal
        view
        returns (address)
    {
        return msg.sender;
    }
        /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 value
    );

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}