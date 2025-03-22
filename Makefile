# Makefile for Foundry Solidity project - "Fortified Wallet"

# Project Configuration
PROJECT_NAME := "Fortified Wallet"          # Name of the project
FORGE := forge                           # Forge command alias
TEST_FLAGS := -vvv                       # Default test verbosity level (verbose)
TEST_MATCH :=                            # Test filter pattern (e.g. TEST_MATCH=ContractTest)
RANDOM_STRING := $(shell openssl rand -base64 12 | tr -dc 'A-Za-z0-9' | head -c 16) # Random string generator for wallet names

# Argument placeholders for parameterized targets
ARG1 := 
ARG2 :=
ARG3 :=
ARG4 :=

# Environment Configuration
# Load and export all variables from .env file to make them available to subprocesses
-include .env
export

# PHONY Targets Declaration
.PHONY: all install build clean test snapshot fmt lint coverage update analyze \
        deploy verify help get-contract get-mock-multicall3 get-token-registry \
        get-price-feed-registry get-wallet-factory get-token get-price-feed \
        create-wallet get-wallets-by-signer deposit-eth approve-token deposit-token \
        get-token-views get-total-balance-in-usd guard-%

# Helper target to enforce required environment variables
guard-%:
	@if [ -z '${${*}}' ]; then \
		echo "ERROR: Variable '$*' is required!"; \
		exit 1; \
	fi

# Default target - install dependencies, build, and test
all: install build test

# Install project dependencies using Forge
install:
	@echo "🚀 Installing project dependencies..."
	@$(FORGE) install

# Build the project and compile Solidity contracts
build:
	@echo "🚀 Building project..."
	@$(FORGE) build

# Clean build artifacts and cache
clean:
	@echo "🚀 Cleaning build artifacts..."
	@$(FORGE) clean

# Run tests with optional filter pattern (use TEST_MATCH to filter specific tests)
test:
	@echo "🚀 Running tests..."
	@$(FORGE) test $(TEST_FLAGS) $(if $(TEST_MATCH),--match-test $(TEST_MATCH),)

# Generate gas usage snapshot for test cases
snapshot:
	@echo "🚀 Generating gas snapshot..."
	@$(FORGE) snapshot

# Format Solidity code according to style guide
fmt:
	@echo "🚀 Formatting code..."
	@$(FORGE) fmt

# Check code formatting without making changes
lint:
	@echo "🚀 Linting code..."
	@$(FORGE) fmt --check

# Generate test coverage report
coverage:
	@echo "🚀 Generating coverage report..."
	@$(FORGE) coverage

# Update project dependencies
update:
	@echo "🚀 Updating dependencies..."
	@$(FORGE) update

# Run static analysis using Slither (requires slither installed)
analyze:
	@echo "🚀 Running static analysis..."
	@slither ./src

# Deploy contracts to specified network (requires APP_ENV)
# Supported environments: local, dev, prod
deploy: guard-APP_ENV
ifeq ($(APP_ENV),local)
	@echo "🚀 Deploying to local network..."
	@$(FORGE) script $(DEPLOYER_SCRIPT_PATH) --broadcast --rpc-url $(RPC_URL) --private-key $(PRIVATE_KEY)
else ifeq ($(APP_ENV),dev)
	@echo "🚀 Deploying to development network..."
	@$(FORGE) script $(DEPLOYER_SCRIPT_PATH) --broadcast --rpc-url $(RPC_URL) --private-key $(PRIVATE_KEY)
else ifeq ($(APP_ENV),prod)
	@echo "🚀 Deploying to production network..."
	@$(FORGE) script $(DEPLOYER_SCRIPT_PATH) --broadcast --rpc-url $(RPC_URL) --private-key $(PRIVATE_KEY)
else
	@echo "❌ Invalid APP_ENV: $(APP_ENV). Use 'local', 'dev', or 'prod'."
	@exit 1
