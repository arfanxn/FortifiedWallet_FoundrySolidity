// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {IDeployer} from "script/interfaces/IDeployer.sol";
import {HelperConfig} from "src/HelperConfig.sol";
import {DynamicPriceConsumer} from "src/DynamicPriceConsumer.sol";
import {IDynamicPriceConsumer} from "src/interfaces/IDynamicPriceConsumer.sol";

// Deploy DynamicPriceConsumer
contract DeployPriceConsumer is Script, IDeployer {
    HelperConfig private immutable config;
    constructor(HelperConfig _config) {
        config = _config;
    }

    function run() external returns (address) {
        HelperConfig.Token[] memory tokenEnumValues = config
            .getTokenEnumValues();

        // Start a new transaction
        vm.startBroadcast();

        // Deploy the DynamicPriceConsumer contract
        IDynamicPriceConsumer priceConsumer = new DynamicPriceConsumer();

        // Register the price feeds for Ether and USDC
        for (uint256 index = 0; index < tokenEnumValues.length; index++) {
            HelperConfig.Token tokenName = tokenEnumValues[index];
            address tokenAddr = config.getToken(tokenName);
            address priceFeedAddr = config.getPriceFeed(tokenName);

            priceConsumer.registerPriceFeed(tokenAddr, priceFeedAddr);
        }

        config.setPriceConsumer(address(priceConsumer));

        // Stop the new transaction
        vm.stopBroadcast();

        // Return the addresses of the price consumer and the two price feeds
        return address(priceConsumer);
    }
}
