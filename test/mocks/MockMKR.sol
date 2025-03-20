// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {BaseMockERC20} from "test/mocks/BaseMockERC20.sol";

contract MockMKR is BaseMockERC20 {
    constructor() {
        _name = "Mock MKR";
        _symbol = "MMKR";
        _decimals = 18;
    }
}
