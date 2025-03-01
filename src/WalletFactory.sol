// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {HelperConfig} from "src/HelperConfig.sol";
import {Wallet} from "src/Wallet.sol";

contract WalletFactory {
    error WalletDoesNotExist();
    /// @notice Error thrown when a user attempts to create more than the maximum
    /// allowed number of wallets.
    error WalletExceededMaximum();

    HelperConfig private immutable config;

    struct SignerWalletRegistry {
        address[] ownedWallets; // Wallets directly owned/created by the signer
        address[] associatedWallets; // Wallets related to but not owned by the signer
        address[] allWallets; // Combined list of both owned and associated wallets
    }

    uint256 public constant MAX_OWNED_WALLETS_PER_ACCOUNT = 10;

    /// @dev Mapping of signers to a registry that tracks the wallets they have created,
    /// associated with, and all wallets (combination of both) they have any connection to.
    mapping(address signer => SignerWalletRegistry)
        private s_signerToWalletRegistry;

    /// @dev Mapping of signers to the wallets they have created.
    // mapping(address signer => address[] wallets) private s_signerToWallets;

    /// @dev Mapping of wallets to boolean values indicating whether or not the
    /// wallet exists.
    mapping(address wallet => bool) private s_walletExists;

    struct WalletView {
        string name;
        address addr;
        address[] signers;
        uint256 minimumApprovals;
        uint256 totalBalanceInUsd;
    }

    /// @notice Event emitted when a new wallet is created
    event WalletCreated(address indexed wallet, address[] signers);

    constructor(HelperConfig _config) {
        config = _config;
    }

    /**
     * @notice Creates a new wallet with the specified name, signers and minimum approvals required.
     * @param name The name of the wallet to create.
     * @param signers The array of signers associated with the wallet.
     * @param minimumApprovalsRequired The minimum approvals required for a transaction to be executed.
     * @return The address of the newly created wallet.
     */
    function createWallet(
        string memory name,
        address[] memory signers,
        uint256 minimumApprovalsRequired,
        bytes32 passwordHash
    ) public returns (address) {
        address mainSigner = signers[0];
        uint256 ownedWalletCount = getOwnedWalletCountForSigner(mainSigner);
        if (ownedWalletCount >= MAX_OWNED_WALLETS_PER_ACCOUNT)
            revert WalletExceededMaximum();

        // Create a new Wallet instance
        Wallet wallet = new Wallet(
            config,
            name,
            signers,
            minimumApprovalsRequired,
            passwordHash
        );
        s_walletExists[address(wallet)] = true;

        _setSignerToWalletRegistry(mainSigner, signers, address(wallet));

        // Emit the WalletCreated event
        emit WalletCreated(address(wallet), signers);

        // Return the address of the newly created wallet
        return address(wallet);
    }

    /**
     * @dev Internal function to set the signer to wallet registry.
     *      This function is used by the createWallet function to set the
     *      signer to wallet registry.
     * @param mainSigner The main signer of the wallet.
     * @param signers The array of signers associated with the wallet.
     * @param walletAddress The address of the wallet.
     */
    function _setSignerToWalletRegistry(
        address mainSigner,
        address[] memory signers,
        address walletAddress
    ) private {
        // Add the wallet to the main signer's owned wallets registry
        s_signerToWalletRegistry[mainSigner].ownedWallets.push(walletAddress);

        // Iterate over the signers array and add the wallet to each signer's registry
        for (uint256 i = 0; i < signers.length; i++) {
            address signer = signers[i];

            // If the signer is not the main signer, add the wallet to the associated wallets registry
            if (signer != mainSigner) {
                s_signerToWalletRegistry[signer].associatedWallets.push(
                    walletAddress
                );
            }

            // Add the wallet to the all wallets registry for the signer
            s_signerToWalletRegistry[signer].allWallets.push(walletAddress);
        }
    }

    ///=============================================================
    //                      Getter functions
    //==============================================================

    function getOwnedWalletCountForSigner(
        address signer
    ) public view returns (uint256) {
        return s_signerToWalletRegistry[signer].ownedWallets.length;
    }

    function getAssociatedWalletCountForSigner(
        address signer
    ) public view returns (uint256) {
        return s_signerToWalletRegistry[signer].associatedWallets.length;
    }

    function getAllWalletCountForSigner(
        address signer
    ) public view returns (uint256) {
        return s_signerToWalletRegistry[signer].allWallets.length;
    }

    function getWalletAddressesBySigner(
        address signer,
        uint256 offset,
        uint256 limit
    ) public view returns (address[] memory results) {
        address[] memory walletAddresses = s_signerToWalletRegistry[signer]
            .allWallets;
        uint256 walletAddressesLength = walletAddresses.length;

        uint256 available = walletAddressesLength > offset
            ? walletAddressesLength - offset
            : 0;

        uint256 size = available > limit ? limit : available;
        uint256 end = offset + limit;
        if (end > walletAddressesLength) end = walletAddressesLength;

        results = new address[](size);
        uint256 resultsIndex = 0;

        for (uint256 i = offset; i < end; i++) {
            address walletAddress = walletAddresses[i];
            results[resultsIndex] = walletAddress;
            resultsIndex++;
        }
    }

    /**
     * @notice Returns a WalletView object of the wallet at the specified address
     * @param walletAddress The address of the wallet to retrieve
     * @return walletView The WalletView object of the wallet at the specified address
     */
    function getWallet(
        address payable walletAddress
    ) public view returns (WalletView memory walletView) {
        Wallet wallet = Wallet(walletAddress);
        if (walletAddress == address(0) || !s_walletExists[walletAddress])
            revert WalletDoesNotExist();
        walletView = WalletView({
            name: wallet.getName(),
            addr: walletAddress,
            signers: wallet.getSigners(),
            minimumApprovals: wallet.getMinimumApprovals(),
            totalBalanceInUsd: wallet.getTotalBalanceInUsd()
        });
    }

    /**
     * @notice Retrieves the newest wallets created by a specified signer,
     *         in reverse order (newest first) based on the specified offset and limit.
     * @param signer The address of the signer whose wallets are to be retrieved.
     * @param offset The starting index from which to begin fetching wallets.
     * @param limit The maximum number of wallets to retrieve.
     * @return results An array of WalletView objects representing the retrieved wallets.
     */
    function getNewestWalletsBySigner(
        address signer,
        uint256 offset,
        uint256 limit
    ) public view returns (WalletView[] memory results) {
        address[] memory walletAddresses = s_signerToWalletRegistry[signer]
            .allWallets;
        uint256 walletAddressesLength = walletAddresses.length;

        uint256 available = walletAddressesLength > offset
            ? walletAddressesLength - offset
            : 0;

        uint256 size = available > limit ? limit : available;
        results = new WalletView[](size);

        for (uint256 i = 0; i < size; i++) {
            uint256 index = walletAddressesLength - offset - i - 1;
            if (index >= walletAddressesLength) {
                return new WalletView[](0);
            }
            address walletAddress = walletAddresses[index];
            results[i] = getWallet(payable(walletAddress));
        }
    }
}