endif

# Verify contract on Etherscan (example - customize with your contract details)
verify:
	@echo "🚀 Verifying contract..."
	@$(FORGE) verify-contract <CONTRACT_ADDRESS> src/Contract.sol:Contract --chain-id 1 --etherscan-api-key <API_KEY>

# Get contract address from registry (ARG1=contract name)
get-contract: guard-ARG1
	@echo "🚀 Retrieving contract address for '$(ARG1)'..."
	@cast call ${CONTRACT_REGISTRY} "getContract(string name) returns (address)" \
	$(ARG1) \
	--rpc-url $(RPC_URL)

# Get MockMulticall3 contract address from registry
get-mock-multicall3:
	@echo "🚀 Getting MockMulticall3 address..."
	@cast call ${CONTRACT_REGISTRY} "getContract(string name) returns (address)" \
	"__MockMulticall3" \
	--rpc-url $(RPC_URL)

# Get TokenRegistry contract address
get-token-registry:
	@echo "🚀 Retrieving TokenRegistry..."
	@cast call ${CONTRACT_REGISTRY} "getContract(string name) returns (address)" \
	"__TokenRegistry" \
	--rpc-url $(RPC_URL)

# Get PriceFeedRegistry contract address
get-price-feed-registry:
	@echo "🚀 Retrieving PriceFeedRegistry..."
	@cast call ${CONTRACT_REGISTRY} "getContract(string name) returns (address)" \
	"__PriceFeedRegistry" \
	--rpc-url $(RPC_URL)

# Get WalletFactory contract address
get-wallet-factory:
	@echo "🚀 Getting WalletFactory address..."
	@cast call ${CONTRACT_REGISTRY} "getContract(string name) returns (address)" \
	"__WalletFactory" \
	--rpc-url $(RPC_URL)

# Get token address from TokenRegistry (ARG1=token name)
get-token: guard-ARG1
	@echo "🚀 Retrieving token address for '$(ARG1)'..."
	@cast call ${TOKEN_REGISTRY} "getToken(string name) returns (address)" \
	$(ARG1) \
	--rpc-url $(RPC_URL)

# Get price feed address for a token (ARG1=token address)
get-price-feed: guard-ARG1
	@echo "🚀 Retrieving price feed for token $(ARG1)..."
	@cast call ${PRICE_FEED_REGISTRY} "getPriceFeed(address token) returns (address)" \
	$(ARG1) \
	--rpc-url $(RPC_URL)

# Create new wallet with random name and specified parameters
create-wallet:
	@echo "🚀 Creating new wallet with random name..."
	@cast send $(WALLET_FACTORY) "createWallet(string, address[], uint256, bytes32)" \
	$(RANDOM_STRING) $(WALLET_SIGNER_ADDRESSES) $(WALLET_APPROVALS_COUNT) $(WALLET_PASSWORD_HASH) \
	--rpc-url $(RPC_URL) \
	--private-key $(PRIVATE_KEY)

# Get wallet addresses associated with a signer (PUBLIC_KEY must be set)
get-wallets-by-signer:
	@echo "🚀 Listing wallets for signer $(PUBLIC_KEY)..."
	@cast call $(WALLET_FACTORY) "getWalletAddressesBySigner(address signer, uint256 offset, uint256 limit) view returns(address[])" \
	$(PUBLIC_KEY) 0 50 \
	--rpc-url $(RPC_URL)

# Deposit ETH to wallet (ARG1=amount in wei)
deposit-eth: guard-ARG1
	@echo "🚀 Depositing $(ARG1) ETH to $(WALLET)..."
	@cast send $(WALLET) "deposit(address token, uint256 value)" \
		0x0000000000000000000000000000000000000000 \
		$(shell echo $(ARG1) | bc) \
		--rpc-url $(RPC_URL) \
		--private-key $(PRIVATE_KEY) \
		--value $(shell echo $(ARG1) | bc)

