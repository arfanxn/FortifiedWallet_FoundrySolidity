// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {console2} from "forge-std/console2.sol";
import {PriceUtils} from "src/libraries/PriceUtils.sol";
import {IDynamicPriceConsumer} from "src/interfaces/IDynamicPriceConsumer.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {BaseTest} from "test/features/Base.t.sol";
import {Wallet} from "src/Wallet.sol";

contract WalletTest is BaseTest {
    Wallet public wallet;
    string public walletPassword;
    string public walletSalt;

    function setUp() public override {
        super.setUp();
    }

    modifier createWallet(
        string memory walletName,
        uint256 signersCount,
        uint256 minimumApprovals
    ) {
        // Create a new wallet with 2 signers
        address[] memory signers = new address[](signersCount);
        for (uint256 i = 0; i < signersCount; i++) {
            signers[i] = accounts[i];
        }

        walletPassword = "nueoRNm0xxEfCs6Hzu1v7qWyD9CB3y8W";
        walletSalt = "799PX8nKg18V5Ms2gXI5qnXCa5GZ6WF9";
        bytes32 passwordHash = keccak256(
            abi.encodePacked(walletPassword, walletSalt)
        );

        // Create the wallet
        address walletAddress = factory.createWallet(
            walletName,
            signers,
            minimumApprovals,
            passwordHash
        );

        wallet = Wallet(payable(walletAddress));

        assertNotEq(walletAddress, address(0));

        _;
    }

    function testLockUnlockBalance()
        public
        initAccounts(2)
        fundAccounts
        createWallet("", 2, 2)
    {
        address token = address(usdc);
        uint256 amount = 1000 * 10 ** usdc.decimals();
        uint256 amountInUsd = (amount / (10 ** usdc.decimals())) * 1e18;
        uint256 lockedAmountInUsd = amountInUsd / 2;
        uint256 unlockedAmountInUsd = amountInUsd - lockedAmountInUsd;

        vm.startPrank(_getMainAccount());
        usdc.approve(address(wallet), amount);
        wallet.deposit(token, amount);
        assertEq(usdc.balanceOf(address(wallet)), amount);
        assertEq(wallet.getTotalBalanceInUsd(), amountInUsd);
        vm.stopPrank();

        vm.prank(_getMainAccount());
        wallet.lockBalancedInUsd(lockedAmountInUsd);

        assertEq(wallet.getTotalLockedBalanceInUsd(), lockedAmountInUsd);
        assertEq(wallet.getTotalUnlockedBalanceInUsd(), unlockedAmountInUsd);

        vm.prank(_getMainAccount());
        wallet.unlockBalanceInUsd(
            lockedAmountInUsd,
            walletPassword,
            walletSalt
        );

        assertEq(wallet.getTotalLockedBalanceInUsd(), 0);
        assertEq(wallet.getTotalUnlockedBalanceInUsd(), amountInUsd);

        uint256 totalBalanceInUsd = wallet.getTotalBalanceInUsd();
        assertEq(totalBalanceInUsd, amountInUsd);
    }

    function testEthDeposit()
        public
        initAccounts(2)
        fundAccounts
        createWallet("", 2, 2)
    {
        address token = address(0);
        uint256 amount = 0.5 ether;

        // Assert that the wallet balance is initially 0
        assertEq(
            address(wallet).balance,
            0,
            "Wallet balance should be 0 initially"
        );

        // Deposit 1 ether into the wallet
        vm.prank(_getMainAccount());
        wallet.deposit{value: amount}(token, amount);

        // Assert that the wallet balance is now 1 ether
        assertEq(
            address(wallet).balance,
            amount,
            "Wallet balance should be equal to the deposited amount"
        );

        // Calculate the total balance in USD
        uint256 oneEthInUsd = 2600e18;
        uint256 totalBalanceInUsd = (oneEthInUsd * amount) / 1e18;

        // Assert that the wallet's total balance in USD is equal to the deposited amount
        assertEq(
            wallet.getTotalBalanceInUsd(),
            totalBalanceInUsd,
            "Wallet's total balance in USD should be equal to the deposited amount"
        );
    }

    function testTokensDeposit()
        public
        initAccounts(2)
        fundAccounts
        createWallet("", 2, 2)
    {
        // Set up the tokens that will be deposited into the wallet
        ERC20Mock[] memory tokens = new ERC20Mock[](2);
        tokens[0] = usdc;
        tokens[1] = mkr;

        // Set up the prices of the tokens
        uint256[] memory prices = new uint256[](2);
        prices[0] = 1 * 10 ** 18; // 1 USD
        prices[1] = 1000 * 10 ** 18; // 1000 USD

        // Set up the amounts of the tokens to be deposited
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1000 * 10 ** usdc.decimals(); // 1000 USDC
        amounts[1] = 5 * 10 ** mkr.decimals(); // 5 MKR

        // Set up the initial balances of the main account
        uint256[] memory initialBalances = new uint256[](2);
        initialBalances[0] = ACCOUNT_INITIAL_USDC;
        initialBalances[1] = ACCOUNT_INITIAL_MKR;

        uint256 expectedTotal = 0;
        for (uint256 i = 0; i < tokens.length; i++) {
            ERC20Mock token = tokens[i];
            uint256 price = prices[i];
            uint256 amount = amounts[i];
            uint256 initialBalance = initialBalances[i];

            assertEq(
                token.balanceOf(_getMainAccount()),
                initialBalance,
                "Main account's token balance should be equal to the initial amount"
            );
            assertEq(
                token.balanceOf(address(wallet)),
                0,
                "Wallet's token balance should be equal to 0 before deposit"
            );

            vm.startPrank(_getMainAccount());
            token.approve(address(wallet), amount); // Approve the wallet to spend the specified amount of token
            wallet.deposit(address(token), amount); // Deposit the approved token amount into the wallet
            // Stop the transaction
            vm.stopPrank();

            assertEq(
                token.balanceOf(address(wallet)),
                amount,
                "Wallet's token balance should be equal to the deposited amount"
            );
            assertEq(
                token.balanceOf(_getMainAccount()),
                initialBalance - amount,
                "Main account's token balance should be equal to the initial amount minus the deposited amount"
            );

            expectedTotal += (amount * price) / (10 ** token.decimals());
            assertEq(
                wallet.getTotalBalanceInUsd(),
                expectedTotal,
                "Wallet's total balance in USD should be equal to the deposited amount"
            );
        }

        address[] memory actualTokens = wallet.getTokenAddresses(0, 100, false);
        Wallet.TokenView[] memory actualTokenViews = wallet.getTokens(
            0,
            100,
            false
        );
        for (uint i = 0; i < tokens.length; i++) {
            address tokenAddress = address(tokens[i]);
            address actualTokenAddress = actualTokens[i];
            assertEq(actualTokenAddress, tokenAddress);

            Wallet.TokenView memory actualTokenView = actualTokenViews[i];
            assertEq(actualTokenView.addr, tokenAddress);
        }

        // Start the mock transaction as the main account
        vm.startPrank(_getMainAccount());

        // Remove the USDC token from the wallet
        wallet.removeToken(address(usdc));

        // Attempt to remove the USDC token again, expecting a revert because it no longer exists
        vm.expectRevert(Wallet.TokenNotAdded.selector);
        wallet.removeToken(address(usdc));

        // Add the USDC token back to the wallet
        wallet.addToken(address(usdc));

        // Attempt to add the USDC token again, expecting a revert because it already exists
        vm.expectRevert(Wallet.TokenAlreadyAdded.selector);
        wallet.addToken(address(usdc));

        // Stop the mock transaction
        vm.stopPrank();
    }

    function testCreateUnexecutedEthTransaction()
        public
        initAccounts(3)
        fundAccounts
        createWallet("", 2, 2)
    {
        address token = address(0); // Specify Ether as the token
        address to = accounts[2]; // Set recipient of the transaction
        uint256 amount = 1e18; // Define the transaction amount
        uint256 usdAmount = PriceUtils.getUsdValue(
            token,
            amount,
            IDynamicPriceConsumer(config.getPriceConsumer())
        );

        // Ensure initial balances are as expected
        assertEq(_getMainAccount().balance, ACCOUNT_INITIAL_ETH);
        assertEq(to.balance, ACCOUNT_INITIAL_ETH);

        // Start the transaction as the main account
        vm.startPrank(_getMainAccount());
        // Deposit Ether into the wallet
        wallet.deposit{value: amount}(token, amount);
        uint256 createdAt = block.timestamp; // Record the creation time
        // Create a new transaction
        bytes32 txHash = wallet.createTransaction(token, to, amount);
        vm.stopPrank();

        // Verify the transaction hash matches the last transaction's hash
        assertEq(wallet.getLastTransactionHash(), txHash);

        // Retrieve transaction details
        Wallet.TransactionView memory transactionView = wallet.getTransaction(
            txHash
        );

        // Assert transaction details are correct
        assertEq(transactionView.hash, txHash);
        assertEq(transactionView.token, token);
        assertEq(transactionView.to, to);
        assertEq(transactionView.value, amount);
        assertEq(transactionView.valueInUsd, usdAmount);
        assertEq(transactionView.approvalCount, 1);
        assertEq(transactionView.approvers.length, 1);
        assertEq(transactionView.approvers[0], _getMainAccount());
        assertEq(transactionView.createdAt, createdAt);
        assertEq(transactionView.executedAt, 0);
        assertEq(transactionView.cancelledAt, 0);

        // Check balances remain unchanged after transaction creation
        assertEq(_getMainAccount().balance, ACCOUNT_INITIAL_ETH - amount);
        assertEq(to.balance, ACCOUNT_INITIAL_ETH);
        assertNotEq(to.balance, ACCOUNT_INITIAL_ETH + amount);
    }

    /// @notice Tests creating multiple unexecuted transactions with different token addresses
    function testCreateMultipleUnexecutedTransactions()
        public
        initAccounts(3)
        fundAccounts
        createWallet("", 2, 2)
    {
        // Create an array of token addresses
        address[] memory tokenAddresses = new address[](4);
        tokenAddresses[0] = address(0);
        tokenAddresses[1] = address(weth);
        tokenAddresses[2] = address(usdc);
        tokenAddresses[3] = address(mkr);
        uint256 tokenAddressesLength = tokenAddresses.length;
        uint256 tokenAddressesLastIndex = tokenAddressesLength - 1;
        uint256 tokenAddressesIndex = 0;

        // Set the recipient of the transaction
        address to = accounts[2];
        uint256 createdTransactionsCount = 15;
        bytes32[] memory transactionHashes = new bytes32[](
            createdTransactionsCount
        );

        // Start the transaction as the main account
        vm.startPrank(_getMainAccount());
        // Iterate over the token addresses and create a transaction for each one
        for (uint256 i = 0; i < createdTransactionsCount; i++) {
            tokenAddressesIndex = tokenAddressesIndex > tokenAddressesLastIndex
                ? 0
                : tokenAddressesIndex;
            address tokenAddr = tokenAddresses[tokenAddressesIndex];
            uint256 randomAmount = (i + 1) * (10 ** 18);
            // Create a transaction with the current token address and increment the value by 1 ether
            transactionHashes[i] = wallet.createTransaction(
                tokenAddr,
                to,
                randomAmount
            );

            tokenAddressesIndex++;
        }
        // Stop the main account's transaction
        vm.stopPrank();

        // Get the newest transactions
        uint256 offset = 5;
        uint256 limit = 10;
        Wallet.TransactionView[] memory transactionViews = wallet
            .getNewestTransactions(offset, limit);
        uint256 transactionViewsLength = transactionViews.length;

        // Iterate over the transaction views and assert that the hash matches the expected hash
        for (
            uint256 i = transactionViewsLength - 1;
            i > (transactionViewsLength - offset);
            i--
        ) {
            Wallet.TransactionView memory transactionView = transactionViews[i];
            bytes32 expectedHash = transactionHashes[
                transactionHashes.length - 1 - (offset + i)
            ];
            assertEq(transactionView.hash, expectedHash);
        }
    }

    function testExecuteEthTransactionsLacksApprovals()
        public
        initAccounts(4)
        fundAccounts
        createWallet("", 3, 3)
    {
        address token = address(0);
        address to = accounts[3];
        uint256 amount = 1e18;

        vm.startPrank(_getMainAccount());
        wallet.deposit{value: amount}(token, amount);
        bytes32 txHash = wallet.createTransaction(token, to, amount);
        vm.stopPrank();

        // Approve the transaction with only one signers instead of two
        vm.prank(accounts[1]);
        wallet.approveTransaction(txHash);

        // Attempt to execute the transaction, expecting it to fail due to insufficient approvals
        vm.expectRevert(Wallet.TransactionLacksApprovals.selector);
        vm.startPrank(_getMainAccount());
        wallet.executeTransaction(txHash);
        vm.stopPrank();

        assertEq(address(wallet).balance, amount);
        assertEq(to.balance, ACCOUNT_INITIAL_ETH);
    }

    function testExecuteEthTransactionSuccess()
        public
        initAccounts(4)
        fundAccounts
        createWallet("", 3, 3)
    {
        address[] memory signers = wallet.getSigners();
        address token = address(0);
        address to = accounts[3];
        uint256 amount = 1e18;

        // Deposit Ether into the wallet
        vm.startPrank(_getMainAccount());
        wallet.deposit{value: amount}(token, amount);
        // Create a transaction in the wallet
        bytes32 txHash = wallet.createTransaction(token, to, amount);
        vm.stopPrank();

        // Approve the transaction with all the signers
        for (uint256 i = 1; i < signers.length; i++) {
            vm.prank(signers[i]);
            // Approve the transaction with each signer
            wallet.approveTransaction(txHash);
        }

        assertEq(
            address(wallet).balance,
            amount,
            "Wallet's balance should remain the same before execution"
        );
        assertEq(
            to.balance,
            ACCOUNT_INITIAL_ETH,
            "Recipient's balance should remain the same before execution"
        );

        // Execute the transaction
        vm.prank(_getMainAccount());
        wallet.executeTransaction(txHash);

        assertEq(
            address(wallet).balance,
            0,
            "Wallet's balance should be zero after execution"
        );
        assertEq(
            to.balance,
            ACCOUNT_INITIAL_ETH + amount,
            "Recipient's balance should be updated after execution"
        );
    }

    function testExecuteEthTransactionBalanceLocked()
        public
        initAccounts(4)
        fundAccounts
        createWallet("", 3, 3)
    {
        address[] memory signers = wallet.getSigners();
        address token = address(0);
        address to = accounts[3];
        uint256 amount = 1e18;
        uint256 usdAmount = PriceUtils.getUsdValue(
            token,
            amount,
            IDynamicPriceConsumer(config.getPriceConsumer())
        );

        // Deposit Ether into the wallet
        vm.startPrank(_getMainAccount());
        wallet.deposit{value: amount}(token, amount);
        // Create a transaction in the wallet
        bytes32 txHash = wallet.createTransaction(token, to, amount);
        vm.stopPrank();

        // Approve the transaction with all the signers
        for (uint256 i = 1; i < signers.length; i++) {
            vm.prank(signers[i]);
            // Approve the transaction with each signer
            wallet.approveTransaction(txHash);
        }

        assertEq(
            address(wallet).balance,
            amount,
            "Wallet's balance should remain the same before execution"
        );
        assertEq(
            to.balance,
            ACCOUNT_INITIAL_ETH,
            "Recipient's balance should remain the same before execution"
        );

        vm.startPrank(_getMainAccount());
        wallet.lockBalancedInUsd(usdAmount);
        vm.expectRevert(Wallet.TransactionInsufficientUnlockedBalance.selector);
        wallet.executeTransaction(txHash);
        vm.stopPrank();

        assertEq(
            address(wallet).balance,
            amount,
            "Wallet's balance should remain the same after execution due to InsufficientUnlockedBalance revert"
        );
        assertEq(
            to.balance,
            ACCOUNT_INITIAL_ETH,
            "Recipient's balance should remain the same after execution due to InsufficientUnlockedBalance revert"
        );
    }
}
