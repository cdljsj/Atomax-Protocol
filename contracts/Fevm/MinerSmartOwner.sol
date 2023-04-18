// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.10;

import "@zondax/filecoin-solidity/contracts/v0.8/types/CommonTypes.sol";
import "@zondax/filecoin-solidity/contracts/v0.8/MinerAPI.sol";
import "@zondax/filecoin-solidity/contracts/v0.8/utils/FilAddresses.sol";
import "@zondax/filecoin-solidity/contracts/v0.8/PrecompilesAPI.sol";
import "../Interfaces/ISmartAccount.sol";
import "../Interfaces/EIP20Interface.sol";
import "../CWrappedNative.sol";

contract MinerSmartOwner is ISmartAccount {
    error Unauthorized();
    error IllegalArgument();
    error InvalidAddress();
    error InvalidActorId();
    error MinerAlreadyBound();
    error MinerNotBound();
    error NegativeValueNotAllowed();

    event GovernorTransferred(address oldGovernor, address newGovernor);
    event Invoked(address indexed invoker, address indexed target, uint indexed value, bytes data);

    CommonTypes.FilActorId public minerId;
    using MinerAPI for CommonTypes.FilActorId;

    address public governor;
    CWrappedNative public lendingPool; 

    modifier onlyGovernor {
        if (msg.sender != governor) revert Unauthorized();
        _;
    }
    
    constructor(address governor_, address payable lendingPool_) {
        governor = governor_;
        lendingPool = CWrappedNative(lendingPool_);
    }

    function transferGovernor(address newGovernor) external onlyGovernor {
        // TODO: liquidity check, not allow to transfer if not all borrow got repaid
        _transferGovernor(newGovernor);
    }

    // TODO: permission check
    function liquidate(address borrower, address liquidator) external {
        if (borrower != address(this)) revert IllegalArgument();
        _transferGovernor(liquidator);
    }

    function _transferGovernor(address newGovernor) internal {
        if (newGovernor == address(0)) revert IllegalArgument();
        
        emit GovernorTransferred(governor, newGovernor);

        governor = newGovernor;
    }

    function withdraw(address token, uint amount, address to) external onlyGovernor {
        if (isNativeToken(token)) {
            (bool success, ) = to.call{value: amount}("");
            if (!success) {
                revert InvalidAddress();
            }
        } else {
            EIP20Interface(token).transfer(to, amount);
        }
    }

    function borrow(uint amount) external onlyGovernor {
        lendingPool.borrow(amount);
    }

    function borrowBalance() public returns (uint) {
        return lendingPool.borrowBalanceCurrent(address(this));
    }

    function repayBorrow() public payable onlyGovernor {
        lendingPool.repayBorrow{value: msg.value}();
    }

    function repayWithDeposit(uint repayAmount) external onlyGovernor {
        lendingPool.repayWithDeposit(address(this), repayAmount);
    }

    function getMinerOwner() external returns (CommonTypes.FilAddress memory currentOwner, CommonTypes.FilAddress memory proposedOwner) {
        MinerTypes.GetOwnerReturn memory getOwnerReturn = minerId.getOwner();
        currentOwner = getOwnerReturn.owner;
        proposedOwner = getOwnerReturn.proposed;
    }

    function acceptMinerOwnership(uint64 targetMinerActorId) external onlyGovernor {
        if (targetMinerActorId == 0) revert InvalidActorId();
        if (CommonTypes.FilActorId.unwrap(minerId) != 0) revert MinerAlreadyBound();

        minerId = CommonTypes.FilActorId.wrap(targetMinerActorId);
        uint64 ownerActorId = PrecompilesAPI.resolveEthAddress(address(this));
        minerId.changeOwnerAddress(FilAddresses.fromActorID(ownerActorId));
    }

    function transferMinerOwnership(CommonTypes.FilAddress memory newMinerOwner) external onlyGovernor {
        minerId.changeOwnerAddress(newMinerOwner);
        minerId = CommonTypes.FilActorId.wrap(0);
    }

    function transferMinerOwnership(address newMinerOwner) external onlyGovernor {
        if (newMinerOwner == address(0)) revert IllegalArgument();
        if (CommonTypes.FilActorId.unwrap(minerId) == 0) revert MinerNotBound();

        uint64 ownerActorId = PrecompilesAPI.resolveEthAddress(address(newMinerOwner));
        minerId.changeOwnerAddress(FilAddresses.fromActorID(ownerActorId));
        minerId = CommonTypes.FilActorId.wrap(0);
    }

    function isControllingAddress(address controller) external returns (bool) {
        return minerId.isControllingAddress(FilAddresses.fromEthAddress(controller));
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

    function changeBeneficiary(MinerTypes.ChangeBeneficiaryParams memory params) external onlyGovernor {
        minerId.changeBeneficiary(params);
    }

    function getBeneficiary() external returns (MinerTypes.GetBeneficiaryReturn memory) {
        return minerId.getBeneficiary();
    }

    function changeWorkerAddress(MinerTypes.ChangeWorkerAddressParams memory params) external onlyGovernor {
        minerId.changeWorkerAddress(params);
    }

    function changePeerId(CommonTypes.FilAddress memory newId) external onlyGovernor {
        minerId.changePeerId(newId);
    }

    function changeMultiaddresses(MinerTypes.ChangeMultiaddrsParams memory params) external onlyGovernor {
        minerId.changeMultiaddresses(params);
    }

    function repayDebt() external onlyGovernor {
        minerId.repayDebt();
    }

    function confirmChangeWorkerAddress() external onlyGovernor {
        minerId.confirmChangeWorkerAddress();
    }

    function getPeerId() external returns (CommonTypes.FilAddress memory) {
        return minerId.getPeerId();
    }

    function getMultiaddresses() external returns (MinerTypes.GetMultiaddrsReturn memory) {
        return minerId.getMultiaddresses();
    }

    function withdrawBalanceFromMiner(CommonTypes.BigInt memory amount) external onlyGovernor returns (uint) {
        uint withdrawAmount = toUint256(minerId.withdrawBalance(amount));
        uint borrowedAmount = borrowBalance();
        uint repayAmount = withdrawAmount/2;
        if (repayAmount > borrowedAmount) {
            repayAmount = borrowedAmount;
        }
        repayBorrow();
        return withdrawAmount;
    }

    function getNonStandardCollateralAssetValue() external pure returns(uint) {
        return 100 * (10 ** 18);
    }

    function toUint256(CommonTypes.BigInt memory value) internal pure returns (uint256) {
        if (value.neg) {
            revert NegativeValueNotAllowed();
        }

        // BigNumber memory max = BigNumbers.init(MAX_UINT, false);
        // BigNumber memory bigNumValue = BigNumbers.init(value.val, value.neg);
        // if (BigNumbers.gt(bigNumValue, max)) {
        //     return (0, true);
        // }

        return (uint256(bytes32(value.val)));
    }

    function isNativeToken(address token) internal pure returns (bool) {
        return token == address(0);
    }

    function filAdressToAddress(CommonTypes.FilAddress memory addr) public pure returns (address) {
        bytes memory data = addr.data;
        if (data.length != 22) {
            revert InvalidAddress();
        }
        bytes20 addressBytes;
        assembly {
            addressBytes := mload(add(data, 0x22))
        }
        return address(addressBytes);
    }


    // function invoke(address target, bytes calldata data) external payable onlyGovernor returns (bytes memory result) {
    //     bool success;
    //     (success, result) = target.call{value: msg.value}(data);
    //     if (!success) {
    //         // solhint-disable-next-line no-inline-assembly
    //         assembly {
    //             returndatacopy(0, 0, returndatasize())
    //             revert(0, returndatasize())
    //         }
    //     }
    //     emit Invoked(msg.sender, target, msg.value, data);
    // }

    receive() external payable {
    }
}