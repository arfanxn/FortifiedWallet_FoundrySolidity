// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {DynamicPriceConsumer} from "src/DynamicPriceConsumer.sol";
import {HelperConfig} from "src/HelperConfig.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

interface IERC20Metadata is IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}

contract Wallet is ReentrancyGuard {
    HelperConfig private immutable config;

    //==============================================================
    //                           Errors
    //==============================================================

    // Errors related to validation
    error MustUseFunctionCall();
    error MustBeGreaterThanZero();
    error MustBeNonZeroAddress();
    error MustMatchEtherValue();
    error InsufficientUnlockedBalance();

    // Errors related to wallet configuration
    error InsufficientSigners();
    error ExcessiveSigners(); // Error when the number of signers exceeds the allowed limit
    error DuplicateSigners();
    error OnlySigner();

    // Errors related to transactions
    error DepositFailed();
    error TransactionDoesNotExist();
    error TransactionAlreadyApproved();
    error TransactionNotApproved();
    error TransactionAlreadyRevoked();
    error TransactionNotRevoked();
    error TransactionAlreadyExecuted();
    error TransactionNotExecuted();
    error TransactionAlreadyCancelled();
    error TransactionNotCancelled();
    error TransactionLacksApprovals();
    error TransactionFailed();

    //==============================================================
    //                           Libraries
    //==============================================================
    using SafeERC20 for IERC20;

    //==============================================================
    //                       State variables
    //==============================================================

    /// @dev The name of the wallet
    string private s_name;
    /// @dev Mapping of signer addresses to their signer status
    mapping(address => bool) private s_isSigner;
    /// @dev The signers of the wallet
    address[] private s_signers;
    /// @dev The minimum number of approvals required to execute a transaction
    uint256 private s_minimumApprovals;
    /// @dev Stores the tokens that the wallet is holding
    address[] private s_tokens;
    /// @dev Tracks existing tokens to avoid duplicates
    mapping(address => bool) private s_tokenExists;
    /// @dev The amount of each ERC20 token (or ETH if address(0)) that is currently locked (i.e. not transferable)
    mapping(address => uint256) private s_lockedBalances;

    /// @notice Represents a transaction to be executed by the wallet
    struct Transaction {
        // Unique identifier for the transaction
        bytes32 hash;
        // Token address if the transaction involves an ERC20 token transfer.
        /// @dev If address(0) it means it is an ETH transaction not an ERC20 transaction.
        address token;
        // Address to which the transaction will be sent
        address to;
        // Ether value to be transferred in the transaction
        uint256 value;
        // Number of approvals the transaction has received
        uint8 approvalCount;
        /// @dev Mapping of approver addresses to their approval status
        mapping(address => bool) hasApproved;
        // Timestamp when the transaction was created
        uint256 createdAt;
        // Timestamp when the transaction was executed
        uint256 executedAt;
        // Timestamp when the transaction was cancelled
        uint256 cancelledAt;
    }

    /// @dev Maps transaction hashes to their respective transactions
    mapping(bytes32 => Transaction) private s_transactions;
    /// @dev Stores all transaction hashes in the order they were created
    bytes32[] private s_transactionHashes;
    /// @dev The hash of the most recently created transaction
    bytes32 private s_lastTransactionHash;

    //==============================================================
    //                           Enums
    //==============================================================

    //==============================================================
    //                           Events
    //==============================================================

    event TransactionCreated(
        bytes32 indexed txHash,
        address indexed to,
        uint256 value,
        address token
    );
    event TransactionApproved(bytes32 indexed txHash, address indexed approver);
    event TransactionRevoked(bytes32 indexed txHash, address indexed revoker);
    event TransactionExecuted(bytes32 indexed txHash, address indexed executor);
    event TransactionCancelled(
        bytes32 indexed txHash,
        address indexed canceller
    );
    /// @dev Emitted when the wallet receives Ether
    event Deposited(address indexed sender, uint256 value);
    /// @dev Emitted when the wallet receives an ERC20 token
    event ERC20Deposited(
        address indexed sender,
        address indexed token,
        uint256 value
    );

    //==============================================================
    //                           Modifiers
    //==============================================================

    /// @dev Ensures that the value is greater than zero.
    modifier greaterThanZero(uint256 value) {
        if (value == 0) revert MustBeGreaterThanZero();
        _;
    }

    /// @dev Ensures that the address is not the zero address.
    modifier nonZeroAddress(address value) {
        if (value == address(0)) revert MustBeNonZeroAddress();
        _;
    }

    /// @dev Ensures the caller is a signer.
    modifier onlySigner() {
        if (!s_isSigner[msg.sender]) revert OnlySigner();
        _;
    }

    /// @dev Ensures the transaction exists.
    modifier txExists(bytes32 txHash) {
        if (s_transactions[txHash].hash == bytes32(0))
            revert TransactionDoesNotExist();
        _;
    }

    /// @dev Ensures the transaction is not already approved by the given approver.
    modifier txNotApprovedBy(bytes32 txHash, address approver) {
        if (s_transactions[txHash].hasApproved[approver] == true)
            revert TransactionAlreadyApproved();
        _;
    }

    /// @dev Ensures the transaction is not already revoked by the given revoker.
    modifier txNotRevokedBy(bytes32 txHash, address revoker) {
        if (s_transactions[txHash].hasApproved[revoker] == false)
            revert TransactionAlreadyRevoked();
        _;
    }

    /// @dev Ensures the transaction is not already executed.
    modifier txNotExecuted(bytes32 txHash) {
        if (s_transactions[txHash].executedAt > 0)
            revert TransactionAlreadyExecuted();
        _;
    }

    /// @dev Ensures the transaction is not already cancelled.
    modifier txNotCancelled(bytes32 txHash) {
        if (s_transactions[txHash].cancelledAt > 0)
            revert TransactionAlreadyCancelled();
        _;
    }

    /// @dev Ensures the transaction has the required number of approvals.
    modifier txDoesNotLackApprovals(bytes32 txHash) {
        if (s_transactions[txHash].approvalCount < s_minimumApprovals)
            revert TransactionLacksApprovals();
        _;
    }

    //==============================================================
    //                       Init functions
    //==============================================================

    /**
     * @dev Initializes the fortified wallet contract.
     * @param _signers The array of addresses of the signers.
     * @param _minimumApprovalsRequired The minimum number of approvals required to execute a transaction.
     *
     * Requirements:
     * - The length of the `_signers` array must be greater than 1.
     * - The length of the `_signers` array must be less than or equal to 10.
     * - The value of `_minimumApprovalsRequired` must be greater than 1.
     * - The value of `_minimumApprovalsRequired` must be less than or equal to the length of the `_signers` array.
     */
    constructor(
        HelperConfig _config,
        string memory name,
        address[] memory _signers,
        uint256 _minimumApprovalsRequired
    ) {
        config = _config;
        s_name = name;
        uint256 signersLength = _signers.length;
        if (signersLength < 2) revert InsufficientSigners();
        // Limiting the number of signers to 10 is a trade-off between decentralization
        // and gas efficiency. With more than 10 signers, the cost of creating a new
        // transaction would be prohibitive. Given that the wallet is intended to be
        // used by a small group of trusted parties, 10 signers should be sufficient.
        if (signersLength > 10) revert ExcessiveSigners();
        if (_minimumApprovalsRequired < 2) revert InsufficientSigners();
        if (_minimumApprovalsRequired > signersLength)
            revert ExcessiveSigners();

        for (uint256 i = 0; i < signersLength; i++) {
            address _signer = _signers[i];

            if (_signer == address(0)) revert MustBeNonZeroAddress();
            if (s_isSigner[_signer] != false) revert DuplicateSigners();

            s_isSigner[_signer] = true;
            s_signers.push(_signer);
        }
        s_minimumApprovals = _minimumApprovalsRequired;
    }

    //==============================================================
    //                       Internal functions
    //==============================================================

    //==============================================================
    //                       External functions
    //==============================================================
    /// @notice Reverts any Ether sent to the contract.
    /// @dev This function is required to prevent Ether from being sent to the
    /// contract. To deposit Ether or ERC20 tokens, use the `deposit` function
    /// instead.
    receive() external payable {
        revert MustUseFunctionCall();
    }

    /// @notice Reverts any calls to the contract that are not explicitly handled.
    /// @dev This function is required to prevent any unexpected behavior from
    /// occurring when the contract is called with an unknown function signature.
    fallback() external payable {
        revert MustUseFunctionCall();
    }

    /// @notice Deposits Ether or ERC20 tokens into the wallet.
    /// @param token The ERC20 token to be deposited. If Ether, set to address(0).
    /// @param value The amount of tokens to be deposited. If Ether, set to address(0).
    function deposit(
        address token,
        uint256 value
    ) external payable greaterThanZero(value) nonReentrant {
        address etherAddress = address(0);

        // If token is not Ether (i.e. it's an ERC20 token), then `msg.value` must be zero.
        // Otherwise, if `msg.value` is not zero, then we must be depositing Ether, not an ERC20 token.
        bool tokenIsNotEther = token != etherAddress;
        bool msgValueIsNotZero = msg.value != 0;
        if (tokenIsNotEther && msgValueIsNotZero) revert MustUseFunctionCall();

        if (token == etherAddress) {
            if (msg.value != value) revert MustMatchEtherValue();
            emit Deposited(msg.sender, value);
        } else {
            // TODO: implements safeTransferFrom instead of transferFrom
            bool success = IERC20(token).transferFrom(
                msg.sender,
                address(this),
                value
            );
            if (!success) revert DepositFailed();
            emit ERC20Deposited(msg.sender, address(token), value);
        }

        // If the token has not already been added to the array of tokens, add it.
        // This is done to keep track of all the tokens that have been deposited
        // into the wallet.
        if (!s_tokenExists[token]) s_tokens.push(token);
    }

    /// @notice Locks the specified Ether and/or ERC20 tokens in the wallet, so
    /// that they cannot be transferred or executed.
    /// @param _tokens The array of ERC20 tokens to be locked. If Ether, set it to address(0).
    /// @param _balances The array of amounts of Ether and/or ERC20 tokens to be locked.
    /// @dev This function can be used to lock Ether and/or ERC20 tokens in the wallet.
    /// @dev Only the owner of the wallet can lock Ether and/or ERC20 tokens.
    function lockBalances(
        address[] memory _tokens,
        uint256[] memory _balances
    ) external onlySigner nonReentrant {
        // TODO: implement locking authentication

        for (uint256 i = 0; i < _tokens.length; i++) {
            address _token = _tokens[i];
            uint256 _balance = _balances[i];

            if (_token == address(0)) {
                // If Ether, set the address to 0
                s_lockedBalances[address(0)] = _balance;
                continue;
            }

            s_lockedBalances[_token] = _balance;
        }
    }

    /// @notice Unlocks the specified Ether and/or ERC20 tokens in the wallet, so
    /// that they can be transferred or executed.
    /// @param _tokens The array of ERC20 tokens to be unlocked. If Ether, set it to address(0).
    /// @param _balances The array of amounts of Ether and/or ERC20 tokens to be unlocked.
    /// @dev This function can be used to unlock Ether and/or ERC20 tokens in the wallet.
    /// @dev Only the owner of the wallet can unlock Ether and/or ERC20 tokens.
    function unlockBalances(
        address[] memory _tokens,
        uint256[] memory _balances
    ) external onlySigner nonReentrant {
        // TODO: implement unlocking authentication

        for (uint256 i = 0; i < _tokens.length; i++) {
            address _token = _tokens[i];
            uint256 _balance = _balances[i];

            if (_token == address(0)) {
                // If Ether, set the address to 0
                s_lockedBalances[address(0)] = _balance;
                continue;
            }

            s_lockedBalances[_token] = _balance;
        }
    }

    /// @notice Creates a new transaction.
    /// @param to The address to send the transaction to.
    /// @param value The amount of Ether or tokens to be sent.
    /// @param token The ERC20 token to be sent. If Ether, set to address(0).
    /// @dev This function can be used to create a transaction if you are the
    /// owner of the wallet.
    /// @notice Only the owner of the wallet can create a transaction.
    /// @notice The transaction will not be executed until enough approvals
    /// have been received.
    function createTransaction(
        address token,
        address to,
        uint256 value
    ) external onlySigner nonReentrant returns (bytes32 txHash) {
        uint256 timestamp = block.timestamp;

        bool isTokenTransaction = token != address(0);

        txHash = keccak256(
            abi.encodePacked(
                to,
                isTokenTransaction ? 0 : value,
                isTokenTransaction ? token : address(0),
                isTokenTransaction ? value : 0,
                timestamp
            )
        );
        Transaction storage _transaction = s_transactions[txHash];

        _transaction.hash = txHash;
        _transaction.to = to;
        _transaction.value = value;
        _transaction.token = isTokenTransaction ? token : address(0); // `address(0)` Indicates Ether transfer
        _transaction.approvalCount = 1;
        _transaction.hasApproved[msg.sender] = true;
        _transaction.createdAt = timestamp;
        _transaction.executedAt = 0;
        _transaction.cancelledAt = 0;

        s_transactionHashes.push(_transaction.hash); // Store the transaction key
        s_lastTransactionHash = _transaction.hash; // Update the last transaction

        emit TransactionCreated(
            _transaction.hash,
            _transaction.to,
            _transaction.value,
            _transaction.token
        );

        return _transaction.hash;
    }

    /// @notice Approve a transaction.
    /// @param txHash The hash of the transaction to be approved.
    /// @dev This function can be used to approve a transaction if it has not
    /// been executed yet.
    /// @notice Only the signer of the transaction can approve it.
    function approveTransaction(
        bytes32 txHash
    )
        external
        onlySigner
        txExists(txHash)
        txNotApprovedBy(txHash, msg.sender)
        txNotExecuted(txHash)
    {
        Transaction storage transaction = s_transactions[txHash];
        transaction.hasApproved[msg.sender] = true;
        transaction.approvalCount++;

        emit TransactionApproved(txHash, msg.sender);
    }

    /// @notice Revoke a transaction.
    /// @param txHash The hash of the transaction to be revoked.
    /// @dev This function can be used to revoke a transaction if it has not
    /// been executed yet.
    /// @notice Only the signer of the transaction can revoke it.
    function revokeTransaction(
        bytes32 txHash
    )
        external
        onlySigner
        txExists(txHash)
        txNotRevokedBy(txHash, msg.sender)
        txNotExecuted(txHash)
    {
        Transaction storage transaction = s_transactions[txHash];
        transaction.hasApproved[msg.sender] = false;
        delete transaction.hasApproved[msg.sender];
        transaction.approvalCount--;

        emit TransactionRevoked(txHash, msg.sender);
    }

    /// @dev Cancel a transaction.
    /// @param txHash The hash of the transaction to be cancelled.
    /// This function can be used to cancel a transaction if it has not
    /// been executed yet. Once a transaction is cancelled, it can't be uncancelled.
    function cancelTransaction(
        bytes32 txHash
    ) public onlySigner txExists(txHash) txNotExecuted(txHash) {
        Transaction storage transaction = s_transactions[txHash];
        transaction.cancelledAt = block.timestamp;

        emit TransactionCancelled(txHash, msg.sender);
    }

    function executeTransaction(
        bytes32 txHash
    )
        external
        onlySigner
        txExists(txHash)
        txNotExecuted(txHash)
        txNotCancelled(txHash)
        txDoesNotLackApprovals(txHash)
        nonReentrant
    {
        // Store the timestamp when the transaction is executed
        uint256 timestamp = block.timestamp;

        // Update the transaction state
        Transaction storage transaction = s_transactions[txHash];
        transaction.executedAt = timestamp;

        // Check if the transaction is an ERC20 token transfer
        bool isTokenTransaction = transaction.token != address(0);

        // Get the total balance of the token, and the locked balance
        uint256 totalBalance = isTokenTransaction
            ? IERC20(transaction.token).balanceOf(address(this))
            : address(this).balance;
        uint256 lockedBalance = s_lockedBalances[transaction.token];
        uint256 unlockedBalance = totalBalance - lockedBalance;

        // Revert if the transaction value exceeds the unlocked balance
        if (transaction.value > unlockedBalance)
            revert InsufficientUnlockedBalance();

        // Execute the transaction based on its type
        if (!isTokenTransaction) {
            // For ETH transactions, call the recipient address with the specified value
            (bool success, ) = transaction.to.call{value: transaction.value}(
                ""
            );
            // Revert if the transaction fails
            if (!success) revert TransactionFailed();
        } else {
            // For ERC20 transactions, transfer the specified amount to the recipient address
            bool success = IERC20(transaction.token).transferFrom(
                address(this),
                transaction.to,
                transaction.value
            );
            // Revert if the transaction fails
            if (!success) revert TransactionFailed();
        }

        // Emit the TransactionExecuted event
        emit TransactionExecuted(txHash, msg.sender);
    }

    //==============================================================
    //                       Getter functions
    //==============================================================

    /// @notice Returns the list of signers who have approved a transaction
    /// @param txHash The hash of the transaction to get the approvers for
    /// @return approvers The list of signers who have approved the transaction
    function _getTransactionApprovers(
        bytes32 txHash
    ) private view returns (address[] memory approvers) {
        Transaction storage transaction = s_transactions[txHash];
        address[] memory signers = s_signers;
        uint256 signersLength = signers.length;
        approvers = new address[](signersLength);

        uint256 approversIndex = 0;
        for (uint256 i = 0; i < signersLength; i++) {
            address signer = signers[i];
            if (transaction.hasApproved[signer] == true) {
                approvers[approversIndex] = signer;
                approversIndex++;
            }
        }
    }

    /// @dev Returns the name of the wallet
    /// @return The name of the wallet
    function getName() public view returns (string memory) {
        return s_name;
    }

    function getMinimumApprovals() public view returns (uint256) {
        return s_minimumApprovals;
    }

    /// @notice Returns the total balance of the wallet in USD
    /// @return usdTotal The total balance of the wallet in USD with 18 zeros (eg: 1 USD = 1,000,000,000,000,000,000 = 1e18)
    function getTotalBalance() public view returns (uint256 usdTotal) {
        address[] memory tokens = s_tokens;
        uint256 tokensLength = tokens.length;
        for (uint256 i = 0; i < tokensLength; i++) {
            address token = tokens[i];
            bool isEtherToken = token == address(0);

            uint256 balance = isEtherToken
                ? address(this).balance
                : IERC20(token).balanceOf(address(this));
            uint8 tokenDecimals = isEtherToken
                ? 18
                : IERC20Metadata(token).decimals();

            AggregatorV3Interface priceFeed = DynamicPriceConsumer(
                config.getPriceConsumer()
            ).fetchPriceFeed(token);

            (, int256 price, , , ) = priceFeed.latestRoundData();
            uint8 priceFeedDecimals = priceFeed.decimals();

            // Adjust decimals for calculation
            uint256 adjustedPrice = uint256(price) *
                (10 ** (18 - priceFeedDecimals)); // Scale to 18 decimals
            uint256 adjustedBalance = balance * (10 ** (18 - tokenDecimals)); // Scale to 18 decimals

            // Calculate USD value (balance * price)
            uint256 usdValue = (adjustedBalance * adjustedPrice) / 1e18; // Divide by 1e18 to normalize
            usdTotal += usdValue;
        }

        return usdTotal;
    }

    function getSigners() public view returns (address[] memory) {
        return s_signers;
    }

    /// @dev Returns a transaction based on its hash
    function getTransaction(
        bytes32 txHash
    )
        public
        view
        returns (
            bytes32,
            address token,
            address to,
            uint256 value,
            uint256 approvalCount,
            address[] memory approvers,
            uint256 createdAt,
            uint256 executedAt,
            uint256 cancelledAt
        )
    {
        Transaction storage transaction = s_transactions[txHash];
        approvers = _getTransactionApprovers(txHash);
        return (
            txHash,
            transaction.token,
            transaction.to,
            transaction.value,
            transaction.approvalCount,
            approvers,
            transaction.createdAt,
            transaction.executedAt,
            transaction.cancelledAt
        );
    }

    /// @dev Returns the hash of the most recently created transaction
    function getLastTransactionHash() public view returns (bytes32) {
        return s_lastTransactionHash;
    }
}
