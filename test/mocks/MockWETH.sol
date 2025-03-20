// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {BaseMockERC20} from "test/mocks/BaseMockERC20.sol";

contract MockWETH is BaseMockERC20 {
    constructor() {
        _name = "Wrapped Ether";
        _symbol = "WETH";
        _decimals = 18;
    }
}
