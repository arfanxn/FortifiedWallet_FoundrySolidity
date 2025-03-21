// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Errors} from "src/Errors.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract TokenRegistry is Ownable, Errors {
    error TokenDoesNotExist();

    mapping(bytes32 name => address token) private s_tokens;

    constructor() Ownable(msg.sender) {
        //
    }

    function setToken(
        string memory _name,
        address _token
    ) external onlyOwner nonZeroAddress(_token) {
        s_tokens[keccak256(abi.encodePacked(_name))] = _token;
    }

    function getToken(string memory _name) public view returns (address) {
        bytes32 nameHash = keccak256(abi.encodePacked(_name));
        if (address(s_tokens[nameHash]) == address(0))
            revert TokenDoesNotExist();
        return s_tokens[nameHash];
    }
}
