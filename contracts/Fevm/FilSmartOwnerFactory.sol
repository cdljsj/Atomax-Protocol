// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.10;

import "./MinerSmartOwner.sol";
import "../Interfaces/ISmartAccountFactory.sol";

contract FilSmartOwnerFactory is ISmartAccountFactory {
    mapping(address => bool) public smartOwnerPool;

    function createSmartOwner(address governor) external {
        MinerSmartOwner newSmartOwner = new MinerSmartOwner(governor);
        smartOwnerPool[address(newSmartOwner)] = true;
    }

    function isValidSmartAccount(address smartOwner) external view returns (bool) {
        return smartOwnerPool[smartOwner];
    }
}