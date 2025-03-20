// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Errors} from "src/Errors.sol";

contract ContractRegistry is Ownable, Errors {
    // Mapping from contract name to address
    mapping(bytes32 => address) private s_contracts;

    error ContractDoesNotExist();

    event ContractSetted(bytes32 indexed name, address indexed contractAddress);

    constructor() Ownable(msg.sender) {
        //
    }

    function setContract(
        string memory name,
        address contractAddress
    ) external onlyOwner nonZeroAddress(contractAddress) {
        bytes32 nameHash = keccak256(abi.encodePacked(name));
        s_contracts[nameHash] = contractAddress;
        emit ContractSetted(nameHash, contractAddress);
    }

    function getContract(
        string memory name
    ) external view returns (address contractAddress) {
        bytes32 nameHash = keccak256(abi.encodePacked(name));
        contractAddress = s_contracts[nameHash];
        if (contractAddress == address(0)) revert ContractDoesNotExist();
    }
}
