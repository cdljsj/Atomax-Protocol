// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.10;

interface ICollateralAsset {
    function getCollateralValue() external returns (uint);
}