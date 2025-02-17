// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BaseTest} from "test/features/Base.t.sol";
import {WalletFactory} from "src/WalletFactory.sol";

contract WalletFactoryTest is BaseTest {
    WalletFactory public factory;

    function setUp() public override {
        super.setUp();

        factory = WalletFactory(config.getWalletFactory());
    }

    function testCreateWallet() public initAccounts(2) fundAccounts {
        // Create a new wallet with 2 signers
        address[] memory signers = new address[](2);
        signers[0] = _getMainAccount();
        signers[1] = accounts[1];

        // Set the minimum approvals required to 2
        uint256 minimumApprovals = 2;

        // Set the wallet name
        string memory walletName = "Fortified Wallet";

        // Create the wallet
        address walletAddress = factory.createWallet(
            walletName,
            signers,
            minimumApprovals
        );

        // Assert that the wallet address is not zero
        assertNotEq(
            walletAddress,
            address(0),
            "Wallet address should not be zero"
        );

        // Get the list of wallets created by the main account
        address[] memory actualWalletAddresses = factory
            .getWalletAddressesBySigner(_getMainAccount(), 0, 10);

        // Assert that the list has only one wallet
        assertEq(
            actualWalletAddresses.length,
            1,
            "Should have only one wallet"
        );

        // Get the first wallet in the list
        address actualWalletAddress = actualWalletAddresses[0];

        // Assert that the wallet address returned is the same as the one
        // created in the previous step
        assertEq(
            actualWalletAddress,
            walletAddress,
            "Wallet address should match the one created"
        );

        (
            string memory actualWalletName,
            ,
            address[] memory actualSigners,
            uint256 actualMinimumApprovals,
            uint256 actualWalletBalance
        ) = factory.getWallet(payable(walletAddress));

        // Assert that the wallet name is the same as the one set in the previous step
        assertEq(
            actualWalletName,
            walletName,
            "Wallet name should match the one set"
        );

        // Assert that the signers returned are the same as the ones set in the previous step
        assertEq(actualSigners, signers, "Signers should match the ones set");

        // Assert that the minimum approvals returned are the same as the ones set in the previous step
        assertEq(
            actualMinimumApprovals,
            minimumApprovals,
            "Minimum approvals should match the ones set"
        );

        // Assert that the total balance of the wallet is greater than or equal to 0
        assertGe(
            actualWalletBalance,
            0,
            "Total balance should be greater than or equal to 0"
        );
    }
}
