// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IDeployer} from "script/interfaces/IDeployer.sol";
import {Script} from "forge-std/Script.sol";
import {MockWETH} from "test/mocks/MockWETH.sol";
import {MockUSDC} from "test/mocks/MockUSDC.sol";
import {MockMKR} from "test/mocks/MockMKR.sol";
import {MockERC20} from "lib/openzeppelin-contracts/lib/forge-std/src/mocks/MockERC20.sol";
import {HelperConfig} from "src/HelperConfig.sol";

contract DeployMockTokens is Script, IDeployer {
    HelperConfig private immutable config;
    constructor(HelperConfig _config) {
        config = _config;
    }

    function run() external returns (address) {
        vm.startBroadcast();
        MockERC20 weth = new MockWETH();
        MockERC20 usdc = new MockUSDC();
        MockERC20 mkr = new MockMKR();
        vm.stopBroadcast();

        config.setToken(HelperConfig.Token.ETH, address(0));
        config.setToken(HelperConfig.Token.WETH, address(weth));
        config.setToken(HelperConfig.Token.USDC, address(usdc));
        config.setToken(HelperConfig.Token.MKR, address(mkr));

        return address(config);
    }
}
