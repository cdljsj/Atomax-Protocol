// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./Comptroller.sol";
import "./CToken.sol";
import "./FixedMath.sol";
import "./Interfaces/EIP20Interface.sol";

contract RewardsPool is Ownable {
    error IllegalArgument();
    error MarketNotListed();

    /// @notice Emitted when COMP is distributed to a supplier
    event DistributedSupplierRewards(CToken indexed cToken, address indexed supplier, uint compDelta, uint compSupplyIndex);

    /// @notice Emitted when COMP is distributed to a borrower
    event DistributedBorrowerRewards(CToken indexed cToken, address indexed borrower, uint compDelta, uint compBorrowIndex);

    /// @notice Emitted when a new borrow-side COMP speed is calculated for a market
    event RewardsBorrowSpeedUpdated(CToken indexed cToken, uint newSpeed);

    /// @notice Emitted when a new supply-side COMP speed is calculated for a market
    event RewardsSupplySpeedUpdated(CToken indexed cToken, uint newSpeed);

    struct RewardsMarketState {
        // The market's last updated compBorrowIndex or compSupplyIndex
        uint224 index;

        // The block number the index was last updated at
        uint32 block;
    }

    /// @notice The initial COMP index for a market
    uint224 public constant rewardsInitialIndex = 1e36;

    address public rewardsToken;

    Comptroller public comptroller;

    /// @notice The portion of compRate that each market currently receives
    mapping(address => uint) public rewardsSpeeds;

    /// @notice The COMP market supply state for each market
    mapping(address => RewardsMarketState) public rewardsSupplyState;

    /// @notice The COMP market borrow state for each market
    mapping(address => RewardsMarketState) public rewardsBorrowState;

    /// @notice The COMP borrow index for each market for each supplier as of the last time they accrued COMP
    mapping(address => mapping(address => uint)) public compSupplierIndex;

    /// @notice The COMP borrow index for each market for each borrower as of the last time they accrued COMP
    mapping(address => mapping(address => uint)) public compBorrowerIndex;

    /// @notice The COMP accrued but not yet transferred to each user
    mapping(address => uint) public rewardsAccrued;


    /**
     * @notice Set COMP borrow and supply speeds for the specified markets.
     * @param cTokens The markets whose COMP speed to update.
     * @param supplySpeeds New supply-side COMP speed for the corresponding market.
     * @param borrowSpeeds New borrow-side COMP speed for the corresponding market.
     */
    function _setRewardsSpeeds(CToken[] memory cTokens, uint[] memory supplySpeeds, uint[] memory borrowSpeeds) external {
        // if (!adminOrInitializing()) revert Unauthorized();

        uint numTokens = cTokens.length;
        if (numTokens != supplySpeeds.length || numTokens != borrowSpeeds.length) revert IllegalArgument();

        for (uint i = 0; i < numTokens; ++i) {
            setRewardsSpeedInternal(cTokens[i], supplySpeeds[i], borrowSpeeds[i]);
        }
    }

    function _addRewardsMarketInternal(address cToken) internal {
        if (rewardsSupplyState[cToken].index == 0) {
            rewardsSupplyState[cToken] = RewardsMarketState({
                index: rewardsInitialIndex,
                block: FixedMath.safe32(comptroller.getBlockNumber())
            });
        }

        if (rewardsBorrowState[cToken].index == 0) {
            rewardsBorrowState[cToken] = RewardsMarketState({
                index: rewardsInitialIndex,
                block: FixedMath.safe32(comptroller.getBlockNumber())
            });
        }
    }


    /**
     * @notice Set COMP speed for a single market
     * @param cToken The market whose COMP speed to update
     * @param supplySpeed New supply-side COMP speed for market
     * @param borrowSpeed New borrow-side COMP speed for market
     */
    function setRewardsSpeedInternal(CToken cToken, uint supplySpeed, uint borrowSpeed) internal {
        (bool isListed,,,) = comptroller.markets(address(cToken));
        if (!isListed) revert MarketNotListed();

        uint currentRewardsSpeed = rewardsSpeeds[address(cToken)];
        uint currentSupplySpeed = currentRewardsSpeed >> 128;
        uint currentBorrowSpeed = uint128(currentRewardsSpeed);

        if (currentSupplySpeed != supplySpeed) {
            // Supply speed updated so let's update supply state to ensure that
            //  1. COMP accrued properly for the old speed, and
            //  2. COMP accrued at the new speed starts after this block.
            updateRewardsSupplyIndex(address(cToken));

            // Update speed and emit event
            // compSupplySpeeds[address(cToken)] = supplySpeed;
            emit RewardsSupplySpeedUpdated(cToken, supplySpeed);
        }

        if (currentBorrowSpeed != borrowSpeed) {
            // Borrow speed updated so let's update borrow state to ensure that
            //  1. COMP accrued properly for the old speed, and
            //  2. COMP accrued at the new speed starts after this block.
            FixedMath.Exp borrowIndex = FixedMath.Exp.wrap(cToken.borrowIndex());
            updateRewardsBorrowIndex(address(cToken), borrowIndex);

            // Update speed and emit event
            // compBorrowSpeeds[address(cToken)] = borrowSpeed;
            emit RewardsBorrowSpeedUpdated(cToken, borrowSpeed);
        }
        uint newRewardsSpeed = uint256(supplySpeed << 128) + borrowSpeed;
        rewardsSpeeds[address(cToken)] = newRewardsSpeed;
    }

    /**
     * @notice Accrue COMP to the market by updating the supply index
     * @param cToken The market whose supply index to update
     * @dev Index is a cumulative sum of the COMP per cToken accrued.
     */
    function updateRewardsSupplyIndex(address cToken) public {
        RewardsMarketState storage supplyState = rewardsSupplyState[cToken];
        uint compSpeed = rewardsSpeeds[cToken];
        // use first 128 bit as supplySpeed
        uint supplySpeed = compSpeed >> 128;
        uint32 blockNumber = uint32(comptroller.getBlockNumber());
        uint deltaBlocks = FixedMath.sub_(uint(blockNumber), uint(supplyState.block));
        if (deltaBlocks > 0 && supplySpeed > 0) {
            uint supplyTokens = CToken(cToken).totalSupply();
            uint compAccrued = FixedMath.mul_(deltaBlocks, supplySpeed);
            FixedMath.Double ratio = supplyTokens > 0 ? FixedMath.fraction(compAccrued, supplyTokens) : FixedMath.Double.wrap(0);
            supplyState.index = FixedMath.safe224(FixedMath.Double.unwrap(FixedMath.add_(FixedMath.Double.wrap(supplyState.index), ratio)));
            supplyState.block = blockNumber;
        } else if (deltaBlocks > 0) {
            supplyState.block = blockNumber;
        }
    }

    /**
     * @notice Accrue COMP to the market by updating the borrow index
     * @param cToken The market whose borrow index to update
     * @dev Index is a cumulative sum of the COMP per cToken accrued.
     */
    function updateRewardsBorrowIndex(address cToken, FixedMath.Exp marketBorrowIndex) public {
        RewardsMarketState storage borrowState = rewardsBorrowState[cToken];
        // use last 128 bit as borrowSpeed
        uint borrowSpeed = uint128(rewardsSpeeds[cToken]);        
        uint32 blockNumber = uint32(comptroller.getBlockNumber());
        uint deltaBlocks = FixedMath.sub_(uint(blockNumber), uint(borrowState.block));
        if (deltaBlocks > 0 && borrowSpeed > 0) {
            uint borrowAmount = FixedMath.mul_(CToken(cToken).totalBorrows(), marketBorrowIndex);
            uint compAccrued = FixedMath.mul_(deltaBlocks, borrowSpeed);
            FixedMath.Double ratio = borrowAmount > 0 ? FixedMath.fraction(compAccrued, borrowAmount) : FixedMath.Double.wrap(0);
            borrowState.index = FixedMath.safe224(FixedMath.Double.unwrap(FixedMath.add_(FixedMath.Double.wrap(borrowState.index), ratio)));
            borrowState.block = blockNumber;
        } else if (deltaBlocks > 0) {
            borrowState.block = blockNumber;
        }
    }
    
    /**
     * @notice Calculate COMP accrued by a supplier and possibly transfer it to them
     * @param cToken The market in which the supplier is interacting
     * @param supplier The address of the supplier to distribute COMP to
     */
    function distributeSupplierRewards(address cToken, address supplier) internal {
        // TODO: Don't distribute supplier COMP if the user is not in the supplier market.
        // This check should be as gas efficient as possible as distributeSupplierRewards is called in many places.
        // - We really don't want to call an external contract as that's quite expensive.

        RewardsMarketState storage supplyState = rewardsSupplyState[cToken];
        uint supplyIndex = supplyState.index;
        uint supplierIndex = compSupplierIndex[cToken][supplier];

        // Update supplier's index to the current index since we are distributing accrued COMP
        compSupplierIndex[cToken][supplier] = supplyIndex;

        if (supplierIndex == 0 && supplyIndex >= rewardsInitialIndex) {
            // Covers the case where users supplied tokens before the market's supply state index was set.
            // Rewards the user with COMP accrued from the start of when supplier rewards were first
            // set for the market.
            supplierIndex = rewardsInitialIndex;
        }

        // Calculate change in the cumulative sum of the COMP per cToken accrued
        FixedMath.Double deltaIndex = FixedMath.Double.wrap(FixedMath.sub_(supplyIndex, supplierIndex));

        uint supplierTokens = CToken(cToken).balanceOf(supplier);

        // Calculate COMP accrued: cTokenAmount * accruedPerCToken
        uint supplierDelta = FixedMath.mul_(supplierTokens, deltaIndex);

        uint supplierAccrued = FixedMath.add_(rewardsAccrued[supplier], supplierDelta);

        rewardsAccrued[supplier] = supplierAccrued;

        emit DistributedSupplierRewards(CToken(cToken), supplier, supplierDelta, supplyIndex);
    }

    /**
     * @notice Calculate COMP accrued by a borrower and possibly transfer it to them
     * @dev Borrowers will not begin to accrue until after the first interaction with the protocol.
     * @param cToken The market in which the borrower is interacting
     * @param borrower The address of the borrower to distribute COMP to
     */
    function distributeBorrowerRewards(address cToken, address borrower, FixedMath.Exp marketBorrowIndex) internal {
        // TODO: Don't distribute supplier COMP if the user is not in the borrower market.
        // This check should be as gas efficient as possible as distributeBorrowerRewards is called in many places.
        // - We really don't want to call an external contract as that's quite expensive.

         RewardsMarketState storage borrowState = rewardsBorrowState[cToken];
        uint borrowIndex = borrowState.index;
        uint borrowerIndex = compBorrowerIndex[cToken][borrower];

        // Update borrowers's index to the current index since we are distributing accrued COMP
        compBorrowerIndex[cToken][borrower] = borrowIndex;

        if (borrowerIndex == 0 && borrowIndex >= rewardsInitialIndex) {
            // Covers the case where users borrowed tokens before the market's borrow state index was set.
            // Rewards the user with COMP accrued from the start of when borrower rewards were first
            // set for the market.
            borrowerIndex = rewardsInitialIndex;
        }

        // Calculate change in the cumulative sum of the COMP per borrowed unit accrued
        FixedMath.Double deltaIndex = FixedMath.Double.wrap(FixedMath.sub_(borrowIndex, borrowerIndex));

        uint borrowerAmount = FixedMath.div_(CToken(cToken).borrowBalanceStored(borrower), marketBorrowIndex);

        // Calculate COMP accrued: cTokenAmount * accruedPerBorrowedUnit
        uint borrowerDelta = FixedMath.mul_(borrowerAmount, deltaIndex);

        uint borrowerAccrued = FixedMath.add_(rewardsAccrued[borrower], borrowerDelta);
        rewardsAccrued[borrower] = borrowerAccrued;

        emit DistributedBorrowerRewards(CToken(cToken), borrower, borrowerDelta, borrowIndex);
    }

    /**
     * @notice Claim all the comp accrued by holder in all markets
     * @param holder The address to claim COMP for
     */
    function claimRewards(address holder) public {
        return claimRewards(holder, comptroller.getAllMarkets());
    }

    /**
     * @notice Claim all the comp accrued by holder in the specified markets
     * @param holder The address to claim COMP for
     * @param cTokens The list of markets to claim COMP in
     */
    function claimRewards(address holder, CToken[] memory cTokens) public {
        address[] memory holders = new address[](1);
        holders[0] = holder;
        claimRewards(holders, cTokens, true, true);
    }

    /**
     * @notice Claim all comp accrued by the holders
     * @param holders The addresses to claim COMP for
     * @param cTokens The list of markets to claim COMP in
     * @param borrowers Whether or not to claim COMP earned by borrowing
     * @param suppliers Whether or not to claim COMP earned by supplying
     */
    function claimRewards(address[] memory holders, CToken[] memory cTokens, bool borrowers, bool suppliers) public {
        for (uint i = 0; i < cTokens.length; i++) {
            CToken cToken = cTokens[i];
            (bool isListed,,,) = comptroller.markets(address(cToken));
            require(isListed, "market must be listed");
            if (borrowers == true) {
                FixedMath.Exp borrowIndex = FixedMath.Exp.wrap(cToken.borrowIndex());
                updateRewardsBorrowIndex(address(cToken), borrowIndex);
                for (uint j = 0; j < holders.length; j++) {
                    distributeBorrowerRewards(address(cToken), holders[j], borrowIndex);
                }
            }
            if (suppliers == true) {
                updateRewardsSupplyIndex(address(cToken));
                for (uint j = 0; j < holders.length; j++) {
                    distributeSupplierRewards(address(cToken), holders[j]);
                }
            }
        }

        for (uint j = 0; j < holders.length; j++) {
            rewardsAccrued[holders[j]] = grantRewardsInternal(holders[j], rewardsAccrued[holders[j]]);
        }
    }

    /**
     * @notice Transfer COMP to the user
     * @dev Note: If there is not enough COMP, we do not perform the transfer all.
     * @param user The address of the user to transfer COMP to
     * @param amount The amount of COMP to (possibly) transfer
     * @return The amount of COMP which was NOT transferred to the user
     */
    function grantRewardsInternal(address user, uint amount) internal returns (uint) {
        EIP20Interface comp = EIP20Interface(rewardsToken);
        uint compRemaining = comp.balanceOf(address(this));
        if (amount > 0 && amount <= compRemaining) {
            comp.transfer(user, amount);
            return 0;
        }
        return amount;
    }
}