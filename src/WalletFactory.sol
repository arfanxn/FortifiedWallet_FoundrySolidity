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

    uint256 public constant MAX_WALLETS_PER_ACCOUNT = 10;

    /// @dev Mapping of signers to the wallets they have created.
    mapping(address signer => address[] wallets) private s_signerToWallets;

    struct WalletView {
        string name;
        address addr;
        address[] signers;
        uint256 minimumApprovals;
        uint256 totalBalanceInUsd;
    }

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

    function getWalletAddressesBySigner(
        address signer,
        uint256 offset,
        uint256 limit
    ) public view returns (address[] memory results) {
        address[] memory walletAddresses = s_signerToWallets[signer];
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
        if (walletAddress == address(0)) revert WalletDoesNotExist();
        walletView = WalletView({
            name: wallet.getName(),
            addr: walletAddress,
            signers: wallet.getSigners(),
            minimumApprovals: wallet.getMinimumApprovals(),
            totalBalanceInUsd: wallet.getTotalBalanceInUsd()
        });
    }

    function getWalletsBySigner(
        address signer,
        uint256 offset,
        uint256 limit
    ) public view returns (WalletView[] memory results) {
        address[] memory walletAddresses = s_signerToWallets[signer];
        uint256 walletAddressesLength = walletAddresses.length;

        uint256 available = walletAddressesLength > offset
            ? walletAddressesLength - offset
            : 0;

        uint256 size = available > limit ? limit : available;
        uint256 end = offset + limit;
        if (end > walletAddressesLength) end = walletAddressesLength;

        results = new WalletView[](size);
        uint256 resultsIndex = 0;

        for (uint256 i = offset; i < end; i++) {
            address walletAddress = walletAddresses[i];
            results[resultsIndex] = getWallet(payable(walletAddress));
            resultsIndex++;
        }
    }
}
