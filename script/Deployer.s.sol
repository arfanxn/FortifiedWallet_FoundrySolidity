// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {IDeployer} from "script/interfaces/IDeployer.sol";
import {DeployWalletFactory} from "script/DeployWalletFactory.s.sol";
import {DeployMockTokens} from "script/DeployMockTokens.s.sol";
import {DeployPriceConsumer} from "script/DeployPriceConsumer.s.sol";
import {DeployMockV3Aggregator} from "script/DeployMockV3Aggregator.s.sol";
import {HelperConfig} from "src/HelperConfig.sol";

contract Deployer is Script, IDeployer {
    error InvalidChainId();

    HelperConfig private config;

    function run() external returns (address) {
        vm.startBroadcast();
        config = new HelperConfig();
        config.grantRole(config.OWNER_ROLE(), address(this));
        config.setCaller(msg.sender);
        vm.stopBroadcast();

        uint256 chainId = block.chainid;
        if (config.MAINNET_CHAIN_ID() == chainId) {
            _runMainnet();
        } else if (config.LOCAL_CHAIN_ID() == chainId) {
            _runLocal();
        } else revert InvalidChainId();

        return address(config);
    }

    function getConfig() external view returns (HelperConfig) {
        return config;
    }

    /**
     * @dev Deploys the contracts for the mainnet environment.
     * 1. Deploy the PriceConsumer
     * 2. Deploy the WalletFactory
     */
    function _runMainnet() private {
        IDeployer[] memory deployers = new IDeployer[](2);
        deployers[0] = new DeployPriceConsumer(config);
        deployers[1] = new DeployWalletFactory(config);
        _executeDeployers(deployers);
    }

    /**
     * @dev Deploys the contracts for the local environment.
     * 1. Deploy the mock tokens (USDC, WETH, MKR)
     * 2. Deploy the mock V3Aggregator
     * 3. Deploy the PriceConsumer
     * 4. Deploy the WalletFactory
     */
    function _runLocal() private {
        IDeployer[] memory deployers = new IDeployer[](4);
        deployers[0] = new DeployMockTokens(config);
        deployers[1] = new DeployMockV3Aggregator(config);
        deployers[2] = new DeployPriceConsumer(config);
        deployers[3] = new DeployWalletFactory(config);
        _executeDeployers(deployers);
    }

    /**
     * @dev Runs the deployers in the given array.
     * @param deployers The deployers to run.
     */
    function _executeDeployers(IDeployer[] memory deployers) private {
        for (uint256 i = 0; i < deployers.length; i++) {
            vm.startBroadcast();
            config.grantRole(config.OWNER_ROLE(), address(deployers[i]));
            vm.stopBroadcast();
            deployers[i].run();
        }
    }
}
