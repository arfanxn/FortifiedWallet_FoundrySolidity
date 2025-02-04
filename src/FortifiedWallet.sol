// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
// import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
// import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract FortifiedWallet is ReentrancyGuard {
    /*////////////////////////////////////////////////
                        Errors
    ////////////////////////////////////////////////*/

    // Errors related to validation
    error MustUseFunctionCall();
    error MustBeGreaterThanZero();
    error MustBeNonZeroAddress();
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

    /*////////////////////////////////////////////////
                        Libraries
    ////////////////////////////////////////////////*/
    using SafeERC20 for IERC20;

    /*////////////////////////////////////////////////
                    State variables
    ////////////////////////////////////////////////*/

    /// @dev The signers of the wallet
    mapping(address => bool) private s_signers;
    /// @dev The minimum number of approvals required to execute a transaction
    uint256 private s_minimumApprovalsRequired;
    /// @dev The amount of each ERC20 token (or ETH if address(0)) that is currently locked (i.e. not transferable)
    mapping(address => uint256) private s_lockedBalances;

    /// @notice Represents a transaction to be executed by the wallet
    struct Transaction {
        // Unique identifier for the transaction
        bytes32 hash;
        // Address to which the transaction will be sent
        address to;
        // Ether value to be transferred in the transaction
        uint256 value;
        // Token address if the transaction involves an ERC20 token transfer.
        /// @dev If address(0) it means it is an ETH transaction not an ERC20 transaction.
        address token;
        // Number of approvals the transaction has received
        uint8 approvalCount;
        // Mapping of signer addresses to their approval status for this transaction
        mapping(address => bool) approvals;
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

    /*////////////////////////////////////////////////
                        Enums
    ////////////////////////////////////////////////*/

    /*////////////////////////////////////////////////
                        Events
    ////////////////////////////////////////////////*/

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

    /*////////////////////////////////////////////////
                        Modifiers
    ////////////////////////////////////////////////*/

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
        if (!s_signers[msg.sender]) revert OnlySigner();
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
        if (s_transactions[txHash].approvals[approver] == true)
            revert TransactionAlreadyApproved();
        _;
    }

    /// @dev Ensures the transaction is not already revoked by the given revoker.
    modifier txNotRevokedBy(bytes32 txHash, address revoker) {
        if (s_transactions[txHash].approvals[revoker] == false)
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
        if (s_transactions[txHash].approvalCount < s_minimumApprovalsRequired)
            revert TransactionLacksApprovals();
        _;
    }

    /*////////////////////////////////////////////////
                    Init functions
    ////////////////////////////////////////////////*/

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
    constructor(address[] memory _signers, uint256 _minimumApprovalsRequired) {
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
            if (s_signers[_signer] != false) revert DuplicateSigners();

            s_signers[_signer] = true;
        }
        s_minimumApprovalsRequired = _minimumApprovalsRequired;
    }

    /*////////////////////////////////////////////////
                    Internal functions
    ////////////////////////////////////////////////*/

    /*////////////////////////////////////////////////
                    External functions
    ////////////////////////////////////////////////*/
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
        if (token == address(0) && msg.value > 0) {
            emit Deposited(msg.sender, value);
        } else {
            bool success = IERC20(token).transferFrom(
                msg.sender,
                address(this),
                value
            );
            if (!success) revert DepositFailed();
            emit ERC20Deposited(msg.sender, address(token), value);
        }
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
        address to,
        uint value,
        address token
    ) external onlySigner nonReentrant {
        uint256 timestamp = block.timestamp;

        bool isTokenTransaction = token != address(0);

        bytes32 txHash = keccak256(
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
        _transaction.approvalCount = 0;
        _transaction.approvals[msg.sender] = true;
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
        transaction.approvals[msg.sender] = true;
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
        transaction.approvals[msg.sender] = false;
        delete transaction.approvals[msg.sender];
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

    /*////////////////////////////////////////////////
                    Getter functions
    ////////////////////////////////////////////////*/

    /// @dev Returns a transaction based on its hash
    function getTransaction(
        bytes32 txHash
    )
        public
        view
        returns (
            address to,
            uint256 value,
            address token,
            uint256 approvalCount,
            uint256 createdAt,
            uint256 executedAt,
            uint256 cancelledAt
        )
    {
        Transaction storage transaction = s_transactions[txHash];
        return (
            transaction.to,
            transaction.value,
            transaction.token,
            transaction.approvalCount,
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
