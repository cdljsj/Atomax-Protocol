// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.10;

import "./FilMinerSmartOwner.sol";
import "../Interfaces/ISmartAccountFactory.sol";

contract FilSmartOwnerFactory is ISmartAccountFactory {
    mapping(address => bool) public smartOwnerPool;

    function createSmartOwner(address superAdmin) external {
        FilMinerSmartOwner newSmartOwner = new FilMinerSmartOwner(superAdmin);
        smartOwnerPool[address(newSmartOwner)] = true;
    }

    function isValidSmartAccount(address smartOwner) external view returns (bool) {
        return smartOwnerPool[smartOwner];
    }
}