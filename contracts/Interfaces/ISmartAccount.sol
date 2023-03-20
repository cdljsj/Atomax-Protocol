// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.10;

interface ISmartAccount {
    function getNonStandardCollateralAssetValue() external view returns (uint);
    function withdraw(address token, uint amount, address to) external;
    function transferOwner(address newOwner) external;
}