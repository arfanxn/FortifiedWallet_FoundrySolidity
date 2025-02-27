// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PriceUtils} from "src/libraries/PriceUtils.sol";
import {IDynamicPriceConsumer} from "src/interfaces/IDynamicPriceConsumer.sol";
import {HelperConfig} from "src/HelperConfig.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

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

    // Errors related to wallet configuration
    error InsufficientSigners();
    error ExcessiveSigners(); // Error when the number of signers exceeds the allowed limit
    error DuplicateSigners();
    error OnlySigner();
    error InvalidPasswordHashLength();
    error PasswordHashMismatch();

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
    error TransactionInsufficientBalance();
    error TransactionInsufficientUnlockedBalance();
    error TransactionFailed();

    //==============================================================
    //                           Libraries
    //==============================================================
    using SafeERC20 for IERC20;

    //==============================================================
    //                       State variables
    //==============================================================

    uint256 public constant MIN_SIGNERS_REQUIRED = 2;
    uint256 public constant MAX_SIGNERS_ALLOWED = 10;

    /// @dev The name of the wallet
    string private s_name;
    /// @dev Mapping of signer addresses to their signer status
    mapping(address => bool) private s_isSigner;
    /// @dev The signers of the wallet
    address[] private s_signers;
    /// @dev The minimum number of approvals required to execute a transaction
    uint256 private s_minimumApprovals;
    /// @dev Hash of the password used for wallet authentication
    bytes32 private s_passwordHash;
    /// @dev Stores the tokens that the wallet is holding
    address[] private s_tokens;
    /// @dev Tracks existing tokens to avoid duplicates
    mapping(address => bool) private s_tokenExists;
    /// @dev Tracks the total locked balance of the wallet in USD
    uint256 private s_totalLockedBalanceInUsd;

    /// @notice Represents a transaction to be executed by the wallet
    struct TransactionStorage {
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

    /// @notice Structure containing detailed information about a specific transaction
    /// @dev This structure is used by the wallet to provide comprehensive transaction data
    struct TransactionView {
        /// @notice Unique identifier for the transaction
        bytes32 hash;
        /// @notice Address of the ERC20 token involved in the transaction, or address(0) for ETH
        address token;
        /// @notice Recipient address for the transaction
        address to;
        /// @notice Amount of Ether or tokens to be transferred
        uint256 value;
        /// @notice Number of approvals the transaction has received
        uint8 approvalCount;
        /// @notice List of addresses that have approved the transaction
        address[] approvers;
        /// @notice Timestamp when the transaction was created
        uint256 createdAt;
        /// @notice Timestamp when the transaction was executed
        uint256 executedAt;
        /// @notice Timestamp when the transaction was cancelled
        uint256 cancelledAt;
    }

    /// @dev Maps transaction hashes to their respective transactions
    mapping(bytes32 => TransactionStorage) private s_transactions;
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
    event WalletBalanceLocked(address indexed signer, uint256 usdAmount);
    event WalletBalanceUnlocked(address indexed signer, uint256 usdAmount);

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

    modifier verifyPassword(string memory password, string memory salt) {
        bytes32 passwordHash = keccak256(abi.encodePacked(password, salt));
        if (passwordHash != s_passwordHash) revert PasswordHashMismatch();
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
        string memory _name,
        address[] memory _signers,
        uint256 _minimumApprovalsRequired,
        bytes32 _passwordHash
    ) {
        config = _config;
        s_name = _name;
        uint256 signersLength = _signers.length;
        if (signersLength < MIN_SIGNERS_REQUIRED) revert InsufficientSigners();
        // Limiting the number of signers to 10 is a trade-off between decentralization
        // and gas efficiency. With more than 10 signers, the cost of creating a new
        // transaction would be prohibitive. Given that the wallet is intended to be
        // used by a small group of trusted parties, 10 signers should be sufficient.
        if (signersLength > MAX_SIGNERS_ALLOWED) revert ExcessiveSigners();
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
        s_passwordHash = _passwordHash;
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
            IERC20(token).safeTransferFrom(msg.sender, address(this), value);
            emit ERC20Deposited(msg.sender, address(token), value);
        }

        // Add the token to the array of tokens if it has not already been added.
        // This is used to keep track of all the tokens that have been deposited
        // into the wallet.
        if (!s_tokenExists[token]) {
            s_tokenExists[token] = true;
            s_tokens.push(token);
        }
    }

    /**
     * @notice Locks a specified amount of USD in the wallet.
     * @param usdAmount The amount of USD to lock.
     * @dev The total locked balance cannot exceed the maximum uint256 value.
     */
    function lockBalancedInUsd(
        uint256 usdAmount
    ) external onlySigner nonReentrant {
        // If usdAmount is the maximum uint256 value, lock the entire wallet balance.
        // Otherwise, add usdAmount to the total locked balance.
        if (usdAmount >= type(uint256).max) {
            // Set the total locked balance to the entire wallet balance.
            usdAmount = getTotalBalanceInUsd();
            s_totalLockedBalanceInUsd = usdAmount;
        } else {
            // Add usdAmount to the total locked balance.
            s_totalLockedBalanceInUsd += usdAmount;
        }
        // Emit an event to notify that the wallet balance has been locked.
        emit WalletBalanceLocked(msg.sender, usdAmount);
    }

    /**
     * @notice Unlocks a specified amount of USD in the wallet.
     * @param usdAmount The amount of USD to unlock.
     * @dev The total locked balance cannot be less than zero.
     */
    function unlockBalanceInUsd(
        uint256 usdAmount,
        string memory password,
        string memory salt
    ) external onlySigner nonReentrant verifyPassword(password, salt) {
        // If usdAmount is greater than or equal to the total locked balance,
        // or if usdAmount is the maximum uint256 value, unlock the entire
        // locked balance.
        // Otherwise, subtract usdAmount from the total locked balance.
        if (
            usdAmount >= type(uint256).max ||
            usdAmount >= s_totalLockedBalanceInUsd
        ) {
            // Unlock the entire locked balance.
            usdAmount = s_totalLockedBalanceInUsd;
            s_totalLockedBalanceInUsd = 0;
        } else {
            // Subtract usdAmount from the total locked balance.
            s_totalLockedBalanceInUsd -= usdAmount;
        }
        // Emit an event to notify that the wallet balance has been unlocked.
        emit WalletBalanceUnlocked(msg.sender, usdAmount);
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

        bool isEtherTransaction = token == address(0);

        txHash = keccak256(
            abi.encode(
                isEtherTransaction ? address(0) : token,
                to,
                isEtherTransaction ? 0 : value,
                timestamp
            )
        );
        TransactionStorage storage _transaction = s_transactions[txHash];

        _transaction.hash = txHash;
        _transaction.to = to;
        _transaction.value = value;
        _transaction.token = isEtherTransaction ? address(0) : token; // `address(0)` Indicates Ether transfer
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
        TransactionStorage storage transaction = s_transactions[txHash];
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
        TransactionStorage storage transaction = s_transactions[txHash];
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
        TransactionStorage storage transaction = s_transactions[txHash];
        transaction.cancelledAt = block.timestamp;

        emit TransactionCancelled(txHash, msg.sender);
    }
    /// @notice Execute a transaction.
    /// @param txHash The hash of the transaction to be executed.
    /// @dev This function can be used to execute a transaction if it has not
    /// been executed yet and has enough approvals.
    /// @notice Only a signer of the transaction can execute it.
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
        TransactionStorage storage transaction = s_transactions[txHash];
        transaction.executedAt = timestamp;

        // Check if the transaction is an ERC20 token transfer
        bool isEtherTransaction = transaction.token == address(0);

        // Fetch the balance of the token or ether in the contract
        uint256 balance = isEtherTransaction
            ? address(this).balance // For ETH transactions, use the contract's ether balance
            : IERC20(transaction.token).balanceOf(address(this));
        if (balance < transaction.value)
            revert TransactionInsufficientBalance();

        // Fetch the price consumer instance to use to fetch the price feed
        IDynamicPriceConsumer priceConsumer = IDynamicPriceConsumer(
            config.getPriceConsumer()
        );

        // Calculate the wallet total balance in USD
        uint256 totalBalanceInUsd = getTotalBalanceInUsd();

        // Calculate the wallet total locked balance in USD
        uint256 totalLockedBalanceInUsd = s_totalLockedBalanceInUsd;

        // Calculate the wallet total unlocked balance in USD
        uint256 totalUnlockedBalanceInUsd = totalLockedBalanceInUsd >
            totalBalanceInUsd
            ? 0
            : totalBalanceInUsd - totalLockedBalanceInUsd;

        // Calculate the USD value of the transaction
        uint256 valueInUsd = PriceUtils.getUsdValue(
            transaction.token,
            transaction.value,
            priceConsumer
        );

        // Revert if the transaction value exceeds the unlocked balance
        if (valueInUsd > totalUnlockedBalanceInUsd)
            revert TransactionInsufficientUnlockedBalance();

        // Execute the transaction based on its type
        if (isEtherTransaction) {
            // For ETH transactions, call the recipient address with the specified value
            (bool success, ) = transaction.to.call{value: transaction.value}(
                ""
            );
            // Revert if the transaction fails
            if (!success) revert TransactionFailed();
        } else {
            // For ERC20 transactions, transfer the specified amount to the recipient address
            SafeERC20.safeTransfer(
                IERC20(transaction.token),
                transaction.to,
                transaction.value
            );
            // Revert if the transaction fails
            // if (!success) revert TransactionFailed();
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
        TransactionStorage storage transaction = s_transactions[txHash];
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
    function getTotalBalanceInUsd() public view returns (uint256 usdTotal) {
        address[] memory tokens = s_tokens;
        uint256 tokensLength = tokens.length;
        for (uint256 i = 0; i < tokensLength; i++) {
            address token = tokens[i];
            bool isEtherToken = token == address(0);

            uint256 balance = isEtherToken
                ? address(this).balance
                : IERC20(token).balanceOf(address(this));

            IDynamicPriceConsumer priceConsumer = IDynamicPriceConsumer(
                config.getPriceConsumer()
            );
            uint256 usdValue = PriceUtils.getUsdValue(
                token,
                balance,
                priceConsumer
            );
            usdTotal += usdValue;
        }

        return usdTotal;
    }

    function getTotalLockedBalanceInUsd() public view returns (uint256) {
        return s_totalLockedBalanceInUsd;
    }

    function getTotalUnlockedBalanceInUsd() public view returns (uint256) {
        if (s_totalLockedBalanceInUsd > getTotalBalanceInUsd()) return 0;
        uint256 totalUnlockedBalanceInUsd = (getTotalBalanceInUsd() -
            s_totalLockedBalanceInUsd);
        return totalUnlockedBalanceInUsd;
    }

    function getSigners() public view returns (address[] memory) {
        return s_signers;
    }

    /**
     * @dev Returns a transaction based on its hash
     * @param txHash The hash of the transaction to retrieve
     * @return transactionView The transaction details
     */
    function getTransaction(
        bytes32 txHash
    ) public view returns (TransactionView memory transactionView) {
        // Retrieves a transaction based on its hash and returns a TransactionView
        // If the transaction does not exist, it will revert with TransactionDoesNotExist
        TransactionStorage storage transaction = s_transactions[txHash];
        if (transaction.hash == bytes32(0)) revert TransactionDoesNotExist();

        address[] memory approvers = _getTransactionApprovers(txHash);
        transactionView = TransactionView({
            hash: txHash,
            token: transaction.token,
            to: transaction.to,
            value: transaction.value,
            approvalCount: transaction.approvalCount,
            approvers: approvers,
            createdAt: transaction.createdAt,
            executedAt: transaction.executedAt,
            cancelledAt: transaction.cancelledAt
        });
    }

    function getNewestTransactions(
        uint256 offset,
        uint256 limit
    ) public view returns (TransactionView[] memory results) {
        uint256 transactionHashesLength = s_transactionHashes.length;

        // Calculate available transactions after applying the offset
        uint256 available = transactionHashesLength > offset
            ? transactionHashesLength - offset
            : 0;

        // Determine the actual number of transactions to return
        uint256 size = available > limit ? limit : available;

        results = new TransactionView[](size);

        // Fetch transactions in reverse order (newest first)
        for (uint256 i = 0; i < size; i++) {
            // Calculate index: start from the end, apply offset, and iterate backward
            uint256 index = transactionHashesLength - offset - i - 1;

            // Gracefully handle invalid indices by returning empty
            if (index >= transactionHashesLength) {
                return new TransactionView[](0);
            }

            bytes32 transactionHash = s_transactionHashes[index];
            results[i] = getTransaction(transactionHash);
        }
    }

    /// @dev Returns the hash of the most recently created transaction
    function getLastTransactionHash() public view returns (bytes32) {
        return s_lastTransactionHash;
    }
}
