// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// script/DeployContractFactory.sol
import {IDeployer} from "script/interfaces/IDeployer.sol";
import {Script} from "forge-std/Script.sol";
import {WalletFactory} from "src/WalletFactory.sol";
import {HelperConfig} from "src/HelperConfig.sol";

contract DeployWalletFactory is Script, IDeployer {
    HelperConfig private immutable config;
    constructor(HelperConfig _config) {
        config = _config;
    }

    function run() external returns (address) {
        vm.startBroadcast();
        WalletFactory factory = new WalletFactory(config);
        vm.stopBroadcast();
        config.setWalletFactory(address(factory));
        return address(factory);
    }
}
