// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "src/Wallet.sol";

contract WalletFactory {
    /// @dev Mapping of signers to the wallets they have created.
    mapping(address signer => address[] wallets) private s_signerToWallets;

    /// @dev Event emitted when a new wallet is created
    event WalletCreated(address indexed wallet, address[] signers);

    // Function to create a new Wallet instance
    function createWallet(
        address[] memory _signers,
        uint256 _minimumApprovalsRequired
    ) public returns (address) {
        // Create a new Wallet instance
        Wallet wallet = new Wallet(_signers, _minimumApprovalsRequired);

        for (uint256 i = 0; i < _signers.length; i++) {
            address signer = _signers[i];
            s_signerToWallets[signer].push(address(wallet));
        }

        // Emit the WalletCreated event
        emit WalletCreated(address(wallet), _signers);

        // Return the address of the newly created wallet
        return address(wallet);
    }

    /*////////////////////////////////////////////////
                    Getter functions
    ////////////////////////////////////////////////*/

    /// @dev Returns the list of wallets created by a given signer.
    function getWallets(address signer) public view returns (address[] memory) {
        return s_signerToWallets[signer];
    }
}
