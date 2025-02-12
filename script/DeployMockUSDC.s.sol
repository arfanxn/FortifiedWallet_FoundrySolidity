// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {MockERC20} from "lib/openzeppelin-contracts/lib/forge-std/src/mocks/MockERC20.sol";

contract DeployMockUSDC is Script {
    function run() external returns (address) {
        vm.startBroadcast();
        MockERC20 mock = new MockERC20();
        mock.initialize("Mock USDC", "MUSDC", 6);

        vm.stopBroadcast();
        return address(mock);
    }
}
