# Fortified Wallet

## Overview

Fortified Wallet is a decentralized wallet application designed to provide users with a secure and efficient way to manage their digital assets. This project is built using Solidity and Foundry, leveraging smart contracts to facilitate wallet functionalities.

## Features

-   **Multi-signature Wallet**: Supports multiple signers for enhanced security.
-   **Token Management**: Allows users to manage various tokens including WETH, MUSDC, and MMKR.
-   **Price Feeds**: Integrates price feeds for real-time token pricing.
-   **Deployment Scripts**: Includes scripts for local deployment using Foundry.

## Getting Started

### Prerequisites

-   Node.js (version 14 or higher)
-   Foundry for smart contract development
-   Anvil for local blockchain testing

### Installation

1. Clone the repository:
    ```bash
    git clone https://github.com/arfanxn/FortifiedWallet_FoundrySolidity.git
    cd FortifiedWallet_FoundrySolidity
    ```
2. Install dependencies:
    ```bash
    make install
    ```
3. Set up your environment variables:
    - Copy `.env.example` to `.env` and fill in the required values.
    - Ensure you have the correct RPC URL and private keys for deployment.

## Running the Application

1. Start the local blockchain using Anvil:
    ```bash
    anvil
    ```
2. Deploy the contracts:
    ```bash
    make deploy
    ```
3. Interact with the wallet through the provided interfaces or scripts or Makefile commands.

## Configuration

The application uses a `.env` file for configuration. Below are the key environment variables:

-   `APP_NAME`: Name of the application.
-   `APP_ENV`: Environment of the application.
-   `RPC_URL`: URL for the local blockchain (default: `http://127.0.0.1:8545`).
-   `PUBLIC_KEY`: Public key for the wallet.
-   `PRIVATE_KEY`: Private key for the wallet.
-   `CONTRACT_REGISTRY`: Address of the contract registry.
-   `TOKEN_REGISTRY`: Address of the token registry.
-   `PRICE_FEED_REGISTRY`: Address of the price feed registry.
-   `WALLET_FACTORY`: Address of the wallet factory contract.

## Testing

To run tests, use the following command:

```bash
make test
```

## Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository.
2. Create a new branch: `git checkout -b feature/your-feature`.
3. Make your changes and commit them: `git commit -m 'Add some feature'`.
4. Push to the branch: `git push origin feature/your-feature`.
5. Create a new Pull Request.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## Acknowledgments

-   [Foundry](https://getfoundry.sh/) for providing a robust framework for smart contract development.
-   [OpenZeppelin](https://openzeppelin.com/) for their secure smart contract libraries.
