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
        config = new HelperConfig();

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

    function _runMainnet() private {
        // TODO: complete mainnet deployment
    }

    function _runLocal() private {
        IDeployer[] memory deployers = new IDeployer[](4);
        deployers[0] = new DeployMockTokens(config);
        deployers[1] = new DeployMockV3Aggregator(config);
        deployers[2] = new DeployPriceConsumer(config);
        deployers[3] = new DeployWalletFactory(config);
        for (uint256 i = 0; i < deployers.length; i++) {
            config.grantRole(config.OWNER_ROLE(), address(deployers[i]));
            deployers[i].run();
        }
    }
}
