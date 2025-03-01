# Makefile for Foundry Solidity project

# Configuration
PROJECT_NAME := FortifiedWallet
FORGE := forge
TEST_FLAGS := -vvv # Default verbosity level
TEST_MATCH := # Add test pattern match with TEST_MATCH=TestName

# Load environment variables from .env file
# Include .env file and export all variables to be available to child processes
# Child processes are programs that are launched by the current process (make)
# and run in parallel. Examples include the $(FORGE) command.
-include .env
export

.PHONY: all install build clean test snapshot fmt lint coverage update analyze deploy verify help

all: install build test

# Install dependencies
install:
	@$(FORGE) install

# Build project
build:
	@$(FORGE) build

# Clean build artifacts
clean:
	@$(FORGE) clean

# Run tests
test:
	@$(FORGE) test $(TEST_FLAGS) $(if $(TEST_MATCH),--match-test $(TEST_MATCH),)

# Generate gas snapshot
snapshot:
	@$(FORGE) snapshot

# Format code
fmt:
	@$(FORGE) fmt

# Lint code (check formatting without changes)
lint:
	@$(FORGE) fmt --check

# Run coverage analysis
coverage:
	@$(FORGE) coverage

# Update dependencies
update:
	@$(FORGE) update

# Run static analysis (requires slither)
analyze:
	@slither ./src

# Deploy contracts (example - customize for your needs)
deploy:
	@$(FORGE) script script/Deployer.s.sol --broadcast --rpc-url $(RPC_URL) --private-key $(PRIVATE_KEY)

# Verify contract (example - customize for your needs)
verify:
	@$(FORGE) verify-contract <CONTRACT_ADDRESS> src/Contract.sol:Contract --chain-id 1 --etherscan-api-key <API_KEY>

# Show help
help:
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  all         Install dependencies, build, and test"
	@echo "  install     Install project dependencies"
	@echo "  build       Compile contracts"
	@echo "  clean       Remove build artifacts"
	@echo "  test        Run tests (use TEST_MATCH=Pattern to filter)"
	@echo "  snapshot    Generate gas usage snapshot"
	@echo "  fmt         Format source code"
	@echo "  lint        Check code formatting"
	@echo "  coverage    Generate coverage report"
	@echo "  update      Update dependencies"
	@echo "  analyze     Run static analysis (requires slither)"
	@echo "  deploy      Deploy contracts (customize for your project)"
	@echo "  verify      Verify contract on Etherscan (customize for your project)"
	@echo "  help        Show this help message"


get-wallet-factory-address:
	cast call ${HELPER_CONFIG_CONTRACT_ADDRESS} "getWalletFactory() returns (address)" \
	--rpc-url $(RPC_URL)

get-usdc-address: 
	cast call ${HELPER_CONFIG_CONTRACT_ADDRESS} "getToken(HelperConfig.Token) view returns(address)" \
	2 \
	--rpc-url $(RPC_URL)

# Deploy contracts (example - customize for your needs)
create-wallet:
	cast send $(WALLET_FACTORY_CONTRACT_ADDRESS) "createWallet(string, address[], uint256, bytes32)" \
	$(WALLET_NAME) $(WALLET_SIGNER_ADDRESSES) $(WALLET_MINIMUM_APPROVALS_REQUIRED) $(WALLET_PASSWORD_HASH) \
	--rpc-url $(RPC_URL) \
	--private-key $(PRIVATE_KEY)

get-wallet-addresses-by-signer:
	cast call $(WALLET_FACTORY_CONTRACT_ADDRESS) "getWalletAddressesBySigner(address signer, uint256 offset, uint256 limit) view returns(address[])" \
	$(PUBLIC_KEY) 0 10 \
	--rpc-url $(RPC_URL)

# Deposit ETH into wallet contract
# the `--value` parameter must match `value` (the amount ETH to send)
deposit-eth-to-wallet:
	cast send $(WALLET_CONTRACT_ADDRESS) "deposit(address,uint256)" \
	0x0000000000000000000000000000000000000000  \
	1000000000000000000 \
	--rpc-url $(RPC_URL) \
	--private-key $(PRIVATE_KEY) \
	--value 1000000000000000000  

# Deposit token into wallet contract
# the `--value` parameter must match `value` (the amount token to send (in this case USDC token))
# TODO: complete the target and fix the problem on depositing token
deposit-token-to-wallet:
	cast send $(WALLET_CONTRACT_ADDRESS) "deposit(address,uint256)" \
	0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48  \
	5000000 \
	--rpc-url $(RPC_URL) \
	--private-key $(PRIVATE_KEY) \

get-total-balance-in-usd:
	cast call $(WALLET_CONTRACT_ADDRESS) "getTotalBalanceInUsd() view returns(uint256)" \
	--rpc-url $(RPC_URL)


