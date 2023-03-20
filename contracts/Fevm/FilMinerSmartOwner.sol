// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../Interfaces/ISmartAccount.sol";
import "./VirtualMiner.sol";
contract FilMinerSmartOwner is Ownable, ISmartAccount {
    VirtualMiner public miner;

    event Invoked(address indexed module, address indexed target, uint indexed value, bytes data);

    constructor(address initialOwner) {
        _transferOwnership(initialOwner);
    }

    function acceptMinerOwner(VirtualMiner miner_) external {
        // Call miner to accept pending owner
        miner = miner_;
    }

    function getNonStandardCollateralAssetValue() external view returns (uint) {
        // calculate the fil collateral value after termination
    }

    function hasValidMinerAsset() external returns (bool) {
        // check the owner of associated miner is current smart contract and the miner is in valid state
    }

    function withdraw(address token, uint amount, address to) external onlyOwner {

    }

    function transferOwner(address newOwner) external virtual override onlyOwner {
    }

    function invoke(address target, uint value, bytes calldata data) external payable onlyOwner returns (bytes memory result) {
        bool success;
        (success, result) = target.call{value: value}(data);
        if (!success) {
            // solhint-disable-next-line no-inline-assembly
            assembly {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }
        emit Invoked(msg.sender, target, value, data);
    }

    receive() payable external {}
}