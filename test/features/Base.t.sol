// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {HelperConfig} from "src/HelperConfig.sol";
import {IDeployer} from "script/interfaces/IDeployer.sol";
import {Deployer} from "script/Deployer.s.sol";
import {IDynamicPriceConsumer} from "src/interfaces/IDynamicPriceConsumer.sol";

/// @title Base Test Contract
/// @notice This contract is used as a base for other test contracts
contract BaseTest is Test {
    HelperConfig internal config;

    /// @notice Using MessageHashUtils for bytes32
    using MessageHashUtils for bytes32;

    /// @dev Initial ETH balance for the dummy account
    uint256 internal constant ACCOUNT_INITIAL_ETH = 100e18;

    /// @dev Initial USDC balance for the dummy account
    uint256 internal constant ACCOUNT_INITIAL_USDC = 100_000e6;

    /// @dev Initial MKR balance for the dummy account
    uint256 internal constant ACCOUNT_INITIAL_MKR = 10e18;

    /// @notice dummy account addresses
    address[] internal accounts;

    /// @notice Mock WETH token
    ERC20Mock internal weth;
    /// @notice Mock USDC token
    ERC20Mock internal usdc;
    /// @notice Mock MKR token
    ERC20Mock internal mkr;

    /// @notice Dynamic Price Consumer
    IDynamicPriceConsumer internal dynamicPriceConsumer;

    /// @notice Returns the main account address
    /// @return address The main account address
    function _getMainAccount() internal view returns (address) {
        return accounts[0];
    }

    function setUp() public virtual {
        // Deploy the HelperConfig contract
        IDeployer deployer = new Deployer();
        address configAddr = deployer.run();

        // Initialize the HelperConfig contract
        config = HelperConfig(configAddr);

        // Initialize the mock USDC and MKR tokens
        weth = ERC20Mock(config.getToken(HelperConfig.Token.WETH));
        usdc = ERC20Mock(config.getToken(HelperConfig.Token.USDC));
        mkr = ERC20Mock(config.getToken(HelperConfig.Token.MKR));

        // Initialize the dynamic price consumer
        dynamicPriceConsumer = IDynamicPriceConsumer(config.getPriceConsumer());
    }

    modifier initAccounts(uint256 accountsCount) {
        // Create accounts
        accounts = new address[](accountsCount);
        for (uint256 i; i < accountsCount; ++i) {
            // Create account address
            accounts[i] = makeAddr(string(abi.encodePacked("account", i)));
        }
        _;
    }

    /// @notice Funds  accounts with 100 ETH and 100_000 USDC
    /// @dev This modifier is used to fund  accounts before running a test
    modifier fundAccounts() {
        // Fund  accounts
        for (uint256 i; i < accounts.length; ++i) {
            // Fund  account with 100 ETH
            vm.deal(accounts[i], ACCOUNT_INITIAL_ETH);

            // Mint 100_000 USDC to the  account
            usdc.mint(accounts[i], ACCOUNT_INITIAL_USDC);

            // Mint 100_000 USDC to the  account
            mkr.mint(accounts[i], ACCOUNT_INITIAL_MKR);
        }

        _;
    }

    /// @notice Verifies that the dummy accounts have the expected balances
    function testAccountsHaveBalances() public initAccounts(2) fundAccounts {
        for (uint256 i; i < accounts.length; ++i) {
            uint256 accountEthBalance = accounts[i].balance;
            uint256 accountUsdcBalance = usdc.balanceOf(accounts[i]);
            uint256 accountMkrBalance = mkr.balanceOf(accounts[i]);

            assertEq(
                accountEthBalance,
                ACCOUNT_INITIAL_ETH,
                "Account ETH balance is not correct"
            );
            assertEq(
                accountUsdcBalance,
                ACCOUNT_INITIAL_USDC,
                "Account USDC balance is not correct"
            );
            assertEq(
                accountMkrBalance,
                ACCOUNT_INITIAL_MKR,
                "Account MKR balance is not correct"
            );
        }
    }
}
