// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {HelperConfig} from "src/HelperConfig.sol";
import {Wallet} from "src/Wallet.sol";

contract WalletFactory {
    HelperConfig private immutable config;

    /// @dev Mapping of signers to the wallets they have created.
    mapping(address signer => address[] wallets) private s_signerToWallets;

    /// @dev Event emitted when a new wallet is created
    event WalletCreated(address indexed wallet, address[] signers);

    constructor(HelperConfig _config) {
        config = _config;
    }

    function createWallet(
        string memory name,
        address[] memory _signers,
        uint256 _minimumApprovalsRequired
    ) public returns (address) {
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

    /// @notice Retrieves the array of wallets associated with a particular signer.
    function getWalletAddressesBySigner(
        address signer
    ) public view returns (address[] memory) {
        return s_signerToWallets[signer];
    }

    /// @notice Retrieves the details of a wallet given its address.
    /// @param _address The address of the wallet to retrieve details for.
    /// @return walletName The name of the wallet.
    /// @return walletAddress The address of the wallet.
    /// @return signers The array of signers associated with the wallet.
    /// @return minimumApprovals The minimum approvals required for the wallet.
    /// @return totalBalance The total balance of the wallet in USD, scaled to 1e18.
    function getWalletDetails(
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