# Approve wallet to spend tokens (ARG1=token address, ARG2=amount)
approve-token: guard-ARG1 guard-ARG2
	@echo "🚀 Approving $(ARG2) of $(ARG1) for spending..."
	@cast send $(ARG1) "approve(address spender, uint256 value)" \
		$(WALLET) \
		$(shell echo $(ARG2) | bc) \
		--rpc-url $(RPC_URL) \
		--private-key $(PRIVATE_KEY)

# Deposit tokens to wallet (ARG1=token address, ARG2=amount)
deposit-token: guard-ARG1 guard-ARG2
	@echo "🚀 Depositing $(ARG2) of $(ARG1) to $(WALLET)..."
	@cast send $(WALLET) "deposit(address token, uint256 value)" \
		$(ARG1) \
		$(shell echo $(ARG2) | bc) \
		--rpc-url $(RPC_URL) \
		--private-key $(PRIVATE_KEY)

# Get token balances and information for wallet
get-token-views:
	@echo "🚀 Retrieving token information for $(WALLET)..."
	@cast call $(WALLET) \
		"getTokens(uint256,uint256,bool) returns ((address,string,string,uint256,uint256,uint256,uint256)[])" \
		0 100 false \
		--rpc-url $(RPC_URL)

# Get total wallet balance in USD
get-total-balance-in-usd:
	@echo "🚀 Calculating total USD balance for $(WALLET)..."
	@cast call $(WALLET) "getTotalBalanceInUsd() view returns(uint256)" \
	--rpc-url $(RPC_URL)

# Display help message with all available targets
help:
	@echo "Usage: make [target] [VARIABLE=value]"
	@echo ""
	@echo "Project: $(PROJECT_NAME)"
	@echo "Targets:"
	@echo ""
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-25s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "Environment Variables:"
	@echo "  APP_ENV             Deployment environment (local|dev|prod)"
	@echo "  RPC_URL             Ethereum node RPC endpoint"
	@echo "  PRIVATE_KEY         Account private key for transactions"
	@echo "  CONTRACT_REGISTRY   Address of ContractRegistry"
	@echo "  WALLET_FACTORY      Address of WalletFactory contract"
	@echo ""
	@echo "Examples:"
	@echo "  make deploy APP_ENV=local"
	@echo "  make test TEST_MATCH=WalletTest"
	@echo "  make get-contract ARG1=TokenRegistry"

## all:              Install dependencies, build, and test
## install:          Install project dependencies
## build:            Compile Solidity contracts
## clean:            Remove build artifacts
## test:             Run tests (use TEST_MATCH to filter)
## snapshot:         Generate gas usage report
## fmt:              Format Solidity code
## lint:             Check code formatting
## coverage:         Generate test coverage report
## update:           Update project dependencies
## analyze:          Run static analysis with Slither
## deploy:           Deploy contracts to specified network (APP_ENV required)
## verify:           Verify contract on Etherscan (customize before use)
## get-contract:     Get contract address from registry (ARG1=contract name)
## get-mock-multicall3: Get MockMulticall3 address
## get-token-registry: Get TokenRegistry address
## get-price-feed-registry: Get PriceFeedRegistry address
## get-wallet-factory: Get WalletFactory address
## get-token:        Get token address (ARG1=token name)
## get-price-feed:   Get price feed address (ARG1=token address)
## create-wallet:    Create new wallet with random name
## get-wallets-by-signer: List wallets by signer (PUBLIC_KEY required)
## deposit-eth:      Deposit ETH to wallet (ARG1=amount in wei)
## approve-token:    Approve wallet to spend tokens (ARG1=token, ARG2=amount)
## deposit-token:    Deposit tokens to wallet (ARG1=token, ARG2=amount)
## get-token-views:  Show wallet token balances and info
## get-total-balance-in-usd: Get wallet total balance in USD
## help:             Show this help message