// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract MultiOwnable is AccessControl {
    /**
     * @dev Reverts if caller is not an owner.
     */
    error CallerIsNotOwner();

    /**
     * @dev Role that corresponds to ownership.
     */
    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");

    /**
     * @dev Grants the OWNER_ROLE to the initial owner(s).
     * @param _owners The initial owners to grant the OWNER_ROLE to.
     */
    function initialize(address[] memory _owners) public {
        _setRoleAdmin(OWNER_ROLE, OWNER_ROLE);
        for (uint256 i = 0; i < _owners.length; i++) {
            address _owner = _owners[i];
            _grantRole(OWNER_ROLE, _owner);
        }
    }

    /**
     * @dev Modifier to restrict access to owners.
     */
    modifier onlyOwner() {
        if (hasRole(OWNER_ROLE, msg.sender) == false) {
            revert CallerIsNotOwner();
        }
        _;
    }
}
