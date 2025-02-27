// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {IDeployer} from "script/interfaces/IDeployer.sol";
import {HelperConfig} from "src/HelperConfig.sol";
import {MockV3Aggregator} from "@chainlink/contracts/src/v0.8/shared/mocks/MockV3Aggregator.sol";

// Deploy DeployMockV3Aggregator
contract DeployMockV3Aggregator is Script, IDeployer {
    HelperConfig private immutable config;
    constructor(HelperConfig _config) {
        config = _config;
    }

    function run() external returns (address) {
        // Start a new transaction
        vm.startBroadcast();
        // Deploy a mock price feed for Ether (ETH)
        MockV3Aggregator etherPriceFeed = new MockV3Aggregator(8, 2600 * 1e8);
        // Deploy a mock price feed for USDC
        MockV3Aggregator usdcPriceFeed = new MockV3Aggregator(8, 1 * 1e8);
        // Deploy a mock price feed for MKR
        MockV3Aggregator mkrPriceFeed = new MockV3Aggregator(8, 1000 * 1e8);

        // Save the price feed addresses
        config.setPriceFeed(HelperConfig.Token.ETH, address(etherPriceFeed));
        config.setPriceFeed(HelperConfig.Token.WETH, address(etherPriceFeed));
        config.setPriceFeed(HelperConfig.Token.USDC, address(usdcPriceFeed));
        config.setPriceFeed(HelperConfig.Token.MKR, address(mkrPriceFeed)); // Save the price feed addresses

        // Stop the new transaction
        vm.stopBroadcast();

        // Return the addresses of the price consumer and the two price feeds
        return address(config);
    }
}
