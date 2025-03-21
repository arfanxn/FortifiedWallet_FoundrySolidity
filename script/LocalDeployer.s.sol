// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BaseMockERC20} from "test/mocks/BaseMockERC20.sol";
import {ContractRegistry} from "src/ContractRegistry.sol";
import {PriceFeedRegistry} from "src/PriceFeedRegistry.sol";
import {TokenRegistry} from "src/TokenRegistry.sol";
import {MockMKR} from "test/mocks/MockMKR.sol";
import {MockUSDC} from "test/mocks/MockUSDC.sol";
import {MockV3Aggregator} from "@chainlink/contracts/src/v0.8/shared/mocks/MockV3Aggregator.sol";
import {MockWETH} from "test/mocks/MockWETH.sol";
import {Script} from "forge-std/Script.sol";
import {WalletFactory} from "src/WalletFactory.sol";

contract LocalDeployer is Script {
    ContractRegistry private contractRegistry;
    TokenRegistry private tokenRegistry;
    PriceFeedRegistry private priceFeedRegistry;

    function run() external returns (address) {
        vm.startBroadcast();

        contractRegistry = new ContractRegistry();
        deployRegistries();
        deployMocks();
        deployWalletFactory();

        vm.stopBroadcast();

        return address(contractRegistry);
    }

    function deployRegistries() internal {
        tokenRegistry = new TokenRegistry();
        contractRegistry.setContract("__TokenRegistry", address(tokenRegistry));

        priceFeedRegistry = new PriceFeedRegistry();
        contractRegistry.setContract(
            "__PriceFeedRegistry",
            address(priceFeedRegistry)
        );
    }

    function deployMocks() internal {
        address Ether = address(0);
        MockV3Aggregator etherPriceFeed = new MockV3Aggregator(8, 2000 * 1e8);
        priceFeedRegistry.setPriceFeed(Ether, etherPriceFeed);

        uint256 tokensLength = 3;
        BaseMockERC20[] memory tokens = new BaseMockERC20[](tokensLength);
        MockV3Aggregator[] memory priceFeeds = new MockV3Aggregator[](
            tokensLength
        );
        tokens[0] = new MockWETH();
        priceFeeds[0] = etherPriceFeed;
        tokens[1] = new MockUSDC();
        priceFeeds[1] = new MockV3Aggregator(8, 1 * 1e8);
        tokens[2] = new MockMKR();
        priceFeeds[2] = new MockV3Aggregator(8, 1000 * 1e8);

        for (uint256 i = 0; i < tokensLength; i++) {
            BaseMockERC20 token = tokens[i];
            MockV3Aggregator priceFeed = priceFeeds[i];

            tokenRegistry.setToken(token.symbol(), address(tokens[i]));
            priceFeedRegistry.setPriceFeed(address(token), priceFeed);

            token.mint(msg.sender, 10_000 * 10 ** token.decimals());
        }
    }

    function deployWalletFactory() internal {
        WalletFactory walletFactory = new WalletFactory(contractRegistry);
        contractRegistry.setContract("__WalletFactory", address(walletFactory));
    }
}
