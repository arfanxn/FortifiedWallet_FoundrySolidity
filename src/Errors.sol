// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Errors {
    error ZeroAddress();

    modifier nonZeroAddress(address _address) {
        if (_address == address(0)) revert ZeroAddress();
        _;
    }
}
