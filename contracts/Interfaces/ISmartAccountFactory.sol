// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.10;

interface ISmartAccountFactory {
    function isValidSmartAccount(address account) external view returns (bool);
}