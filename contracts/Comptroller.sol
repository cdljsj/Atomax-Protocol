// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.10;

import "./CToken.sol";
import "./ErrorReporter.sol";
import "./Interfaces/PriceOracle.sol";
import "./Interfaces/ComptrollerInterface.sol";
import "./Interfaces/ISmartAccount.sol";
import "./ComptrollerStorage.sol";
import "./Unitroller.sol";
import "./FixedMath.sol";

/**
 * @title Compound's Comptroller Contract
 * @author Compound
 */
contract Comptroller is ComptrollerStorage, ComptrollerInterface, ComptrollerErrorReporter {
    /// @notice Emitted when an admin supports a market
    event MarketListed(CToken cToken);

    /// @notice Emitted when an account enters a market
    event MarketEntered(CToken cToken, address account);

    /// @notice Emitted when an account exits a market
    event MarketExited(CToken cToken, address account);

    /// @notice Emitted when close factor is changed by admin
    event NewCloseFactor(uint oldCloseFactorMantissa, uint newCloseFactorMantissa);

    /// @notice Emitted when a collateral factor is changed by admin
    event NewCollateralFactor(CToken cToken, uint oldCollateralFactorMantissa, uint newCollateralFactorMantissa);

    /// @notice Emitted when liquidation incentive is changed by admin
    event NewLiquidationIncentive(uint oldLiquidationIncentiveMantissa, uint newLiquidationIncentiveMantissa);

    /// @notice Emitted when liquidation incentive is changed by admin
    event NewMarketLiquidationIncentive(address cToken, uint oldLiquidationIncentiveMantissa, uint newLiquidationIncentiveMantissa);

    /// @notice Emitted when price oracle is changed
    event NewPriceOracle(PriceOracle oldPriceOracle, PriceOracle newPriceOracle);

    /// @notice Emitted when pause guardian is changed
    event NewPauseGuardian(address oldPauseGuardian, address newPauseGuardian);

    /// @notice Emitted when an action is paused globally
    event ActionPausedGlobally(string action, bool pauseState);

    /// @notice Emitted when an action is paused on a market
    event ActionPaused(CToken cToken, string action, bool pauseState);

    // /// @notice Emitted when a new borrow-side COMP speed is calculated for a market
    // event CompBorrowSpeedUpdated(CToken indexed cToken, uint newSpeed);

    // /// @notice Emitted when a new supply-side COMP speed is calculated for a market
    // event CompSupplySpeedUpdated(CToken indexed cToken, uint newSpeed);

    // /// @notice Emitted when COMP is distributed to a supplier
    // event DistributedSupplierComp(CToken indexed cToken, address indexed supplier, uint compDelta, uint compSupplyIndex);

    // /// @notice Emitted when COMP is distributed to a borrower
    // event DistributedBorrowerComp(CToken indexed cToken, address indexed borrower, uint compDelta, uint compBorrowIndex);

    /// @notice Emitted when borrow cap for a cToken is changed
    event NewBorrowCap(CToken indexed cToken, uint newBorrowCap);

    /// @notice Emitted when borrow cap guardian is changed
    // event NewBorrowCapGuardian(address oldBorrowCapGuardian, address newBorrowCapGuardian);

    /// @notice Emitted when COMP accrued for a user has been manually adjusted.
    // event CompAccruedAdjusted(address indexed user, uint oldCompAccrued, uint newCompAccrued);

    // closeFactorMantissa must be strictly greater than this value
    uint internal constant closeFactorMinMantissa = 0.05e18; // 0.05

    // closeFactorMantissa must not exceed this value
    uint internal constant closeFactorMaxMantissa = 0.9e18; // 0.9

    // No collateralFactorMantissa may exceed this value
    uint internal constant collateralFactorMaxMantissa = 0.98e18; // 0.98

    constructor() {
        admin = msg.sender;
    }

    /*** Assets You Are In ***/

    /**
     * @notice Returns the assets an account has entered
     * @param account The address of the account to pull assets for
     * @return A dynamic list with the assets the account has entered
     */
    function getAssetsIn(address account) external view returns (CToken[] memory) {
        CToken[] memory assetsIn = accountAssets[account];

        return assetsIn;
    }

    /**
     * @notice Returns whether the given account is entered in the given asset
     * @param account The address of the account to check
     * @param cToken The cToken to check
     * @return True if the account is in the asset, otherwise false.
     */
    function checkMembership(address account, CToken cToken) external view returns (bool) {
        return markets[address(cToken)].accountMembership[account];
    }

    /**
     * @notice Add assets to be included in account liquidity calculation
     * @param cTokens The list of addresses of the cToken markets to be enabled
     */
    function enterMarkets(address[] memory cTokens) override external {
        uint len = cTokens.length;

        for (uint i = 0; i < len; i++) {
            CToken cToken = CToken(cTokens[i]);
            addToMarketInternal(cToken, msg.sender);
        }
    }

    /**
     * @notice Add the market to the borrower's "assets in" for liquidity calculations
     * @param cToken The market to enter
     * @param borrower The address of the account to modify
     */
    function addToMarketInternal(CToken cToken, address borrower) internal {
        Market storage marketToJoin = markets[address(cToken)];

        if (!marketToJoin.isListed) revert MarketNotListed();

        if (marketToJoin.accountMembership[borrower] == true) {
            // already joined
            return;
        }

        // survived the gauntlet, add to list
        // NOTE: we store these somewhat redundantly as a significant optimization
        //  this avoids having to iterate through the list for the most common use cases
        //  that is, only when we need to perform liquidity checks
        //  and not whenever we want to check if an account is in a particular market
        marketToJoin.accountMembership[borrower] = true;
        accountAssets[borrower].push(cToken);

        emit MarketEntered(cToken, borrower);
    }

    /**
     * @notice Removes asset from sender's account liquidity calculation
     * @dev Sender must not have an outstanding borrow balance in the asset,
     *  or be providing necessary collateral for an outstanding borrow.
     * @param cTokenAddress The address of the asset to be removed
     */
    function exitMarket(address cTokenAddress) override external {
        CToken cToken = CToken(cTokenAddress);
        /* Get sender tokensHeld and amountOwed underlying from the cToken */
        (, uint tokensHeld, uint amountOwed, ) = cToken.getAccountSnapshot(msg.sender);

        /* Fail if the sender has a borrow balance */
        if (amountOwed != 0) revert ExitMarketBalanceOwned();

        /* Fail if the sender is not permitted to redeem all of their tokens */
        uint allowed = redeemAllowedInternal(cTokenAddress, msg.sender, tokensHeld);
        if (allowed != 0) revert ExitMarketFailed(allowed);

        Market storage marketToExit = markets[address(cToken)];

        /* Return true if the sender is not already ‘in’ the market */
        if (!marketToExit.accountMembership[msg.sender]) {
            return;
        }

        /* Set cToken account membership to false */
        delete marketToExit.accountMembership[msg.sender];

        /* Delete cToken from the account’s list of assets */
        // load into memory for faster iteration
        CToken[] memory userAssetList = accountAssets[msg.sender];
        uint len = userAssetList.length;
        uint assetIndex = len;
        for (uint i = 0; i < len; i++) {
            if (userAssetList[i] == cToken) {
                assetIndex = i;
                break;
            }
        }

        // copy last item in list to location of item to be removed, reduce length by 1
        CToken[] storage storedList = accountAssets[msg.sender];
        storedList[assetIndex] = storedList[storedList.length - 1];
        storedList.pop();

        emit MarketExited(cToken, msg.sender);
    }

    /*** Policy Hooks ***/

    /**
     * @notice Checks if the account should be allowed to mint tokens in the given market
     * @param cToken The market to verify the mint against
     * @return 0 if the mint is allowed, otherwise a semi-opaque error code (See ErrorReporter.sol)
     */
    function mintAllowed(address cToken, 
                         address, // minter The account which would get the minted tokens
                         uint     // mintAmount The amount of underlying being supplied to the market in exchange for tokens
                         ) override external returns (uint) {
        // Pausing is a very serious situation - we revert to sound the alarms
        if (mintGuardianPaused[cToken]) revert MintPaused();

        if (!markets[cToken].isListed) {
            return uint(Error.MARKET_NOT_LISTED);
        }

        // Keep the flywheel moving
        updateCompSupplyIndex(cToken);
        // distributeSupplierComp(cToken, minter);

        return uint(Error.NO_ERROR);
    }

    /**
     * @notice Checks if the account should be allowed to redeem tokens in the given market
     * @param cToken The market to verify the redeem against
     * @param redeemer The account which would redeem the tokens
     * @param redeemTokens The number of cTokens to exchange for the underlying asset in the market
     * @return 0 if the redeem is allowed, otherwise a semi-opaque error code (See ErrorReporter.sol)
     */
    function redeemAllowed(address cToken, address redeemer, uint redeemTokens) override external returns (uint) {
        uint allowed = redeemAllowedInternal(cToken, redeemer, redeemTokens);
        if (allowed != uint(Error.NO_ERROR)) {
            return allowed;
        }

        // Keep the flywheel moving
        updateCompSupplyIndex(cToken);
        // distributeSupplierComp(cToken, redeemer);

        return uint(Error.NO_ERROR);
    }

    function redeemAllowedInternal(address cToken, address redeemer, uint redeemTokens) internal view returns (uint) {
        if (!markets[cToken].isListed) {
            return uint(Error.MARKET_NOT_LISTED);
        }

        /* If the redeemer is not 'in' the market, then we can bypass the liquidity check */
        if (!markets[cToken].accountMembership[redeemer]) {
            return uint(Error.NO_ERROR);
        }

        /* Otherwise, perform a hypothetical liquidity check to guard against shortfall */
        (Error err, , uint shortfall) = getHypotheticalAccountLiquidityInternal(redeemer, CToken(cToken), redeemTokens, 0);
        if (err != Error.NO_ERROR) {
            return uint(err);
        }
        if (shortfall > 0) {
            return uint(Error.INSUFFICIENT_LIQUIDITY);
        }

        return uint(Error.NO_ERROR);
    }

    /**
     * @notice Validates redeem and reverts on rejection. May emit logs.
     * @param cToken Asset being redeemed
     * @param redeemer The address redeeming the tokens
     * @param redeemAmount The amount of the underlying asset being redeemed
     * @param redeemTokens The number of tokens being redeemed
     */
    function redeemVerify(address cToken, address redeemer, uint redeemAmount, uint redeemTokens) override pure external {
        // Shh - currently unused
        cToken;
        redeemer;

        // Require tokens is zero or amount is also zero
        if (redeemTokens == 0 && redeemAmount > 0) {
            revert RedeemTokensZero();
        }
    }

    /**
     * @notice Checks if the account should be allowed to borrow the underlying asset of the given market
     * @param cToken The market to verify the borrow against
     * @param borrower The account which would borrow the asset
     * @param borrowAmount The amount of underlying the account would borrow
     * @return 0 if the borrow is allowed, otherwise a semi-opaque error code (See ErrorReporter.sol)
     */
    function borrowAllowed(address cToken, address borrower, uint borrowAmount) override external returns (uint) {
        // Pausing is a very serious situation - we revert to sound the alarms
        if (borrowGuardianPaused[cToken]) revert BorrowPaused();

        if (!markets[cToken].isListed) {
            return uint(Error.MARKET_NOT_LISTED);
        }

        if (!markets[cToken].accountMembership[borrower]) {
            // only cTokens may call borrowAllowed if borrower not in market
            if (msg.sender != cToken) revert SenderNotCToken();

            // attempt to add borrower to the market
            addToMarketInternal(CToken(msg.sender), borrower);

            // it should be impossible to break the important invariant
            assert(markets[cToken].accountMembership[borrower]);
        }

        if (oracle.getUnderlyingPrice(CToken(cToken)) == 0) {
            return uint(Error.PRICE_ERROR);
        }

        uint borrowCap = borrowCaps[cToken];
        // Borrow cap of 0 corresponds to unlimited borrowing
        if (borrowCap != 0) {
            uint totalBorrows = CToken(cToken).totalBorrows();
            uint nextTotalBorrows = FixedMath.add_(totalBorrows, borrowAmount);
            if (nextTotalBorrows >= borrowCap) revert BorrowCapReached();
        }

        (Error err2, , uint shortfall) = getHypotheticalAccountLiquidityInternal(borrower, CToken(cToken), 0, borrowAmount);
        if (err2 != Error.NO_ERROR) {
            return uint(err2);
        }
        if (shortfall > 0) {
            return uint(Error.INSUFFICIENT_LIQUIDITY);
        }

        // Keep the flywheel moving
        FixedMath.Exp borrowIndex = FixedMath.Exp.wrap(CToken(cToken).borrowIndex());
        updateCompBorrowIndex(cToken, borrowIndex);
        // distributeBorrowerComp(cToken, borrower, borrowIndex);

        return uint(Error.NO_ERROR);
    }

    /**
     * @notice Checks if the account should be allowed to repay a borrow in the given market
     * @param cToken The market to verify the repay against
     * @param payer The account which would repay the asset
     * @param borrower The account which would borrowed the asset
     * @param repayAmount The amount of the underlying asset the account would repay
     * @return 0 if the repay is allowed, otherwise a semi-opaque error code (See ErrorReporter.sol)
     */
    function repayBorrowAllowed(
        address cToken,
        address payer,
        address borrower,
        uint repayAmount) override external returns (uint) {
        // Shh - currently unused
        payer;
        borrower;
        repayAmount;

        if (!markets[cToken].isListed) {
            return uint(Error.MARKET_NOT_LISTED);
        }

        // Keep the flywheel moving
        FixedMath.Exp borrowIndex = FixedMath.Exp.wrap(CToken(cToken).borrowIndex());
        updateCompBorrowIndex(cToken, borrowIndex);
        // distributeBorrowerComp(cToken, borrower, borrowIndex);

        return uint(Error.NO_ERROR);
    }

    /**
     * @notice Checks if the liquidation should be allowed to occur
     * @param cTokenBorrowed Asset which was borrowed by the borrower
     * @param cTokenCollateral Asset which was used as collateral and will be seized
     * @param liquidator The address repaying the borrow and seizing the collateral
     * @param borrower The address of the borrower
     * @param repayAmount The amount of underlying being repaid
     */
    function liquidateBorrowAllowed(
        address cTokenBorrowed,
        address cTokenCollateral,
        address liquidator,
        address borrower,
        uint repayAmount) override view external returns (uint) {
        // Shh - currently unused
        liquidator;

        if (!markets[cTokenBorrowed].isListed || !markets[cTokenCollateral].isListed) {
            return uint(Error.MARKET_NOT_LISTED);
        }

        uint borrowBalance = CToken(cTokenBorrowed).borrowBalanceStored(borrower);

        /* allow accounts to be liquidated if the market is deprecated */
        if (isDeprecated(CToken(cTokenBorrowed))) {
            if (borrowBalance < repayAmount) revert RepayTooMuch();
        } else {
            /* The borrower must have shortfall in order to be liquidatable */
            (uint err, , uint shortfall) = getAccountLiquidity(borrower);
            if (err != 0) {
                return err;
            }

            if (shortfall == 0) {
                return uint(Error.INSUFFICIENT_SHORTFALL);
            }

            /* The liquidator may not repay more than what is allowed by the closeFactor */
            uint maxClose = FixedMath.mul_ScalarTruncate(FixedMath.Exp.wrap(closeFactorMantissa), borrowBalance);
            if (repayAmount > maxClose) {
                return uint(Error.TOO_MUCH_REPAY);
            }
        }
        return uint(Error.NO_ERROR);
    }

    /**
     * @notice Checks if the seizing of assets should be allowed to occur
     * @param cTokenCollateral Asset which was used as collateral and will be seized
     * @param cTokenBorrowed Asset which was borrowed by the borrower
     * @param liquidator The address repaying the borrow and seizing the collateral
     * @param borrower The address of the borrower
     * @param seizeTokens The number of collateral tokens to seize
     */
    function seizeAllowed(
        address cTokenCollateral,
        address cTokenBorrowed,
        address liquidator,
        address borrower,
        uint seizeTokens) override external returns (uint) {
        // Pausing is a very serious situation - we revert to sound the alarms
        if (seizeGuardianPaused) revert SeizePaused();

        // Shh - currently unused
        seizeTokens;
        liquidator;
        borrower;

        if (!markets[cTokenCollateral].isListed || !markets[cTokenBorrowed].isListed) {
            return uint(Error.MARKET_NOT_LISTED);
        }

        if (CToken(cTokenCollateral).comptroller() != CToken(cTokenBorrowed).comptroller()) {
            return uint(Error.COMPTROLLER_MISMATCH);
        }

        // Keep the flywheel moving
        updateCompSupplyIndex(cTokenCollateral);
        // distributeSupplierComp(cTokenCollateral, borrower);
        // distributeSupplierComp(cTokenCollateral, liquidator);

        return uint(Error.NO_ERROR);
    }

    /**
     * @notice Checks if the account should be allowed to transfer tokens in the given market
     * @param cToken The market to verify the transfer against
     * @param src The account which sources the tokens
     * @param dst The account which receives the tokens
     * @param transferTokens The number of cTokens to transfer
     * @return 0 if the transfer is allowed, otherwise a semi-opaque error code (See ErrorReporter.sol)
     */
    function transferAllowed(address cToken, address src, address dst, uint transferTokens) override external returns (uint) {
        // Pausing is a very serious situation - we revert to sound the alarms
        if (transferGuardianPaused) revert TransferPaused();

        dst;
        
        // Currently the only consideration is whether or not
        //  the src is allowed to redeem this many tokens
        uint allowed = redeemAllowedInternal(cToken, src, transferTokens);
        if (allowed != uint(Error.NO_ERROR)) {
            return allowed;
        }

        // Keep the flywheel moving
        updateCompSupplyIndex(cToken);
        // distributeSupplierComp(cToken, src);
        // distributeSupplierComp(cToken, dst);

        return uint(Error.NO_ERROR);
    }

    /*** Liquidity/Liquidation Calculations ***/

    /**
     * @dev Local vars for avoiding stack-depth limits in calculating account liquidity.
     *  Note that `cTokenBalance` is the number of cTokens the account owns in the market,
     *  whereas `borrowBalance` is the amount of underlying that the account has borrowed.
     */
    struct AccountLiquidityLocalVars {
        uint sumCollateral;
        uint sumBorrowPlusEffects;
        uint cTokenBalance;
        uint borrowBalance;
        uint exchangeRateMantissa;
        uint oraclePriceMantissa;
        FixedMath.Exp collateralFactor;
        FixedMath.Exp exchangeRate;
        FixedMath.Exp oraclePrice;
        FixedMath.Exp tokensToDenom;
    }

    /**
     * @notice Determine the current account liquidity wrt collateral requirements
     * @return (possible error code (semi-opaque),
                account liquidity in excess of collateral requirements,
     *          account shortfall below collateral requirements)
     */
    function getAccountLiquidity(address account) public view returns (uint, uint, uint) {
        (Error err, uint liquidity, uint shortfall) = getHypotheticalAccountLiquidityInternal(account, CToken(address(0)), 0, 0);
        // (Error err, uint liquidity, uint shortfall) = getAccountLiquidityInternal(account);
        return (uint(err), liquidity, shortfall);
    }

    /**
     * @notice Determine the current account liquidity wrt collateral requirements
     * @return (possible error code,
                account liquidity in excess of collateral requirements,
     *          account shortfall below collateral requirements)
     */
    // function getAccountLiquidityInternal(address account) internal view returns (Error, uint, uint) {
    //     return getHypotheticalAccountLiquidityInternal(account, CToken(address(0)), 0, 0);
    // }

    /**
     * @notice Determine what the account liquidity would be if the given amounts were redeemed/borrowed
     * @param cTokenModify The market to hypothetically redeem/borrow in
     * @param account The account to determine liquidity for
     * @param redeemTokens The number of tokens to hypothetically redeem
     * @param borrowAmount The amount of underlying to hypothetically borrow
     * @return (possible error code (semi-opaque),
                hypothetical account liquidity in excess of collateral requirements,
     *          hypothetical account shortfall below collateral requirements)
     */
    function getHypotheticalAccountLiquidity(
        address account,
        address cTokenModify,
        uint redeemTokens,
        uint borrowAmount) public view returns (uint, uint, uint) {
        (Error err, uint liquidity, uint shortfall) = getHypotheticalAccountLiquidityInternal(account, CToken(cTokenModify), redeemTokens, borrowAmount);
        return (uint(err), liquidity, shortfall);
    }

    /**
     * @notice Determine what the account liquidity would be if the given amounts were redeemed/borrowed
     * @param cTokenModify The market to hypothetically redeem/borrow in
     * @param account The account to determine liquidity for
     * @param redeemTokens The number of tokens to hypothetically redeem
     * @param borrowAmount The amount of underlying to hypothetically borrow
     * @dev Note that we calculate the exchangeRateStored for each collateral cToken using stored data,
     *  without calculating accumulated interest.
     * @return (possible error code,
                hypothetical account liquidity in excess of collateral requirements,
     *          hypothetical account shortfall below collateral requirements)
     */
    function getHypotheticalAccountLiquidityInternal(
        address account,
        CToken cTokenModify,
        uint redeemTokens,
        uint borrowAmount) internal view returns (Error, uint, uint) {

        AccountLiquidityLocalVars memory vars; // Holds all our calculation results
        // uint oErr;

        // For each asset the account is in
        CToken[] memory assets = accountAssets[account];
        for (uint i = 0; i < assets.length; i++) {
            CToken asset = assets[i];

            // Read the balances and exchange rate from the cToken
            (,vars.cTokenBalance, vars.borrowBalance, vars.exchangeRateMantissa) = asset.getAccountSnapshot(account);
           
            vars.collateralFactor = FixedMath.Exp.wrap(markets[address(asset)].liquidateCollateralFactorMantissa);
            vars.exchangeRate = FixedMath.Exp.wrap(vars.exchangeRateMantissa);

            // Get the normalized price of the asset
            vars.oraclePriceMantissa = oracle.getUnderlyingPrice(asset);
            if (vars.oraclePriceMantissa == 0) {
                return (Error.PRICE_ERROR, 0, 0);
            }
            vars.oraclePrice = FixedMath.Exp.wrap(vars.oraclePriceMantissa);

            // Pre-compute a conversion factor from tokens -> ether (normalized price value)
            vars.tokensToDenom = FixedMath.mul_(FixedMath.mul_(vars.collateralFactor, vars.exchangeRate), vars.oraclePrice);

            // sumCollateral += tokensToDenom * cTokenBalance
            vars.sumCollateral = FixedMath.mul_ScalarTruncateAddUInt(vars.tokensToDenom, vars.cTokenBalance, vars.sumCollateral);

            // sumBorrowPlusEffects += oraclePrice * borrowBalance
            vars.sumBorrowPlusEffects = FixedMath.mul_ScalarTruncateAddUInt(vars.oraclePrice, vars.borrowBalance, vars.sumBorrowPlusEffects);

            // Calculate effects of interacting with cTokenModify
            if (asset == cTokenModify) {
                // redeem effect
                // sumBorrowPlusEffects += tokensToDenom * redeemTokens
                vars.sumBorrowPlusEffects = FixedMath.mul_ScalarTruncateAddUInt(vars.tokensToDenom, redeemTokens, vars.sumBorrowPlusEffects);

                // borrow effect
                // sumBorrowPlusEffects += oraclePrice * borrowAmount
                vars.sumBorrowPlusEffects = FixedMath.mul_ScalarTruncateAddUInt(vars.oraclePrice, borrowAmount, vars.sumBorrowPlusEffects);
            }
        }

        if (smartAccountFactory.isValidSmartAccount(account)) {
            uint extraCollateral = ISmartAccount(account).getNonStandardCollateralAssetValue();
            vars.sumCollateral = vars.sumCollateral + extraCollateral;
        }

        // These are safe, as the underflow condition is checked first
        if (vars.sumCollateral > vars.sumBorrowPlusEffects) {
            return (Error.NO_ERROR, vars.sumCollateral - vars.sumBorrowPlusEffects, 0);
        } else {
            return (Error.NO_ERROR, 0, vars.sumBorrowPlusEffects - vars.sumCollateral);
        }
    }

    /**
     * @notice Calculate number of tokens of collateral asset to seize given an underlying amount
     * @dev Used in liquidation (called in cToken.liquidateBorrowFresh)
     * @param cTokenBorrowed The address of the borrowed cToken
     * @param cTokenCollateral The address of the collateral cToken
     * @param actualRepayAmount The amount of cTokenBorrowed underlying to convert into cTokenCollateral tokens
     * @return (errorCode, number of cTokenCollateral tokens to be seized in a liquidation)
     */
    function liquidateCalculateSeizeTokens(address cTokenBorrowed, address cTokenCollateral, uint actualRepayAmount) override external view returns (uint, uint) {
        /* Read oracle prices for borrowed and collateral markets */
        uint priceBorrowedMantissa = oracle.getUnderlyingPrice(CToken(cTokenBorrowed));
        uint priceCollateralMantissa = oracle.getUnderlyingPrice(CToken(cTokenCollateral));
        if (priceBorrowedMantissa == 0 || priceCollateralMantissa == 0) revert PriceError();

        /*
         * Get the exchange rate and calculate the number of collateral tokens to seize:
         *  seizeAmount = actualRepayAmount * liquidationIncentive * priceBorrowed / priceCollateral
         *  seizeTokens = seizeAmount / exchangeRate
         *   = actualRepayAmount * (liquidationIncentive * priceBorrowed) / (priceCollateral * exchangeRate)
         */
        uint exchangeRateMantissa = CToken(cTokenCollateral).exchangeRateStored(); // Note: reverts on error
        uint seizeTokens;
        FixedMath.Exp numerator;
        FixedMath.Exp denominator;
        FixedMath.Exp ratio;

        uint liquidationIncentive = markets[cTokenCollateral].liquidationIncentiveMantissa;
        numerator = FixedMath.mul_(FixedMath.Exp.wrap(liquidationIncentive), FixedMath.Exp.wrap(priceBorrowedMantissa));
        denominator = FixedMath.mul_(FixedMath.Exp.wrap(priceCollateralMantissa), FixedMath.Exp.wrap(exchangeRateMantissa));
        ratio = FixedMath.mul_(numerator, denominator);

        seizeTokens = FixedMath.mul_ScalarTruncate(ratio, actualRepayAmount);

        return (uint(Error.NO_ERROR), seizeTokens);
    }

    /*** Admin Functions ***/

    /**
      * @notice Sets a new price oracle for the comptroller
      * @dev Admin function to set a new price oracle
      * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
      */
    function _setPriceOracle(PriceOracle newOracle) public returns (uint) {
        // Check caller is admin
        if (msg.sender != admin) revert Unauthorized();

      // Emit NewPriceOracle(oldOracle, newOracle)
        emit NewPriceOracle(oracle, newOracle);

        // Set comptroller's oracle to newOracle
        oracle = newOracle;

        return uint(Error.NO_ERROR);
    }

    /**
      * @notice Sets the closeFactor used when liquidating borrows
      * @dev Admin function to set closeFactor
      * @param newCloseFactorMantissa New close factor, scaled by 1e18
      * @return uint 0=success, otherwise a failure
      */
    function _setCloseFactor(uint newCloseFactorMantissa) external returns (uint) {
        // Check caller is admin
        if (msg.sender != admin) revert Unauthorized();
        
        emit NewCloseFactor(closeFactorMantissa, newCloseFactorMantissa);

        closeFactorMantissa = newCloseFactorMantissa;

        return uint(Error.NO_ERROR);
    }

    /**
      * @notice Sets the collateralFactor for a market
      * @dev Admin function to set per-market collateralFactor
      * @param cToken The market to set the factor on
      * @param newCollateralFactorMantissa The new collateral factor, scaled by 1e18
      * @return uint 0=success, otherwise a failure. (See ErrorReporter for details)
      */
    function _setCollateralFactor(CToken cToken, uint newCollateralFactorMantissa, uint liquidateCollateralFactorExtra) external returns (uint) {
        // Check caller is admin
        if (msg.sender != admin) revert Unauthorized();

        // Verify market is listed
        Market storage market = markets[address(cToken)];
        if (!market.isListed) revert MarketNotListed();

        if (newCollateralFactorMantissa > collateralFactorMaxMantissa) revert InvalidCollaternalFactor();

        // If collateral factor != 0, fail if price == 0
        if (newCollateralFactorMantissa != 0 && oracle.getUnderlyingPrice(cToken) == 0) revert PriceError();

        // Emit event with asset, old collateral factor, and new collateral factor
        emit NewCollateralFactor(cToken, market.collateralFactorMantissa, newCollateralFactorMantissa);
    
        market.collateralFactorMantissa = newCollateralFactorMantissa;
        uint newLiquidateCollateralFactorMantissa = newCollateralFactorMantissa + liquidateCollateralFactorExtra;
        if (newLiquidateCollateralFactorMantissa > FixedMath.mantissaOne) {
            newLiquidateCollateralFactorMantissa = FixedMath.mantissaOne;
        }
        market.liquidateCollateralFactorMantissa = newLiquidateCollateralFactorMantissa;

        return uint(Error.NO_ERROR);
    }


    /**
      * @notice Sets liquidationIncentive
      * @dev Admin function to set liquidationIncentive
      * @param newLiquidationIncentiveMantissa New liquidationIncentive scaled by 1e18
      * @return uint 0=success, otherwise a failure. (See ErrorReporter for details)
      */
    function _setLiquidationIncentive(uint newLiquidationIncentiveMantissa, address cToken) external returns (uint) {
        // Check caller is admin
        if (msg.sender != admin) revert Unauthorized();

        if (cToken != address(0)) {
            // Verify market is listed
            Market storage market = markets[cToken];
            if (!market.isListed) revert MarketNotListed();

            emit NewMarketLiquidationIncentive(cToken, liquidationIncentiveMantissa, newLiquidationIncentiveMantissa);

            market.liquidationIncentiveMantissa = newLiquidationIncentiveMantissa;

            return uint(Error.NO_ERROR);
        }
        
        // Emit event with old incentive, new incentive
        emit NewLiquidationIncentive(liquidationIncentiveMantissa, newLiquidationIncentiveMantissa);

        liquidationIncentiveMantissa = newLiquidationIncentiveMantissa;

        return uint(Error.NO_ERROR);
    }

    /**
      * @notice Add the market to the markets mapping and set it as listed
      * @dev Admin function to set isListed and add support for the market
      * @param cToken The address of the market (token) to list
      * @return uint 0=success, otherwise a failure. (See enum Error for details)
      */
    function _supportMarket(CToken cToken) external returns (uint) {
        if (msg.sender != admin) revert Unauthorized();

        if (markets[address(cToken)].isListed) revert MarketAlreadyListed();

        cToken.isCToken(); // Sanity check to make sure its really a CToken

        // Note that isComped is not in active use anymore
        Market storage newMarket = markets[address(cToken)];
        newMarket.isListed = true;
        newMarket.collateralFactorMantissa = 0;
        newMarket.liquidationIncentiveMantissa = liquidationIncentiveMantissa;

        _addMarketInternal(address(cToken));
        // _initializeMarket(address(cToken));

        emit MarketListed(cToken);

        return uint(Error.NO_ERROR);
    }

    function _addMarketInternal(address cToken) internal {
        for (uint i = 0; i < allMarkets.length; i ++) {
            require(allMarkets[i] != CToken(cToken), "market already added");
        }
        allMarkets.push(CToken(cToken));
    }

    // function _initializeMarket(address cToken) internal {
    //     uint32 blockNumber = uint32(getBlockNumber());

    //     CompMarketState storage supplyState = compSupplyState[cToken];
    //     CompMarketState storage borrowState = compBorrowState[cToken];

    //     /*
    //      * Update market state indices
    //      */
    //     if (supplyState.index == 0) {
    //         // Initialize supply state index with default value
    //         supplyState.index = compInitialIndex;
    //     }

    //     if (borrowState.index == 0) {
    //         // Initialize borrow state index with default value
    //         borrowState.index = compInitialIndex;
    //     }

    //     /*
    //      * Update market state block numbers
    //      */
    //      supplyState.block = borrowState.block = blockNumber;
    // }


    /**
      * @notice Set the given borrow caps for the given cToken markets. Borrowing that brings total borrows to or above borrow cap will revert.
      * @dev Admin or borrowCapGuardian function to set the borrow caps. A borrow cap of 0 corresponds to unlimited borrowing.
      * @param cTokens The addresses of the markets (tokens) to change the borrow caps for
      * @param newBorrowCaps The new borrow cap values in underlying to be set. A value of 0 corresponds to unlimited borrowing.
      */
    function _setMarketBorrowCaps(CToken[] calldata cTokens, uint[] calldata newBorrowCaps) external {
        if (msg.sender != admin) revert Unauthorized();

        uint numMarkets = cTokens.length;
        uint numBorrowCaps = newBorrowCaps.length;

        require(numMarkets != 0 && numMarkets == numBorrowCaps, "invalid input");

        for(uint i = 0; i < numMarkets; i++) {
            borrowCaps[address(cTokens[i])] = newBorrowCaps[i];
            emit NewBorrowCap(cTokens[i], newBorrowCaps[i]);
        }
    }

    /**
     * @notice Admin function to change the Pause Guardian
     * @param newPauseGuardian The address of the new Pause Guardian
     */
    function _setPauseGuardian(address newPauseGuardian) external {
        if (msg.sender != admin) revert Unauthorized();

        // Emit NewPauseGuardian(OldPauseGuardian, NewPauseGuardian)
        emit NewPauseGuardian(pauseGuardian, newPauseGuardian);

        // Store pauseGuardian with value newPauseGuardian
        pauseGuardian = newPauseGuardian;
    }

    function _setMintPaused(CToken cToken, bool state) public returns (bool) {
        if (!markets[address(cToken)].isListed) revert MarketNotListed();
        checkPermission(state);
        mintGuardianPaused[address(cToken)] = state;
        emit ActionPaused(cToken, "Mint", state);
        return state;
    }

    function _setBorrowPaused(CToken cToken, bool state) public returns (bool) {
        if (!markets[address(cToken)].isListed) revert MarketNotListed();
        checkPermission(state);
        borrowGuardianPaused[address(cToken)] = state;
        emit ActionPaused(cToken, "Borrow", state);
        return state;
    }

    function _setTransferPaused(bool state) public returns (bool) {
        checkPermission(state);
        transferGuardianPaused = state;
        emit ActionPausedGlobally("Transfer", state);
        return state;
    }

    function _setSeizePaused(bool state) external returns (bool) {
        checkPermission(state);
        seizeGuardianPaused = state;
        emit ActionPausedGlobally("Seize", state);
        return state;
    }

    function _setRewardsPool(RewardsPool rewardsPool_) external {
        if (msg.sender != admin) revert Unauthorized();
        
        rewardsPool = rewardsPool_;
    }

    function _setSmartAccountFactory(ISmartAccountFactory smartAccountFactory_) external {
        if (msg.sender != admin) revert Unauthorized();

        smartAccountFactory = smartAccountFactory_;
    }

    function checkPermission(bool state) private view {
        if (msg.sender != pauseGuardian && msg.sender != admin) revert Unauthorized();
        if (msg.sender != admin && state != true) revert Unauthorized();
    }

    function _become(Unitroller unitroller) external {
        if (msg.sender!= unitroller.admin()) revert Unauthorized();
        if (unitroller._acceptImplementation() != 0) revert Unauthorized();
    }

    /**
     * @notice Checks caller is admin, or this contract is becoming the new implementation
     */
    function adminOrInitializing() internal view returns (bool) {
        return msg.sender == admin || msg.sender == comptrollerImplementation;
    }

    /**
     * @notice Accrue COMP to the market by updating the supply index
     * @param cToken The market whose supply index to update
     * @dev Index is a cumulative sum of the COMP per cToken accrued.
     */
    function updateCompSupplyIndex(address cToken) public {
        if (address(rewardsPool) != address(0)) {
            rewardsPool.updateRewardsSupplyIndex(cToken);
        }
    }

    /**
     * @notice Accrue COMP to the market by updating the borrow index
     * @param cToken The market whose borrow index to update
     * @dev Index is a cumulative sum of the COMP per cToken accrued.
     */
    function updateCompBorrowIndex(address cToken, FixedMath.Exp marketBorrowIndex) public {
        if (address(rewardsPool) != address(0)) {
            rewardsPool.updateRewardsBorrowIndex(cToken, marketBorrowIndex);
        }
    }

    /**
     * @notice Return all of the markets
     * @dev The automatic getter may be used to access an individual market.
     * @return The list of market addresses
     */
    function getAllMarkets() public view returns (CToken[] memory) {
        return allMarkets;
    }

    /**
     * @notice Returns true if the given cToken market has been deprecated
     * @dev All borrows in a deprecated cToken market can be immediately liquidated
     * @param cToken The market to check if deprecated
     */
    function isDeprecated(CToken cToken) internal view returns (bool) {
        return
            markets[address(cToken)].collateralFactorMantissa == 0 &&
            borrowGuardianPaused[address(cToken)] == true &&
            cToken.reserveFactorMantissa() == 1e18
        ;
    }

    function getBlockNumber() virtual public view returns (uint) {
        return block.number;
    }

    function isValidSmartAccount(address account) virtual external override returns (bool) {
        return smartAccountFactory.isValidSmartAccount(account);
    }
}
