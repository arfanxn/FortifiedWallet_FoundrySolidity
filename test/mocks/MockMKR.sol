// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {MockERC20} from "lib/openzeppelin-contracts/lib/forge-std/src/mocks/MockERC20.sol";

contract MockMKR is MockERC20 {
    constructor() {
        _name = "Mock MKR";
        _symbol = "MMKR";
        _decimals = 18;
    }

    // Add extra functions for testing convenience
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) public {
        _burn(from, amount);
    }
}
