// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {BaseMockERC20} from "test/mocks/BaseMockERC20.sol";

contract MockUSDC is BaseMockERC20 {
    constructor() {
        _name = "Mock USDC";
        _symbol = "MUSDC";
        _decimals = 6;
    }
}
