// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {HelperConfig} from "src/HelperConfig.sol";
import {Wallet} from "src/Wallet.sol";

contract WalletFactory {
    /// @notice Error thrown when a user attempts to create more than the maximum
    /// allowed number of wallets.
    error WalletExceededMaximum();

    HelperConfig private immutable config;

    uint256 constant MAX_WALLETS_PER_ACCOUNT = 10;

    /// @dev Mapping of signers to the wallets they have created.
    mapping(address signer => address[] wallets) private s_signerToWallets;

    /// @dev Event emitted when a new wallet is created
    event WalletCreated(address indexed wallet, address[] signers);

    constructor(HelperConfig _config) {
        config = _config;
    }

    /**
     * @notice Creates a new wallet with the specified name, signers and minimum approvals required.
     * @param name The name of the wallet to create.
     * @param _signers The array of signers associated with the wallet.
     * @param _minimumApprovalsRequired The minimum approvals required for a transaction to be executed.
     * @return The address of the newly created wallet.
     */
    function createWallet(
        string memory name,
        address[] memory _signers,
        uint256 _minimumApprovalsRequired
    ) public returns (address) {
        address mainSigner = _signers[0];
        uint256 walletsLength = s_signerToWallets[mainSigner].length;
        if (walletsLength >= MAX_WALLETS_PER_ACCOUNT)
            revert WalletExceededMaximum();

        // Create a new Wallet instance
        Wallet wallet = new Wallet(
            config,
            name,
            _signers,
            _minimumApprovalsRequired
        );

        for (uint256 i = 0; i < _signers.length; i++) {
            address signer = _signers[i];
            s_signerToWallets[signer].push(address(wallet));
        }

        // Emit the WalletCreated event
        emit WalletCreated(address(wallet), _signers);

        // Return the address of the newly created wallet
        return address(wallet);
    }

    ///==============================================================
    //                      Getter functions
    //==============================================================

    /// @notice Retrieves the list of wallet addresses created by a specific signer.
    /// @param signer The address of the signer whose wallets are being queried.
    /// @param offset The starting index in the wallet list from which to retrieve wallet addresses.
    /// @param limit The maximum number of wallet addresses to retrieve.
    /// @return walletAddressResults An array of wallet addresses created by the specified signer.
    function getWalletAddressesBySigner(
        address signer,
        uint256 offset,
        uint256 limit
    ) public view returns (address[] memory walletAddressResults) {
        // Initialize the return array with the specified limit
        walletAddressResults = new address[](limit);

        // Get the array of wallets associated with the specified signer
        address[] memory walletAddresses = s_signerToWallets[signer];

        // Get the length of the array of wallets
        uint256 walletAddressesLength = walletAddresses.length;

        // Calculate the end index of the slice of the array of wallets to return
        // If the end index exceeds the length of the array, set it to the length
        uint256 end = offset + limit;
        if (end > walletAddressesLength) end = walletAddressesLength;

        // Initialize the index of the return array
        uint256 walletAddressResultsIndex = 0;

        // Iterate over the slice of the array of wallets from the offset to the end index
        for (uint256 i = offset; i < end; i++) {
            // Set the wallet address at the current index of the return array
            // to the wallet address at the current index of the array of wallets
            walletAddressResults[walletAddressResultsIndex] = walletAddresses[
                i
            ];

            // Increment the index of the return array
            walletAddressResultsIndex++;
        }

        // Set the length of the return array to the number of wallet addresses
        // that were actually set
        assembly {
            mstore(walletAddressResults, walletAddressResultsIndex)
        }

        // Return the array of wallet addresses
        return walletAddressResults;
    }

    /// @notice Retrieves the details of a wallet given its address.
    /// @param _address The address of the wallet to retrieve details for.
    /// @return walletName The name of the wallet.
    /// @return walletAddress The address of the wallet.
    /// @return signers The array of signers associated with the wallet.
    /// @return minimumApprovals The minimum approvals required for the wallet.
    /// @return totalBalance The total balance of the wallet in USD, scaled to 1e18.
    function getWallet(
        address payable _address
    )
        public
        view
        returns (
            string memory walletName,
            address walletAddress,
            address[] memory signers,
            uint256 minimumApprovals,
            uint256 totalBalance
        )
    {
        Wallet wallet = Wallet(_address);
        walletAddress = _address;
        walletName = wallet.getName();
        signers = wallet.getSigners();
        minimumApprovals = wallet.getMinimumApprovals();
        totalBalance = wallet.getTotalBalance();
    }
}
