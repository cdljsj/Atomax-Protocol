// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.10;

import "@zondax/filecoin-solidity/contracts/v0.8/types/CommonTypes.sol";
import "@zondax/filecoin-solidity/contracts/v0.8/MinerAPI.sol";
import "../Interfaces/ICollateralAsset.sol";

contract VirtualMiner is ICollateralAsset {
    CommonTypes.FilActorId public minerId;
    using MinerAPI for CommonTypes.FilActorId;
    
    constructor(CommonTypes.FilActorId minerId_) {
        minerId = minerId_;
    }

    function getOwner() external returns (MinerTypes.GetOwnerReturn memory) {
        return minerId.getOwner();
    }

    function changeOwnerAddress(CommonTypes.FilAddress memory addr) external {
        minerId.changeOwnerAddress(addr);
    }

    function isControllingAddress(CommonTypes.FilAddress memory addr) external returns (bool) {
        return minerId.isControllingAddress(addr);
    }

    function getSectorSize() external returns (uint64) {
        return minerId.getSectorSize();
    }

    function getAvailableBalance() external returns (CommonTypes.BigInt memory) {
        return minerId.getAvailableBalance();
    }

    function getVestingFunds() external returns (MinerTypes.GetVestingFundsReturn memory) {
        return minerId.getVestingFunds();
    }

    function changeBeneficiary(MinerTypes.ChangeBeneficiaryParams memory params) external {
        minerId.changeBeneficiary(params);
    }

    function getBeneficiary(CommonTypes.FilActorId target) external returns (MinerTypes.GetBeneficiaryReturn memory) {
        return minerId.getBeneficiary();
    }

    function changeWorkerAddress(MinerTypes.ChangeWorkerAddressParams memory params) external {
        minerId.changeWorkerAddress(params);
    }

    function changePeerId(CommonTypes.FilAddress memory newId) external {
        minerId.changePeerId(newId);
    }

    function changeMultiaddresses(MinerTypes.ChangeMultiaddrsParams memory params) external {
        minerId.changeMultiaddresses(params);
    }

    function repayDebt() external {
        minerId.repayDebt();
    }

    function confirmChangeWorkerAddress() external {
        minerId.confirmChangeWorkerAddress();
    }

    function getPeerId() external returns (CommonTypes.FilAddress memory) {
        return minerId.getPeerId();
    }

    function getMultiaddresses(CommonTypes.FilActorId target) external returns (MinerTypes.GetMultiaddrsReturn memory) {
        return minerId.getMultiaddresses();
    }

    function withdrawBalance(CommonTypes.BigInt memory amount) external returns (CommonTypes.BigInt memory) {
        return minerId.withdrawBalance(amount);
    }

    function getCollateralValue() external pure returns(uint) {
        return 0;
    }

}