// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// script/DeployContractFactory.sol
import {Script} from "forge-std/Script.sol";
import {WalletFactory} from "src/WalletFactory.sol";

contract DeployWalletFactory is Script {
    function run() external returns (address) {
        vm.startBroadcast();
        WalletFactory factory = new WalletFactory();
        vm.stopBroadcast();
        return address(factory);
    }
}
