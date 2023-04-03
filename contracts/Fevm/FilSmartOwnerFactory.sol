// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.10;

import "./MinerSmartOwner.sol";
import "../Interfaces/ISmartAccountFactory.sol";

contract FilSmartOwnerFactory is ISmartAccountFactory {
    mapping(address => bool) public smartOwnerPool;

    event SmartOwnerCreated(address creator, address newSmartOwner);

    function createSmartOwner(address governor) external returns(address) {
        MinerSmartOwner newSmartOwner = new MinerSmartOwner(governor);
        smartOwnerPool[address(newSmartOwner)] = true;

        emit SmartOwnerCreated(address(msg.sender), address(newSmartOwner));

        return address(newSmartOwner);
    }

    function isValidSmartAccount(address smartOwner) external view returns (bool) {
        return smartOwnerPool[smartOwner];
    }
}