// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.10;

import "./CWrappedNative.sol";

/**
 * @title Compound's Maximillion Contract
 * @author Compound
 */
contract Maximillion {
    /**
     * @notice The default cEther market to repay in
     */
    CWrappedNative public cWrappedNative;

    /**
     * @notice Construct a Maximillion to repay max in a CEther market
     */
    constructor(CWrappedNative cWrappedNative_) {
        cWrappedNative = cWrappedNative_;
    }

    /**
     * @notice msg.sender sends Ether to repay an account's borrow in the cEther market
     * @dev The provided Ether is applied towards the borrow balance, any excess is refunded
     * @param borrower The address of the borrower account to repay on behalf of
     */
    function repayBehalf(address borrower) public payable {
        repayBehalfExplicit(borrower, cWrappedNative);
    }

    /**
     * @notice msg.sender sends Ether to repay an account's borrow in a cEther market
     * @dev The provided Ether is applied towards the borrow balance, any excess is refunded
     * @param borrower The address of the borrower account to repay on behalf of
     * @param cWrappedNative_ The address of the cEther contract to repay in
     */
    function repayBehalfExplicit(address borrower, CWrappedNative cWrappedNative_) public payable {
        uint received = msg.value;
        uint borrows = cWrappedNative_.borrowBalanceCurrent(borrower);
        if (received > borrows) {
            cWrappedNative_.repayBorrowBehalf{value: borrows}(borrower);
            payable(msg.sender).transfer(received - borrows);
        } else {
            cWrappedNative_.repayBorrowBehalf{value: received}(borrower);
        }
    }
}
