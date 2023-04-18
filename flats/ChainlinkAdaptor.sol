// Sources flattened with hardhat v2.13.0 https://hardhat.org

// File contracts/ErrorReporter.sol

// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.10;

contract ComptrollerErrorReporter {
    error IllegalArgument();
    error PriceError();
    error Unauthorized();
    error MarketNotListed();
    error ExitMarketBalanceOwned();
    error MintPaused();
    error RedeemTokensZero();
    error BorrowPaused();
    error SenderNotCToken();
    error BorrowCapReached();
    error RepayTooMuch();
    error SeizePaused();
    error TransferPaused();
    error MarketAlreadyListed();
    error InvalidBlockNumber();
    error InvalidCollaternalFactor();
    error ExitMarketFailed(uint);
    enum Error {
        NO_ERROR,
        COMPTROLLER_MISMATCH,
        INSUFFICIENT_SHORTFALL,
        INSUFFICIENT_LIQUIDITY,
        MARKET_NOT_LISTED,
        PRICE_ERROR,
        TOO_MUCH_REPAY
    }
}

contract TokenErrorReporter {
    uint public constant NO_ERROR = 0; // support legacy return codes

    error TransferComptrollerRejection(uint256 errorCode);
    error TransferNotAllowed();
    error TransferNotEnough();
    error TransferTooMuch();

    error MintComptrollerRejection(uint256 errorCode);
    error MintFreshnessCheck();

    error RedeemComptrollerRejection(uint256 errorCode);
    error RedeemFreshnessCheck();
    error RedeemTransferOutNotPossible();

    error BorrowComptrollerRejection(uint256 errorCode);
    error BorrowFreshnessCheck();
    error BorrowCashNotAvailable();

    error RepayBorrowComptrollerRejection(uint256 errorCode);
    error RepayBorrowFreshnessCheck();

    error LiquidateComptrollerRejection(uint256 errorCode);
    error LiquidateFreshnessCheck();
    error LiquidateCollateralFreshnessCheck();
    error LiquidateAccrueBorrowInterestFailed(uint256 errorCode);
    error LiquidateAccrueCollateralInterestFailed(uint256 errorCode);
    error LiquidateLiquidatorIsBorrower();
    error LiquidateCloseAmountIsZero();
    error LiquidateCloseAmountIsUintMax();
    error LiquidateRepayBorrowFreshFailed(uint256 errorCode);

    error LiquidateSeizeComptrollerRejection(uint256 errorCode);
    error LiquidateSeizeLiquidatorIsBorrower();

    error AcceptAdminPendingAdminCheck();

    error SetComptrollerOwnerCheck();
    error SetPendingAdminOwnerCheck();

    error SetReserveFactorAdminCheck();
    error SetReserveFactorFreshCheck();
    error SetReserveFactorBoundsCheck();

    error AddReservesFactorFreshCheck(uint256 actualAddAmount);

    error ReduceReservesAdminCheck();
    error ReduceReservesFreshCheck();
    error ReduceReservesCashNotAvailable();
    error ReduceReservesCashValidation();

    error SetInterestRateModelOwnerCheck();
    error SetInterestRateModelFreshCheck();

    error InitialExchangeRateCannotBeZero();
    error MarketAlreadyInitialized();
    error Unauthorized();
    error BorrowRateTooHigh();
    error RedeemTokensInOrRedeemAmountInShouldBeZero();
    error LiquidateSizeTooMuch();
    error NotComptroller();
    error InvalidContractAddress();
}


// File contracts/FixedMath.sol


pragma solidity ^0.8.10;

/**
 * @title Exponential module for storing fixed-precision decimals
 * @author Compound
 * @notice Exp is a struct which stores decimals with a fixed precision of 18 decimal places.
 *         Thus, if we wanted to store the 5.1, mantissa would store 5.1e18. That is:
 *         `Exp({mantissa: 5100000000000000000})`.
 */
library FixedMath {
    error InvalidNumber(uint);
    uint constant expScale = 1e18;
    uint constant doubleScale = 1e36;
    uint constant halfExpScale = expScale/2;
    uint constant mantissaOne = expScale;

    type Exp is uint;
 
    type Double is uint;

    /**
     * @dev Truncates the given exp to a whole number value.
     *      For example, truncate(Exp{mantissa: 15 * expScale}) = 15
     */
    function truncate(Exp exp) pure internal returns (uint) {
        // Note: We are not using careful math here as we're performing a division that cannot fail
        return Exp.unwrap(exp) / expScale;
    }

    /**
     * @dev Multiply an Exp by a scalar, then truncate to return an unsigned integer.
     */
    function mul_ScalarTruncate(Exp a, uint scalar) pure internal returns (uint) {
        Exp product = mul_(a, scalar);
        return truncate(product);
    }

    /**
     * @dev Multiply an Exp by a scalar, truncate, then add an to an unsigned integer, returning an unsigned integer.
     */
    function mul_ScalarTruncateAddUInt(Exp a, uint scalar, uint addend) pure internal returns (uint) {
        Exp product = mul_(a, scalar);
        return add_(truncate(product), addend);
    }

    /**
     * @dev Checks if first Exp is less than second Exp.
     */
    function lessThanExp(Exp left, Exp right) pure internal returns (bool) {
        return Exp.unwrap(left) < Exp.unwrap(right);
    }

    /**
     * @dev Checks if left Exp <= right Exp.
     */
    function lessThanOrEqualExp(Exp left, Exp right) pure internal returns (bool) {
        return Exp.unwrap(left) <= Exp.unwrap(right);
    }

    /**
     * @dev Checks if left Exp > right Exp.
     */
    function greaterThanExp(Exp left, Exp right) pure internal returns (bool) {
        return Exp.unwrap(left) > Exp.unwrap(right);
    }

    /**
     * @dev returns true if Exp is exactly zero
     */
    function isZeroExp(Exp value) pure internal returns (bool) {
        return Exp.unwrap(value) == 0;
    }

    function safe224(uint n) pure internal returns (uint224) {
        if (n >= 2**224) revert InvalidNumber(n);
        return uint224(n);
    }

    function safe32(uint n) pure internal returns (uint32) {
        if (n >= 2**32) revert InvalidNumber(n);
        return uint32(n);
    }

    function add_(Exp a, Exp b) pure internal returns (Exp) {
        return Exp.wrap(add_(Exp.unwrap(a), Exp.unwrap(b)));
    }

    function add_(Double a, Double b) pure internal returns (Double) {
        return Double.wrap(add_(Double.unwrap(a), Double.unwrap(b)));
    }

    function add_(uint a, uint b) pure internal returns (uint) {
        return a + b;
    }

    function sub_(Exp a, Exp b) pure internal returns (Exp) {
        return Exp.wrap(sub_(Exp.unwrap(a), Exp.unwrap(b)));
    }

    function sub_(Double a, Double b) pure internal returns (Double) {
        return Double.wrap(sub_(Double.unwrap(a), Double.unwrap(b)));
    }

    function sub_(uint a, uint b) pure internal returns (uint) {
        return a - b;
    }

    function mul_(Exp a, Exp b) pure internal returns (Exp) {
        return Exp.wrap(mul_(Exp.unwrap(a), Exp.unwrap(b)) / expScale);
    }

    function mul_(Exp a, uint b) pure internal returns (Exp) {
        return Exp.wrap(mul_(Exp.unwrap(a), b));
    }

    function mul_(uint a, Exp b) pure internal returns (uint) {
        return mul_(a, Exp.unwrap(b)) / expScale;
    }

    function mul_(Double a, Double b) pure internal returns (Double) {
        return Double.wrap(mul_(Double.unwrap(a), Double.unwrap(b)) / doubleScale);
    }

    function mul_(Double a, uint b) pure internal returns (Double) {
        return Double.wrap(mul_(Double.unwrap(a), b));
    }

    function mul_(uint a, Double b) pure internal returns (uint) {
        return mul_(a, Double.unwrap(b)) / doubleScale;
    }

    function mul_(uint a, uint b) pure internal returns (uint) {
        return a * b;
    }

    function div_(Exp a, Exp b) pure internal returns (Exp) {
        return Exp.wrap(div_(mul_(Exp.unwrap(a), expScale), Exp.unwrap(b)));
    }

    function div_(Exp a, uint b) pure internal returns (Exp) {
        return Exp.wrap(div_(Exp.unwrap(a), b));
    }

    function div_(uint a, Exp b) pure internal returns (uint) {
        return div_(mul_(a, expScale), Exp.unwrap(b));
    }

    function div_(Double a, Double b) pure internal returns (Double) {
        return Double.wrap(div_(mul_(Double.unwrap(a), doubleScale), Double.unwrap(b)));
    }

    function div_(Double a, uint b) pure internal returns (Double) {
        return Double.wrap(div_(Double.unwrap(a), b));
    }

    function div_(uint a, Double b) pure internal returns (uint) {
        return div_(mul_(a, doubleScale), Double.unwrap(b));
    }

    function div_(uint a, uint b) pure internal returns (uint) {
        return a / b;
    }

    function fraction(uint a, uint b) pure internal returns (Double) {
        return Double.wrap(div_(mul_(a, doubleScale), b));
    }
}


// File contracts/Interfaces/ISmartAccountFactory.sol


pragma solidity ^0.8.10;

interface ISmartAccountFactory {
    function isValidSmartAccount(address account) external view returns (bool);
}


// File contracts/Interfaces/ComptrollerInterface.sol


pragma solidity ^0.8.10;

abstract contract ComptrollerInterface {
    /// @notice Indicator that this is a Comptroller contract (for inspection)
    bool public constant isComptroller = true;

    /*** Assets You Are In ***/

    function enterMarkets(address[] calldata cTokens) virtual external;
    function exitMarket(address cToken) virtual external;

    /*** Policy Hooks ***/

    function mintAllowed(address cToken, address minter, uint mintAmount) virtual external returns (uint);

    function redeemAllowed(address cToken, address redeemer, uint redeemTokens) virtual external returns (uint);
    function redeemVerify(address cToken, address redeemer, uint redeemAmount, uint redeemTokens) virtual external;

    function borrowAllowed(address cToken, address borrower, uint borrowAmount) virtual external returns (uint);

    function repayBorrowAllowed(
        address cToken,
        address payer,
        address borrower,
        uint repayAmount) virtual external returns (uint);

    function liquidateBorrowAllowed(
        address cTokenBorrowed,
        address cTokenCollateral,
        address liquidator,
        address borrower,
        uint repayAmount) virtual external returns (uint);

    function seizeAllowed(
        address cTokenCollateral,
        address cTokenBorrowed,
        address liquidator,
        address borrower,
        uint seizeTokens) virtual external returns (uint);

    function transferAllowed(address cToken, address src, address dst, uint transferTokens) virtual external returns (uint);

    /*** Liquidity/Liquidation Calculations ***/

    function liquidateCalculateSeizeTokens(
        address cTokenBorrowed,
        address cTokenCollateral,
        uint repayAmount) virtual external view returns (uint, uint);
    
    function isValidSmartAccount(address account) virtual external returns (bool);
}


// File contracts/Interfaces/EIP20NonStandardInterface.sol


pragma solidity ^0.8.10;

/**
 * @title EIP20NonStandardInterface
 * @dev Version of ERC20 with no return values for `transfer` and `transferFrom`
 *  See https://medium.com/coinmonks/missing-return-value-bug-at-least-130-tokens-affected-d67bf08521ca
 */
interface EIP20NonStandardInterface {

    /**
     * @notice Get the total number of tokens in circulation
     * @return The supply of tokens
     */
    function totalSupply() external view returns (uint256);

    /**
     * @notice Gets the balance of the specified address
     * @param owner The address from which the balance will be retrieved
     * @return balance The balance
     */
    function balanceOf(address owner) external view returns (uint256 balance);

    ///
    /// !!!!!!!!!!!!!!
    /// !!! NOTICE !!! `transfer` does not return a value, in violation of the ERC-20 specification
    /// !!!!!!!!!!!!!!
    ///

    /**
      * @notice Transfer `amount` tokens from `msg.sender` to `dst`
      * @param dst The address of the destination account
      * @param amount The number of tokens to transfer
      */
    function transfer(address dst, uint256 amount) external;

    ///
    /// !!!!!!!!!!!!!!
    /// !!! NOTICE !!! `transferFrom` does not return a value, in violation of the ERC-20 specification
    /// !!!!!!!!!!!!!!
    ///

    /**
      * @notice Transfer `amount` tokens from `src` to `dst`
      * @param src The address of the source account
      * @param dst The address of the destination account
      * @param amount The number of tokens to transfer
      */
    function transferFrom(address src, address dst, uint256 amount) external;

    /**
      * @notice Approve `spender` to transfer up to `amount` from `src`
      * @dev This will overwrite the approval amount for `spender`
      *  and is subject to issues noted [here](https://eips.ethereum.org/EIPS/eip-20#approve)
      * @param spender The address of the account which may transfer tokens
      * @param amount The number of tokens that are approved
      * @return success Whether or not the approval succeeded
      */
    function approve(address spender, uint256 amount) external returns (bool success);

    /**
      * @notice Get the current allowance from `owner` for `spender`
      * @param owner The address of the account which owns the tokens to be spent
      * @param spender The address of the account which may transfer tokens
      * @return remaining The number of tokens allowed to be spent
      */
    function allowance(address owner, address spender) external view returns (uint256 remaining);

    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);
}


// File contracts/Interfaces/InterestRateModel.sol


pragma solidity ^0.8.10;

/**
  * @title Compound's InterestRateModel Interface
  * @author Compound
  */
abstract contract InterestRateModel {
    /// @notice Indicator that this is an InterestRateModel contract (for inspection)
    bool public constant isInterestRateModel = true;

    /**
      * @notice Calculates the current borrow interest rate per block
      * @param cash The total amount of cash the market has
      * @param borrows The total amount of borrows the market has outstanding
      * @param reserves The total amount of reserves the market has
      * @return The borrow rate per block (as a percentage, and scaled by 1e18)
      */
    function getBorrowRate(uint cash, uint borrows, uint reserves) virtual external view returns (uint);

    /**
      * @notice Calculates the current supply interest rate per block
      * @param cash The total amount of cash the market has
      * @param borrows The total amount of borrows the market has outstanding
      * @param reserves The total amount of reserves the market has
      * @param reserveFactorMantissa The current reserve factor the market has
      * @return The supply rate per block (as a percentage, and scaled by 1e18)
      */
    function getSupplyRate(uint cash, uint borrows, uint reserves, uint reserveFactorMantissa) virtual external view returns (uint);
}


// File contracts/Interfaces/CTokenInterfaces.sol


pragma solidity ^0.8.10;




contract CTokenStorage {
    /**
     * @dev Guard variable for re-entrancy checks
     */
    bool internal _notEntered;

    /**
     * @notice EIP-20 token name for this token
     */
    string public name;

    /**
     * @notice EIP-20 token symbol for this token
     */
    string public symbol;

    /**
     * @notice EIP-20 token decimals for this token
     */
    uint8 public decimals;

    // Maximum borrow rate that can ever be applied (.0005% / block)
    uint internal constant borrowRateMaxMantissa = 0.0005e16;

    // Maximum fraction of interest that can be set aside for reserves
    uint internal constant reserveFactorMaxMantissa = 1e18;

    /**
     * @notice Administrator for this contract
     */
    address payable public admin;

    /**
     * @notice Pending administrator for this contract
     */
    address payable public pendingAdmin;

    /**
     * @notice Contract which oversees inter-cToken operations
     */
    ComptrollerInterface public comptroller;

    /**
     * @notice Model which tells what the current interest rate should be
     */
    InterestRateModel public interestRateModel;

    // Initial exchange rate used when minting the first CTokens (used when totalSupply = 0)
    uint internal initialExchangeRateMantissa;

    /**
     * @notice Fraction of interest currently set aside for reserves
     */
    uint public reserveFactorMantissa;

    /**
     * @notice Block number that interest was last accrued at
     */
    uint public accrualBlockNumber;

    /**
     * @notice Accumulator of the total earned interest rate since the opening of the market
     */
    uint public borrowIndex;

    /**
     * @notice Total amount of outstanding borrows of the underlying in this market
     */
    uint public totalBorrows;

    /**
     * @notice Total amount of reserves of the underlying held in this market
     */
    uint public totalReserves;

    /**
     * @notice Total number of tokens in circulation
     */
    uint public totalSupply;

    // Official record of token balances for each account
    mapping (address => uint) internal accountTokens;

    // Approved token transfer amounts on behalf of others
    mapping (address => mapping (address => uint)) internal transferAllowances;

    /**
     * @notice Container for borrow balance information
     * @member principal Total balance (with accrued interest), after applying the most recent balance-changing action
     * @member interestIndex Global borrowIndex as of the most recent balance-changing action
     */
    struct BorrowSnapshot {
        uint principal;
        uint interestIndex;
    }

    // Mapping of account addresses to outstanding borrow balances
    mapping(address => BorrowSnapshot) internal accountBorrows;

    /**
     * @notice Share of seized collateral that is added to reserves
     */
    uint public constant protocolSeizeShareMantissa = 2.8e16; //2.8%
}

abstract contract CTokenInterface is CTokenStorage {
    /**
     * @notice Indicator that this is a CToken contract (for inspection)
     */
    bool public constant isCToken = true;


    /*** Market Events ***/

    /**
     * @notice Event emitted when interest is accrued
     */
    event AccrueInterest(uint cashPrior, uint interestAccumulated, uint borrowIndex, uint totalBorrows);

    /**
     * @notice Event emitted when tokens are minted
     */
    event Mint(address minter, uint mintAmount, uint mintTokens);

    /**
     * @notice Event emitted when tokens are redeemed
     */
    event Redeem(address redeemer, uint redeemAmount, uint redeemTokens);

    /**
     * @notice Event emitted when underlying is borrowed
     */
    event Borrow(address borrower, uint borrowAmount, uint accountBorrows, uint totalBorrows);

    /**
     * @notice Event emitted when a borrow is repaid
     */
    event RepayBorrow(address payer, address borrower, uint repayAmount, uint accountBorrows, uint totalBorrows);

    /**
     * @notice Event emitted when a borrow is liquidated
     */
    event LiquidateBorrow(address liquidator, address borrower, uint repayAmount, address cTokenCollateral, uint seizeTokens);


    /*** Admin Events ***/

    /**
     * @notice Event emitted when pendingAdmin is changed
     */
    event NewPendingAdmin(address oldPendingAdmin, address newPendingAdmin);

    /**
     * @notice Event emitted when pendingAdmin is accepted, which means admin is updated
     */
    event NewAdmin(address oldAdmin, address newAdmin);

    /**
     * @notice Event emitted when comptroller is changed
     */
    event NewComptroller(ComptrollerInterface oldComptroller, ComptrollerInterface newComptroller);

    /**
     * @notice Event emitted when interestRateModel is changed
     */
    event NewMarketInterestRateModel(InterestRateModel oldInterestRateModel, InterestRateModel newInterestRateModel);

    /**
     * @notice Event emitted when the reserve factor is changed
     */
    event NewReserveFactor(uint oldReserveFactorMantissa, uint newReserveFactorMantissa);

    /**
     * @notice Event emitted when the reserves are added
     */
    event ReservesAdded(address benefactor, uint addAmount, uint newTotalReserves);

    /**
     * @notice Event emitted when the reserves are reduced
     */
    event ReservesReduced(address admin, uint reduceAmount, uint newTotalReserves);

    /**
     * @notice EIP20 Transfer event
     */
    event Transfer(address indexed from, address indexed to, uint amount);

    /**
     * @notice EIP20 Approval event
     */
    event Approval(address indexed owner, address indexed spender, uint amount);


    /*** User Interface ***/

    function transfer(address dst, uint amount) virtual external returns (bool);
    function transferFrom(address src, address dst, uint amount) virtual external returns (bool);
    function approve(address spender, uint amount) virtual external returns (bool);
    function allowance(address owner, address spender) virtual external view returns (uint);
    function balanceOf(address owner) virtual external view returns (uint);
    function balanceOfUnderlying(address owner) virtual external returns (uint);
    function getAccountSnapshot(address account) virtual external view returns (uint, uint, uint, uint);
    function borrowRatePerBlock() virtual external view returns (uint);
    function supplyRatePerBlock() virtual external view returns (uint);
    function totalBorrowsCurrent() virtual external returns (uint);
    function borrowBalanceCurrent(address account) virtual external returns (uint);
    function borrowBalanceStored(address account) virtual external view returns (uint);
    function exchangeRateCurrent() virtual external returns (uint);
    function exchangeRateStored() virtual external view returns (uint);
    function getCash() virtual external view returns (uint);
    function accrueInterest() virtual external returns (uint);
    function seize(address liquidator, address borrower, uint seizeTokens) virtual external returns (uint);


    /*** Admin Functions ***/

    function _setPendingAdmin(address payable newPendingAdmin) virtual external returns (uint);
    function _acceptAdmin() virtual external returns (uint);
    function _setComptroller(ComptrollerInterface newComptroller) virtual external returns (uint);
    function _setReserveFactor(uint newReserveFactorMantissa) virtual external returns (uint);
    function _reduceReserves(uint reduceAmount) virtual external returns (uint);
    function _setInterestRateModel(InterestRateModel newInterestRateModel) virtual external returns (uint);
}

contract CErc20Storage {
    /**
     * @notice Underlying asset for this CToken
     */
    address public underlying;
}

abstract contract CErc20Interface is CErc20Storage {

    /*** User Interface ***/

    function mint(uint mintAmount) virtual external returns (uint);
    function redeem(uint redeemTokens) virtual external returns (uint);
    function redeemUnderlying(uint redeemAmount) virtual external returns (uint);
    function borrow(uint borrowAmount) virtual external returns (uint);
    function repayBorrow(uint repayAmount) virtual external returns (uint);
    function repayBorrowBehalf(address borrower, uint repayAmount) virtual external returns (uint);
    function liquidateBorrow(address borrower, uint repayAmount, CTokenInterface cTokenCollateral) virtual external returns (uint);
    function sweepToken(EIP20NonStandardInterface token) virtual external;


    /*** Admin Functions ***/
}

contract CDelegationStorage {
    /**
     * @notice Implementation address for this contract
     */
    address public implementation;
}

abstract contract CDelegatorInterface is CDelegationStorage {
    /**
     * @notice Emitted when implementation is changed
     */
    event NewImplementation(address oldImplementation, address newImplementation);

    /**
     * @notice Called by the admin to update the implementation of the delegator
     * @param implementation_ The address of the new implementation for delegation
     * @param allowResign Flag to indicate whether to call _resignImplementation on the old implementation
     * @param becomeImplementationData The encoded bytes data to be passed to _becomeImplementation
     */
    function _setImplementation(address implementation_, bool allowResign, bytes memory becomeImplementationData) virtual external;
}

abstract contract CDelegateInterface is CDelegationStorage {
    /**
     * @notice Called by the delegator on a delegate to initialize it for duty
     * @dev Should revert if any issues arise which make it unfit for delegation
     * @param data The encoded bytes data for any initialization
     */
    function _becomeImplementation(bytes memory data) virtual external;

    /**
     * @notice Called by the delegator on a delegate to forfeit its responsibility
     */
    function _resignImplementation() virtual external;
}


// File contracts/Interfaces/EIP20Interface.sol


pragma solidity ^0.8.10;

/**
 * @title ERC 20 Token Standard Interface
 *  https://eips.ethereum.org/EIPS/eip-20
 */
interface EIP20Interface {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);

    /**
      * @notice Get the total number of tokens in circulation
      * @return The supply of tokens
      */
    function totalSupply() external view returns (uint256);

    /**
     * @notice Gets the balance of the specified address
     * @param owner The address from which the balance will be retrieved
     * @return balance The balance
     */
    function balanceOf(address owner) external view returns (uint256 balance);

    /**
      * @notice Transfer `amount` tokens from `msg.sender` to `dst`
      * @param dst The address of the destination account
      * @param amount The number of tokens to transfer
      * @return success Whether or not the transfer succeeded
      */
    function transfer(address dst, uint256 amount) external returns (bool success);

    /**
      * @notice Transfer `amount` tokens from `src` to `dst`
      * @param src The address of the source account
      * @param dst The address of the destination account
      * @param amount The number of tokens to transfer
      * @return success Whether or not the transfer succeeded
      */
    function transferFrom(address src, address dst, uint256 amount) external returns (bool success);

    /**
      * @notice Approve `spender` to transfer up to `amount` from `src`
      * @dev This will overwrite the approval amount for `spender`
      *  and is subject to issues noted [here](https://eips.ethereum.org/EIPS/eip-20#approve)
      * @param spender The address of the account which may transfer tokens
      * @param amount The number of tokens that are approved (-1 means infinite)
      * @return success Whether or not the approval succeeded
      */
    function approve(address spender, uint256 amount) external returns (bool success);

    /**
      * @notice Get the current allowance from `owner` for `spender`
      * @param owner The address of the account which owns the tokens to be spent
      * @param spender The address of the account which may transfer tokens
      * @return remaining The number of tokens allowed to be spent (-1 means infinite)
      */
    function allowance(address owner, address spender) external view returns (uint256 remaining);

    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);
}


// File contracts/Interfaces/ISmartAccount.sol


pragma solidity ^0.8.10;

interface ISmartAccount {
    function getNonStandardCollateralAssetValue() external view returns (uint);
    function withdraw(address token, uint amount, address to) external;
    function liquidate(address borrower, address liquidator) external;
}


// File contracts/CToken.sol


pragma solidity ^0.8.10;








/**
 * @title Compound's CToken Contract
 * @notice Abstract base for CTokens
 * @author Compound
 */
abstract contract CToken is CTokenInterface, TokenErrorReporter {
    /**
     * @notice Initialize the money market
     * @param comptroller_ The address of the Comptroller
     * @param interestRateModel_ The address of the interest rate model
     * @param initialExchangeRateMantissa_ The initial exchange rate, scaled by 1e18
     * @param name_ EIP-20 name of this token
     * @param symbol_ EIP-20 symbol of this token
     * @param decimals_ EIP-20 decimal precision of this token
     */
    function initialize(ComptrollerInterface comptroller_,
                        InterestRateModel interestRateModel_,
                        uint initialExchangeRateMantissa_,
                        string memory name_,
                        string memory symbol_,
                        uint8 decimals_) public {
        if (msg.sender != admin) revert Unauthorized();
        if (accrualBlockNumber != 0 || borrowIndex != 0) revert MarketAlreadyInitialized();

        // Set initial exchange rate
        initialExchangeRateMantissa = initialExchangeRateMantissa_;
        if (initialExchangeRateMantissa == 0) revert InitialExchangeRateCannotBeZero();

        // Set the comptroller
        _setComptroller(comptroller_);

        // Initialize block number and borrow index (block number mocks depend on comptroller being set)
        accrualBlockNumber = getBlockNumber();
        borrowIndex = FixedMath.mantissaOne;

        // Set the interest rate model (depends on block number / borrow index)
        _setInterestRateModelFresh(interestRateModel_);

        name = name_;
        symbol = symbol_;
        decimals = decimals_;

        // The counter starts true to prevent changing it from zero to non-zero (i.e. smaller cost/refund)
        _notEntered = true;
    }

    /**
     * @notice Transfer `tokens` tokens from `src` to `dst` by `spender`
     * @dev Called by both `transfer` and `transferFrom` internally
     * @param spender The address of the account performing the transfer
     * @param src The address of the source account
     * @param dst The address of the destination account
     * @param tokens The number of tokens to transfer
     * @return 0 if the transfer succeeded, else revert
     */
    function transferTokens(address spender, address src, address dst, uint tokens) internal returns (uint) {
        /* Fail if transfer not allowed */
        uint allowed = comptroller.transferAllowed(address(this), src, dst, tokens);
        if (allowed != 0) {
            revert TransferComptrollerRejection(allowed);
        }

        /* Do not allow self-transfers */
        if (src == dst) {
            revert TransferNotAllowed();
        }

        /* Get the allowance, infinite for the account owner */
        uint startingAllowance = 0;
        if (spender == src) {
            startingAllowance = type(uint).max;
        } else {
            startingAllowance = transferAllowances[src][spender];
        }

        /////////////////////////
        // EFFECTS & INTERACTIONS
        // (No safe failures beyond this point)

        accountTokens[src] = accountTokens[src] - tokens;
        accountTokens[dst] = accountTokens[dst] + tokens;

        /* Eat some of the allowance (if necessary) */
        if (startingAllowance != type(uint).max) {
            transferAllowances[src][spender] = startingAllowance - tokens;
        }

        /* We emit a Transfer event */
        emit Transfer(src, dst, tokens);

        return NO_ERROR;
    }

    /**
     * @notice Transfer `amount` tokens from `msg.sender` to `dst`
     * @param dst The address of the destination account
     * @param amount The number of tokens to transfer
     * @return Whether or not the transfer succeeded
     */
    function transfer(address dst, uint256 amount) override external nonReentrant returns (bool) {
        return transferTokens(msg.sender, msg.sender, dst, amount) == NO_ERROR;
    }

    /**
     * @notice Transfer `amount` tokens from `src` to `dst`
     * @param src The address of the source account
     * @param dst The address of the destination account
     * @param amount The number of tokens to transfer
     * @return Whether or not the transfer succeeded
     */
    function transferFrom(address src, address dst, uint256 amount) override external nonReentrant returns (bool) {
        return transferTokens(msg.sender, src, dst, amount) == NO_ERROR;
    }

    /**
     * @notice Approve `spender` to transfer up to `amount` from `src`
     * @dev This will overwrite the approval amount for `spender`
     *  and is subject to issues noted [here](https://eips.ethereum.org/EIPS/eip-20#approve)
     * @param spender The address of the account which may transfer tokens
     * @param amount The number of tokens that are approved (uint256.max means infinite)
     * @return Whether or not the approval succeeded
     */
    function approve(address spender, uint256 amount) override external returns (bool) {
        address src = msg.sender;
        transferAllowances[src][spender] = amount;
        emit Approval(src, spender, amount);
        return true;
    }

    /**
     * @notice Get the current allowance from `owner` for `spender`
     * @param owner The address of the account which owns the tokens to be spent
     * @param spender The address of the account which may transfer tokens
     * @return The number of tokens allowed to be spent (-1 means infinite)
     */
    function allowance(address owner, address spender) override external view returns (uint256) {
        return transferAllowances[owner][spender];
    }

    /**
     * @notice Get the token balance of the `owner`
     * @param owner The address of the account to query
     * @return The number of tokens owned by `owner`
     */
    function balanceOf(address owner) override external view returns (uint256) {
        return accountTokens[owner];
    }

    /**
     * @notice Get the underlying balance of the `owner`
     * @dev This also accrues interest in a transaction
     * @param owner The address of the account to query
     * @return The amount of underlying owned by `owner`
     */
    function balanceOfUnderlying(address owner) override external returns (uint) {
        FixedMath.Exp exchangeRate = FixedMath.Exp.wrap(exchangeRateCurrent());
        return FixedMath.mul_ScalarTruncate(exchangeRate, accountTokens[owner]);
    }

    /**
     * @notice Get a snapshot of the account's balances, and the cached exchange rate
     * @dev This is used by comptroller to more efficiently perform liquidity checks.
     * @param account Address of the account to snapshot
     * @return (possible error, token balance, borrow balance, exchange rate mantissa)
     */
    function getAccountSnapshot(address account) override external view returns (uint, uint, uint, uint) {
        return (
            NO_ERROR,
            accountTokens[account],
            borrowBalanceStoredInternal(account),
            exchangeRateStoredInternal()
        );
    }

    /**
     * @dev Function to simply retrieve block number
     *  This exists mainly for inheriting test contracts to stub this result.
     */
    function getBlockNumber() virtual internal view returns (uint) {
        return block.number;
    }

    /**
     * @notice Returns the current per-block borrow interest rate for this cToken
     * @return The borrow interest rate per block, scaled by 1e18
     */
    function borrowRatePerBlock() override external view returns (uint) {
        return interestRateModel.getBorrowRate(getCashPrior(), totalBorrows, totalReserves);
    }

    /**
     * @notice Returns the current per-block supply interest rate for this cToken
     * @return The supply interest rate per block, scaled by 1e18
     */
    function supplyRatePerBlock() override external view returns (uint) {
        return interestRateModel.getSupplyRate(getCashPrior(), totalBorrows, totalReserves, reserveFactorMantissa);
    }

    /**
     * @notice Returns the current total borrows plus accrued interest
     * @return The total borrows with interest
     */
    function totalBorrowsCurrent() override external nonReentrant returns (uint) {
        accrueInterest();
        return totalBorrows;
    }

    /**
     * @notice Accrue interest to updated borrowIndex and then calculate account's borrow balance using the updated borrowIndex
     * @param account The address whose balance should be calculated after updating borrowIndex
     * @return The calculated balance
     */
    function borrowBalanceCurrent(address account) override external nonReentrant returns (uint) {
        accrueInterest();
        return borrowBalanceStored(account);
    }

    /**
     * @notice Return the borrow balance of account based on stored data
     * @param account The address whose balance should be calculated
     * @return The calculated balance
     */
    function borrowBalanceStored(address account) override public view returns (uint) {
        return borrowBalanceStoredInternal(account);
    }

    /**
     * @notice Return the borrow balance of account based on stored data
     * @param account The address whose balance should be calculated
     * @return (error code, the calculated balance or 0 if error code is non-zero)
     */
    function borrowBalanceStoredInternal(address account) internal view returns (uint) {
        /* Get borrowBalance and borrowIndex */
        BorrowSnapshot storage borrowSnapshot = accountBorrows[account];

        /* If borrowBalance = 0 then borrowIndex is likely also 0.
         * Rather than failing the calculation with a division by 0, we immediately return 0 in this case.
         */
        if (borrowSnapshot.principal == 0) {
            return 0;
        }

        /* Calculate new borrow balance using the interest index:
         *  recentBorrowBalance = borrower.borrowBalance * market.borrowIndex / borrower.borrowIndex
         */
        uint principalTimesIndex = borrowSnapshot.principal * borrowIndex;
        return principalTimesIndex / borrowSnapshot.interestIndex;
    }

    /**
     * @notice Accrue interest then return the up-to-date exchange rate
     * @return Calculated exchange rate scaled by 1e18
     */
    function exchangeRateCurrent() override public nonReentrant returns (uint) {
        accrueInterest();
        return exchangeRateStored();
    }

    /**
     * @notice Calculates the exchange rate from the underlying to the CToken
     * @dev This function does not accrue interest before calculating the exchange rate
     * @return Calculated exchange rate scaled by 1e18
     */
    function exchangeRateStored() override public view returns (uint) {
        return exchangeRateStoredInternal();
    }

    /**
     * @notice Calculates the exchange rate from the underlying to the CToken
     * @dev This function does not accrue interest before calculating the exchange rate
     * @return calculated exchange rate scaled by 1e18
     */
    function exchangeRateStoredInternal() virtual internal view returns (uint) {
        uint _totalSupply = totalSupply;
        if (_totalSupply == 0) {
            /*
             * If there are no tokens minted:
             *  exchangeRate = initialExchangeRate
             */
            return initialExchangeRateMantissa;
        } else {
            /*
             * Otherwise:
             *  exchangeRate = (totalCash + totalBorrows - totalReserves) / totalSupply
             */
            uint totalCash = getCashPrior();
            uint cashPlusBorrowsMinusReserves = totalCash + totalBorrows - totalReserves;
            uint exchangeRate = cashPlusBorrowsMinusReserves * FixedMath.expScale / _totalSupply;

            return exchangeRate;
        }
    }

    /**
     * @notice Get cash balance of this cToken in the underlying asset
     * @return The quantity of underlying asset owned by this contract
     */
    function getCash() override external view returns (uint) {
        return getCashPrior();
    }

    /**
     * @notice Applies accrued interest to total borrows and reserves
     * @dev This calculates interest accrued from the last checkpointed block
     *   up to the current block and writes new checkpoint to storage.
     */
    function accrueInterest() virtual override public returns (uint) {
        /* Remember the initial block number */
        uint currentBlockNumber = getBlockNumber();
        uint accrualBlockNumberPrior = accrualBlockNumber;

        /* Short-circuit accumulating 0 interest */
        if (accrualBlockNumberPrior == currentBlockNumber) {
            return NO_ERROR;
        }

        /* Read the previous values out of storage */
        uint cashPrior = getCashPrior();
        uint borrowsPrior = totalBorrows;
        uint reservesPrior = totalReserves;
        uint borrowIndexPrior = borrowIndex;

        /* Calculate the current borrow interest rate */
        uint borrowRateMantissa = interestRateModel.getBorrowRate(cashPrior, borrowsPrior, reservesPrior);
        if (borrowRateMantissa > borrowRateMaxMantissa) revert BorrowRateTooHigh();

        /* Calculate the number of blocks elapsed since the last accrual */
        uint blockDelta = currentBlockNumber - accrualBlockNumberPrior;
        accrualBlockNumber = currentBlockNumber;

        /*
         * Calculate the interest accumulated into borrows and reserves and the new index:
         *  simpleInterestFactor = borrowRate * blockDelta
         *  interestAccumulated = simpleInterestFactor * totalBorrows
         *  totalBorrows = interestAccumulated + totalBorrows
         *  totalReserves = interestAccumulated * reserveFactor + totalReserves
         *  borrowIndex = simpleInterestFactor * borrowIndex + borrowIndex
         */

        FixedMath.Exp simpleInterestFactor = FixedMath.mul_(FixedMath.Exp.wrap(borrowRateMantissa), blockDelta);
        uint interestAccumulated = FixedMath.mul_ScalarTruncate(simpleInterestFactor, borrowsPrior);
        totalBorrows = interestAccumulated + borrowsPrior;
        totalReserves = FixedMath.mul_ScalarTruncateAddUInt(FixedMath.Exp.wrap(reserveFactorMantissa), interestAccumulated, reservesPrior);
        borrowIndex = FixedMath.mul_ScalarTruncateAddUInt(simpleInterestFactor, borrowIndexPrior, borrowIndexPrior);

        /* We emit an AccrueInterest event */
        emit AccrueInterest(cashPrior, interestAccumulated, borrowIndex, totalBorrows);

        return NO_ERROR;
    }

    /**
     * @notice Sender supplies assets into the market and receives cTokens in exchange
     * @dev Accrues interest whether or not the operation succeeds, unless reverted
     * @param mintAmount The amount of the underlying asset to supply
     */
    function mintInternal(uint mintAmount) internal nonReentrant {
        accrueInterest();
        // mintFresh emits the actual Mint event if successful and logs on errors, so we don't need to
        mintFresh(msg.sender, mintAmount);
    }

    /**
     * @notice User supplies assets into the market and receives cTokens in exchange
     * @dev Assumes interest has already been accrued up to the current block
     * @param minter The address of the account which is supplying the assets
     * @param mintAmount The amount of the underlying asset to supply
     */
    function mintFresh(address minter, uint mintAmount) internal {
        /* Fail if mint not allowed */
        uint allowed = comptroller.mintAllowed(address(this), minter, mintAmount);
        if (allowed != 0) {
            revert MintComptrollerRejection(allowed);
        }

        /* Verify market's block number equals current block number */
        if (accrualBlockNumber != getBlockNumber()) {
            revert MintFreshnessCheck();
        }

        FixedMath.Exp exchangeRate = FixedMath.Exp.wrap(exchangeRateStoredInternal());

        /////////////////////////
        // EFFECTS & INTERACTIONS
        // (No safe failures beyond this point)

        /*
         *  We call `doTransferIn` for the minter and the mintAmount.
         *  Note: The cToken must handle variations between ERC-20 and ETH underlying.
         *  `doTransferIn` reverts if anything goes wrong, since we can't be sure if
         *  side-effects occurred. The function returns the amount actually transferred,
         *  in case of a fee. On success, the cToken holds an additional `actualMintAmount`
         *  of cash.
         */
        uint actualMintAmount = doTransferIn(minter, mintAmount);

        /*
         * We get the current exchange rate and calculate the number of cTokens to be minted:
         *  mintTokens = actualMintAmount / exchangeRate
         */

        uint mintTokens = FixedMath.div_(actualMintAmount, exchangeRate);

        /*
         * We calculate the new total supply of cTokens and minter token balance, checking for overflow:
         *  totalSupplyNew = totalSupply + mintTokens
         *  accountTokensNew = accountTokens[minter] + mintTokens
         * And write them into storage
         */
        totalSupply = totalSupply + mintTokens;
        accountTokens[minter] = accountTokens[minter] + mintTokens;

        /* We emit a Mint event, and a Transfer event */
        emit Mint(minter, actualMintAmount, mintTokens);
        emit Transfer(address(this), minter, mintTokens);

        /* We call the defense hook */
        // unused function
        // comptroller.mintVerify(address(this), minter, actualMintAmount, mintTokens);
    }

    /**
     * @notice Sender redeems cTokens in exchange for the underlying asset
     * @dev Accrues interest whether or not the operation succeeds, unless reverted
     * @param redeemTokens The number of cTokens to redeem into underlying
     */
    function redeemInternal(uint redeemTokens) internal nonReentrant {
        accrueInterest();
        // redeemFresh emits redeem-specific logs on errors, so we don't need to
        redeemFresh(payable(msg.sender), redeemTokens, 0);
    }

    /**
     * @notice Sender redeems cTokens in exchange for a specified amount of underlying asset
     * @dev Accrues interest whether or not the operation succeeds, unless reverted
     * @param redeemAmount The amount of underlying to receive from redeeming cTokens
     */
    function redeemUnderlyingInternal(uint redeemAmount) internal nonReentrant {
        accrueInterest();
        // redeemFresh emits redeem-specific logs on errors, so we don't need to
        redeemFresh(payable(msg.sender), 0, redeemAmount);
    }

    /**
     * @notice User redeems cTokens in exchange for the underlying asset
     * @dev Assumes interest has already been accrued up to the current block
     * @param redeemer The address of the account which is redeeming the tokens
     * @param redeemTokensIn The number of cTokens to redeem into underlying (only one of redeemTokensIn or redeemAmountIn may be non-zero)
     * @param redeemAmountIn The number of underlying tokens to receive from redeeming cTokens (only one of redeemTokensIn or redeemAmountIn may be non-zero)
     */
    function redeemFresh(address payable redeemer, uint redeemTokensIn, uint redeemAmountIn) internal {
        if (redeemTokensIn != 0 && redeemAmountIn != 0) revert RedeemTokensInOrRedeemAmountInShouldBeZero();

        /* exchangeRate = invoke Exchange Rate Stored() */
        FixedMath.Exp exchangeRate = FixedMath.Exp.wrap(exchangeRateStoredInternal());

        uint redeemTokens;
        uint redeemAmount;
        /* If redeemTokensIn > 0: */
        if (redeemTokensIn > 0) {
            /*
             * We calculate the exchange rate and the amount of underlying to be redeemed:
             *  redeemTokens = redeemTokensIn
             *  redeemAmount = redeemTokensIn x exchangeRateCurrent
             */
            redeemTokens = redeemTokensIn;
            redeemAmount = FixedMath.mul_ScalarTruncate(exchangeRate, redeemTokensIn);
        } else {
            /*
             * We get the current exchange rate and calculate the amount to be redeemed:
             *  redeemTokens = redeemAmountIn / exchangeRate
             *  redeemAmount = redeemAmountIn
             */
            redeemTokens = FixedMath.div_(redeemAmountIn, exchangeRate);
            redeemAmount = redeemAmountIn;
        }

        /* Fail if redeem not allowed */
        uint allowed = comptroller.redeemAllowed(address(this), redeemer, redeemTokens);
        if (allowed != 0) {
            revert RedeemComptrollerRejection(allowed);
        }

        /* Verify market's block number equals current block number */
        if (accrualBlockNumber != getBlockNumber()) {
            revert RedeemFreshnessCheck();
        }

        /* Fail gracefully if protocol has insufficient cash */
        if (getCashPrior() < redeemAmount) {
            revert RedeemTransferOutNotPossible();
        }

        /////////////////////////
        // EFFECTS & INTERACTIONS
        // (No safe failures beyond this point)


        /*
         * We write the previously calculated values into storage.
         *  Note: Avoid token reentrancy attacks by writing reduced supply before external transfer.
         */
        totalSupply = totalSupply - redeemTokens;
        accountTokens[redeemer] = accountTokens[redeemer] - redeemTokens;

        /*
         * We invoke doTransferOut for the redeemer and the redeemAmount.
         *  Note: The cToken must handle variations between ERC-20 and ETH underlying.
         *  On success, the cToken has redeemAmount less of cash.
         *  doTransferOut reverts if anything goes wrong, since we can't be sure if side effects occurred.
         */
        doTransferOut(redeemer, redeemAmount);

        /* We emit a Transfer event, and a Redeem event */
        emit Transfer(redeemer, address(this), redeemTokens);
        emit Redeem(redeemer, redeemAmount, redeemTokens);

        /* We call the defense hook */
        comptroller.redeemVerify(address(this), redeemer, redeemAmount, redeemTokens);
    }

    /**
      * @notice Sender borrows assets from the protocol to their own address
      * @param borrowAmount The amount of the underlying asset to borrow
      */
    function borrowInternal(uint borrowAmount) internal nonReentrant {
        accrueInterest();
        // borrowFresh emits borrow-specific logs on errors, so we don't need to
        borrowFresh(payable(msg.sender), borrowAmount);
    }

    /**
      * @notice Users borrow assets from the protocol to their own address
      * @param borrowAmount The amount of the underlying asset to borrow
      */
    function borrowFresh(address payable borrower, uint borrowAmount) internal {
        /* Fail if borrow not allowed */
        uint allowed = comptroller.borrowAllowed(address(this), borrower, borrowAmount);
        if (allowed != 0) {
            revert BorrowComptrollerRejection(allowed);
        }

        /* Verify market's block number equals current block number */
        if (accrualBlockNumber != getBlockNumber()) {
            revert BorrowFreshnessCheck();
        }

        /* Fail gracefully if protocol has insufficient underlying cash */
        if (getCashPrior() < borrowAmount) {
            revert BorrowCashNotAvailable();
        }

        /*
         * We calculate the new borrower and total borrow balances, failing on overflow:
         *  accountBorrowNew = accountBorrow + borrowAmount
         *  totalBorrowsNew = totalBorrows + borrowAmount
         */
        uint accountBorrowsPrev = borrowBalanceStoredInternal(borrower);
        uint accountBorrowsNew = accountBorrowsPrev + borrowAmount;
        uint totalBorrowsNew = totalBorrows + borrowAmount;

        /////////////////////////
        // EFFECTS & INTERACTIONS
        // (No safe failures beyond this point)

        /*
         * We write the previously calculated values into storage.
         *  Note: Avoid token reentrancy attacks by writing increased borrow before external transfer.
        `*/
        accountBorrows[borrower].principal = accountBorrowsNew;
        accountBorrows[borrower].interestIndex = borrowIndex;
        totalBorrows = totalBorrowsNew;

        /*
         * We invoke doTransferOut for the borrower and the borrowAmount.
         *  Note: The cToken must handle variations between ERC-20 and ETH underlying.
         *  On success, the cToken borrowAmount less of cash.
         *  doTransferOut reverts if anything goes wrong, since we can't be sure if side effects occurred.
         */
        doTransferOut(borrower, borrowAmount);

        /* We emit a Borrow event */
        emit Borrow(borrower, borrowAmount, accountBorrowsNew, totalBorrowsNew);
    }

    /**
     * @notice Sender repays their own borrow
     * @param repayAmount The amount to repay, or -1 for the full outstanding amount
     */
    function repayBorrowInternal(uint repayAmount) internal nonReentrant {
        accrueInterest();
        // repayBorrowFresh emits repay-borrow-specific logs on errors, so we don't need to
        repayBorrowFresh(msg.sender, msg.sender, repayAmount);
    }

    /**
     * @notice Sender repays a borrow belonging to borrower
     * @param borrower the account with the debt being payed off
     * @param repayAmount The amount to repay, or -1 for the full outstanding amount
     */
    function repayBorrowBehalfInternal(address borrower, uint repayAmount) internal nonReentrant {
        accrueInterest();
        // repayBorrowFresh emits repay-borrow-specific logs on errors, so we don't need to
        repayBorrowFresh(msg.sender, borrower, repayAmount);
    }

    /**
     * @notice Borrows are repaid by another user (possibly the borrower).
     * @param payer the account paying off the borrow
     * @param borrower the account with the debt being payed off
     * @param repayAmount the amount of underlying tokens being returned, or -1 for the full outstanding amount
     * @return (uint) the actual repayment amount.
     */
    function repayBorrowFresh(address payer, address borrower, uint repayAmount) internal returns (uint) {
        /* Fail if repayBorrow not allowed */
        uint allowed = comptroller.repayBorrowAllowed(address(this), payer, borrower, repayAmount);
        if (allowed != 0) {
            revert RepayBorrowComptrollerRejection(allowed);
        }

        /* Verify market's block number equals current block number */
        if (accrualBlockNumber != getBlockNumber()) {
            revert RepayBorrowFreshnessCheck();
        }

        /* We fetch the amount the borrower owes, with accumulated interest */
        uint accountBorrowsPrev = borrowBalanceStoredInternal(borrower);

        /* If repayAmount == -1, repayAmount = accountBorrows */
        uint repayAmountFinal = repayAmount == type(uint).max ? accountBorrowsPrev : repayAmount;

        /////////////////////////
        // EFFECTS & INTERACTIONS
        // (No safe failures beyond this point)

        /*
         * We call doTransferIn for the payer and the repayAmount
         *  Note: The cToken must handle variations between ERC-20 and ETH underlying.
         *  On success, the cToken holds an additional repayAmount of cash.
         *  doTransferIn reverts if anything goes wrong, since we can't be sure if side effects occurred.
         *   it returns the amount actually transferred, in case of a fee.
         */
        uint actualRepayAmount = doTransferIn(payer, repayAmountFinal);

        /*
         * We calculate the new borrower and total borrow balances, failing on underflow:
         *  accountBorrowsNew = accountBorrows - actualRepayAmount
         *  totalBorrowsNew = totalBorrows - actualRepayAmount
         */
        uint accountBorrowsNew = accountBorrowsPrev - actualRepayAmount;
        uint totalBorrowsNew = totalBorrows - actualRepayAmount;

        /* We write the previously calculated values into storage */
        accountBorrows[borrower].principal = accountBorrowsNew;
        accountBorrows[borrower].interestIndex = borrowIndex;
        totalBorrows = totalBorrowsNew;

        /* We emit a RepayBorrow event */
        emit RepayBorrow(payer, borrower, actualRepayAmount, accountBorrowsNew, totalBorrowsNew);

        return actualRepayAmount;
    }

    function repayWithDeposit(address borrower, uint repayAmount) external {
        accrueInterest();
        address repayer = msg.sender;
        /* Fail if repayBorrow not allowed */
        uint allowed = comptroller.repayBorrowAllowed(address(this), repayer, borrower, repayAmount);
        if (allowed != 0) {
            revert RepayBorrowComptrollerRejection(allowed);
        }

        /* Verify market's block number equals current block number */
        if (accrualBlockNumber != getBlockNumber()) {
            revert RepayBorrowFreshnessCheck();
        }

        /* We fetch the amount the borrower owes, with accumulated interest */
        uint accountBorrowsPrev = borrowBalanceStoredInternal(borrower);

        /* If repayAmount == -1, repayAmount = accountBorrows */
        uint repayAmountFinal = repayAmount == type(uint).max ? accountBorrowsPrev : repayAmount;

        /* exchangeRate = invoke Exchange Rate Stored() */
        FixedMath.Exp exchangeRate = FixedMath.Exp.wrap(exchangeRateStoredInternal());

        uint redeemTokens = FixedMath.div_(repayAmountFinal, exchangeRate);

        if (repayer != borrower) {
            allowed = comptroller.redeemAllowed(address(this), repayer, redeemTokens);
            if (allowed != 0) {
                revert RedeemComptrollerRejection(allowed);
            }
        }
       
        totalSupply = totalSupply - redeemTokens;
        accountTokens[repayer] = accountTokens[repayer] - redeemTokens;

        /*
         * We calculate the new borrower and total borrow balances, failing on underflow:
         *  accountBorrowsNew = accountBorrows - actualRepayAmount
         *  totalBorrowsNew = totalBorrows - actualRepayAmount
         */
        uint accountBorrowsNew = accountBorrowsPrev - repayAmountFinal;
        uint totalBorrowsNew = totalBorrows - repayAmountFinal;

        /* We write the previously calculated values into storage */
        accountBorrows[borrower].principal = accountBorrowsNew;
        accountBorrows[borrower].interestIndex = borrowIndex;
        totalBorrows = totalBorrowsNew;

        /* We emit a Transfer event, and a Redeem event */
        emit Transfer(repayer, address(this), redeemTokens);        
        /* We emit a RepayBorrow event */
        emit RepayBorrow(repayer, borrower, repayAmountFinal, accountBorrowsNew, totalBorrowsNew);

    }

    /**
     * @notice The sender liquidates the borrowers collateral.
     *  The collateral seized is transferred to the liquidator.
     * @param borrower The borrower of this cToken to be liquidated
     * @param cTokenCollateral The market in which to seize collateral from the borrower
     * @param repayAmount The amount of the underlying borrowed asset to repay
     */
    function liquidateBorrowInternal(address borrower, uint repayAmount, CTokenInterface cTokenCollateral) internal nonReentrant {
        accrueInterest();

        uint error = cTokenCollateral.accrueInterest();
        if (error != NO_ERROR) {
            // accrueInterest emits logs on errors, but we still want to log the fact that an attempted liquidation failed
            revert LiquidateAccrueCollateralInterestFailed(error);
        }

        // liquidateBorrowFresh emits borrow-specific logs on errors, so we don't need to
        liquidateBorrowFresh(msg.sender, borrower, repayAmount, cTokenCollateral);
    }

    /**
     * @notice The liquidator liquidates the borrowers collateral.
     *  The collateral seized is transferred to the liquidator.
     * @param borrower The borrower of this cToken to be liquidated
     * @param liquidator The address repaying the borrow and seizing collateral
     * @param cTokenCollateral The market in which to seize collateral from the borrower
     * @param repayAmount The amount of the underlying borrowed asset to repay
     */
    function liquidateBorrowFresh(address liquidator, address borrower, uint repayAmount, CTokenInterface cTokenCollateral) internal {
        /* Fail if liquidate not allowed */
        uint allowed = comptroller.liquidateBorrowAllowed(address(this), address(cTokenCollateral), liquidator, borrower, repayAmount);
        if (allowed != 0) {
            revert LiquidateComptrollerRejection(allowed);
        }

        /* Verify market's block number equals current block number */
        if (accrualBlockNumber != getBlockNumber()) {
            revert LiquidateFreshnessCheck();
        }

        /* Verify cTokenCollateral market's block number equals current block number */
        if (cTokenCollateral.accrualBlockNumber() != getBlockNumber()) {
            revert LiquidateCollateralFreshnessCheck();
        }

        /* Fail if borrower = liquidator */
        if (borrower == liquidator) {
            revert LiquidateLiquidatorIsBorrower();
        }

        /* Fail if repayAmount = 0 */
        if (repayAmount == 0) {
            revert LiquidateCloseAmountIsZero();
        }

        /* Fail if repayAmount = -1 */
        if (repayAmount == type(uint).max) {
            revert LiquidateCloseAmountIsUintMax();
        }

        /* Fail if repayBorrow fails */
        uint actualRepayAmount = repayBorrowFresh(liquidator, borrower, repayAmount);

        /////////////////////////
        // EFFECTS & INTERACTIONS
        // (No safe failures beyond this point)

        /* We calculate the number of collateral tokens that will be seized */
        (, uint seizeTokens) = comptroller.liquidateCalculateSeizeTokens(address(this), address(cTokenCollateral), actualRepayAmount);

        if (comptroller.isValidSmartAccount(borrower)) {
            ISmartAccount smartBorrower = ISmartAccount(borrower);
            uint accountCollateralValue = smartBorrower.getNonStandardCollateralAssetValue();
            if (accountCollateralValue < seizeTokens) revert LiquidateSizeTooMuch();
            smartBorrower.liquidate(borrower, liquidator);
            return;
        }
        /* Revert if borrower collateral token balance < seizeTokens */
        if (cTokenCollateral.balanceOf(borrower) < seizeTokens) revert LiquidateSizeTooMuch();

        // If this is also the collateral, run seizeInternal to avoid re-entrancy, otherwise make an external call
        if (address(cTokenCollateral) == address(this)) {
            seizeInternal(address(this), liquidator, borrower, seizeTokens);
        } else {
            cTokenCollateral.seize(liquidator, borrower, seizeTokens);
        }

        /* We emit a LiquidateBorrow event */
        emit LiquidateBorrow(liquidator, borrower, actualRepayAmount, address(cTokenCollateral), seizeTokens);
    }

    /**
     * @notice Transfers collateral tokens (this market) to the liquidator.
     * @dev Will fail unless called by another cToken during the process of liquidation.
     *  Its absolutely critical to use msg.sender as the borrowed cToken and not a parameter.
     * @param liquidator The account receiving seized collateral
     * @param borrower The account having collateral seized
     * @param seizeTokens The number of cTokens to seize
     * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
     */
    function seize(address liquidator, address borrower, uint seizeTokens) override external nonReentrant returns (uint) {
        seizeInternal(msg.sender, liquidator, borrower, seizeTokens);

        return NO_ERROR;
    }

    /**
     * @notice Transfers collateral tokens (this market) to the liquidator.
     * @dev Called only during an in-kind liquidation, or by liquidateBorrow during the liquidation of another CToken.
     *  Its absolutely critical to use msg.sender as the seizer cToken and not a parameter.
     * @param seizerToken The contract seizing the collateral (i.e. borrowed cToken)
     * @param liquidator The account receiving seized collateral
     * @param borrower The account having collateral seized
     * @param seizeTokens The number of cTokens to seize
     */
    function seizeInternal(address seizerToken, address liquidator, address borrower, uint seizeTokens) internal {
        /* Fail if seize not allowed */
        uint allowed = comptroller.seizeAllowed(address(this), seizerToken, liquidator, borrower, seizeTokens);
        if (allowed != 0) {
            revert LiquidateSeizeComptrollerRejection(allowed);
        }

        /* Fail if borrower = liquidator */
        if (borrower == liquidator) {
            revert LiquidateSeizeLiquidatorIsBorrower();
        }

        /*
         * We calculate the new borrower and liquidator token balances, failing on underflow/overflow:
         *  borrowerTokensNew = accountTokens[borrower] - seizeTokens
         *  liquidatorTokensNew = accountTokens[liquidator] + seizeTokens
         */
        uint protocolSeizeTokens = FixedMath.mul_(seizeTokens, FixedMath.Exp.wrap(protocolSeizeShareMantissa));
        uint liquidatorSeizeTokens = seizeTokens - protocolSeizeTokens;
        FixedMath.Exp exchangeRate = FixedMath.Exp.wrap(exchangeRateStoredInternal());
        uint protocolSeizeAmount = FixedMath.mul_ScalarTruncate(exchangeRate, protocolSeizeTokens);
        uint totalReservesNew = totalReserves + protocolSeizeAmount;


        /////////////////////////
        // EFFECTS & INTERACTIONS
        // (No safe failures beyond this point)

        /* We write the calculated values into storage */
        totalReserves = totalReservesNew;
        totalSupply = totalSupply - protocolSeizeTokens;
        accountTokens[borrower] = accountTokens[borrower] - seizeTokens;
        accountTokens[liquidator] = accountTokens[liquidator] + liquidatorSeizeTokens;

        /* Emit a Transfer event */
        emit Transfer(borrower, liquidator, liquidatorSeizeTokens);
        emit Transfer(borrower, address(this), protocolSeizeTokens);
        emit ReservesAdded(address(this), protocolSeizeAmount, totalReservesNew);
    }


    /*** Admin Functions ***/

    /**
      * @notice Begins transfer of admin rights. The newPendingAdmin must call `_acceptAdmin` to finalize the transfer.
      * @dev Admin function to begin change of admin. The newPendingAdmin must call `_acceptAdmin` to finalize the transfer.
      * @param newPendingAdmin New pending admin.
      * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
      */
    function _setPendingAdmin(address payable newPendingAdmin) override external returns (uint) {
        // Check caller = admin
        if (msg.sender != admin) {
            revert SetPendingAdminOwnerCheck();
        }

        emit NewPendingAdmin(pendingAdmin, newPendingAdmin);

        // Store pendingAdmin with value newPendingAdmin
        pendingAdmin = newPendingAdmin;

        return NO_ERROR;
    }

    /**
      * @notice Accepts transfer of admin rights. msg.sender must be pendingAdmin
      * @dev Admin function for pending admin to accept role and update admin
      * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
      */
    function _acceptAdmin() override external returns (uint) {
        // Check caller is pendingAdmin and pendingAdmin ≠ address(0)
        if (msg.sender != pendingAdmin || pendingAdmin == address(0)) {
            revert AcceptAdminPendingAdminCheck();
        }

        emit NewAdmin(admin, pendingAdmin);
        emit NewPendingAdmin(pendingAdmin, payable(address(0)));
     
        // Store admin with value pendingAdmin
        admin = pendingAdmin;

        // Clear the pending value
        pendingAdmin = payable(address(0));

        return NO_ERROR;
    }

    /**
      * @notice Sets a new comptroller for the market
      * @dev Admin function to set a new comptroller
      * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
      */
    function _setComptroller(ComptrollerInterface newComptroller) override public returns (uint) {
        // Check caller is admin
        if (msg.sender != admin) {
            revert SetComptrollerOwnerCheck();
        }

        // Ensure invoke comptroller.isComptroller() returns true
        if(!newComptroller.isComptroller()) revert NotComptroller();

        emit NewComptroller(comptroller, newComptroller);

        // Set market's comptroller to newComptroller
        comptroller = newComptroller;

        return NO_ERROR;
    }

    /**
      * @notice accrues interest and sets a new reserve factor for the protocol using _setReserveFactorFresh
      * @dev Admin function to accrue interest and set a new reserve factor
      * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
      */
    function _setReserveFactor(uint newReserveFactorMantissa) override external nonReentrant returns (uint) {
        accrueInterest();
        // _setReserveFactorFresh emits reserve-factor-specific logs on errors, so we don't need to.
        return _setReserveFactorFresh(newReserveFactorMantissa);
    }

    /**
      * @notice Sets a new reserve factor for the protocol (*requires fresh interest accrual)
      * @dev Admin function to set a new reserve factor
      * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
      */
    function _setReserveFactorFresh(uint newReserveFactorMantissa) internal returns (uint) {
        // Check caller is admin
        if (msg.sender != admin) {
            revert SetReserveFactorAdminCheck();
        }

        // Check newReserveFactor ≤ maxReserveFactor
        if (newReserveFactorMantissa > reserveFactorMaxMantissa) {
            revert SetReserveFactorBoundsCheck();
        }

        emit NewReserveFactor(reserveFactorMantissa, newReserveFactorMantissa);

        reserveFactorMantissa = newReserveFactorMantissa;

        return NO_ERROR;
    }

    /**
     * @notice Accrues interest and reduces reserves by transferring to admin
     * @param reduceAmount Amount of reduction to reserves
     * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
     */
    function _reduceReserves(uint reduceAmount) override external nonReentrant returns (uint) {
        accrueInterest();
        // _reduceReservesFresh emits reserve-reduction-specific logs on errors, so we don't need to.
        return _reduceReservesFresh(reduceAmount);
    }

    /**
     * @notice Reduces reserves by transferring to admin
     * @dev Requires fresh interest accrual
     * @param reduceAmount Amount of reduction to reserves
     * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
     */
    function _reduceReservesFresh(uint reduceAmount) internal returns (uint) {
        // Fail gracefully if protocol has insufficient underlying cash
        if (getCashPrior() < reduceAmount) {
            revert ReduceReservesCashNotAvailable();
        }

        // Check reduceAmount ≤ reserves[n] (totalReserves)
        if (reduceAmount > totalReserves) {
            revert ReduceReservesCashValidation();
        }

        /////////////////////////
        // EFFECTS & INTERACTIONS
        // (No safe failures beyond this point)

        totalReserves = totalReserves - reduceAmount;

        // doTransferOut reverts if anything goes wrong, since we can't be sure if side effects occurred.
        doTransferOut(admin, reduceAmount);

        emit ReservesReduced(admin, reduceAmount, totalReserves);

        return NO_ERROR;
    }

    /**
     * @notice accrues interest and updates the interest rate model using _setInterestRateModelFresh
     * @dev Admin function to accrue interest and update the interest rate model
     * @param newInterestRateModel the new interest rate model to use
     * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
     */
    function _setInterestRateModel(InterestRateModel newInterestRateModel) override public returns (uint) {
        accrueInterest();
        // _setInterestRateModelFresh emits interest-rate-model-update-specific logs on errors, so we don't need to.
        return _setInterestRateModelFresh(newInterestRateModel);
    }

    /**
     * @notice updates the interest rate model (*requires fresh interest accrual)
     * @dev Admin function to update the interest rate model
     * @param newInterestRateModel the new interest rate model to use
     * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
     */
    function _setInterestRateModelFresh(InterestRateModel newInterestRateModel) internal returns (uint) {
        // Check caller is admin
        if (msg.sender != admin) {
            revert SetInterestRateModelOwnerCheck();
        }

        // Ensure invoke newInterestRateModel.isInterestRateModel() returns true
        if (!newInterestRateModel.isInterestRateModel()) revert InvalidContractAddress();

        // Emit NewMarketInterestRateModel(oldInterestRateModel, newInterestRateModel)
        emit NewMarketInterestRateModel(interestRateModel, newInterestRateModel);

        // Set the interest rate model to newInterestRateModel
        interestRateModel = newInterestRateModel;
   
        return NO_ERROR;
    }

    /*** Safe Token ***/

    /**
     * @notice Gets balance of this contract in terms of the underlying
     * @dev This excludes the value of the current message, if any
     * @return The quantity of underlying owned by this contract
     */
    function getCashPrior() virtual internal view returns (uint);

    /**
     * @dev Performs a transfer in, reverting upon failure. Returns the amount actually transferred to the protocol, in case of a fee.
     *  This may revert due to insufficient balance or insufficient allowance.
     */
    function doTransferIn(address from, uint amount) virtual internal returns (uint);

    /**
     * @dev Performs a transfer out, ideally returning an explanatory error code upon failure rather than reverting.
     *  If caller has not called checked protocol's balance, may revert due to insufficient cash held in the contract.
     *  If caller has checked protocol's balance, and verified it is >= amount, this should not revert in normal conditions.
     */
    function doTransferOut(address payable to, uint amount) virtual internal;

    function isNativeToken() external pure virtual returns (bool) {
        return false;
    }
    /*** Reentrancy Guard ***/

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     */
    modifier nonReentrant() {
        require(_notEntered, "re-entered");
        _notEntered = false;
        _;
        _notEntered = true; // get a gas-refund post-Istanbul
    }
}


// File contracts/CErc20.sol


pragma solidity ^0.8.10;

interface CompLike {
    function delegate(address delegatee) external;
}

/**
 * @title Compound's CErc20 Contract
 * @notice CTokens which wrap an EIP-20 underlying
 * @author Compound
 */
contract CErc20 is CToken, CErc20Interface {
    /**
     * @notice Initialize the new money market
     * @param underlying_ The address of the underlying asset
     * @param comptroller_ The address of the Comptroller
     * @param interestRateModel_ The address of the interest rate model
     * @param initialExchangeRateMantissa_ The initial exchange rate, scaled by 1e18
     * @param name_ ERC-20 name of this token
     * @param symbol_ ERC-20 symbol of this token
     * @param decimals_ ERC-20 decimal precision of this token
     */
    function initialize(address underlying_,
                        ComptrollerInterface comptroller_,
                        InterestRateModel interestRateModel_,
                        uint initialExchangeRateMantissa_,
                        string memory name_,
                        string memory symbol_,
                        uint8 decimals_) public {
        // CToken initialize does the bulk of the work
        super.initialize(comptroller_, interestRateModel_, initialExchangeRateMantissa_, name_, symbol_, decimals_);

        // Set underlying and sanity check it
        underlying = underlying_;
        EIP20Interface(underlying).totalSupply();
    }

    /*** User Interface ***/

    /**
     * @notice Sender supplies assets into the market and receives cTokens in exchange
     * @dev Accrues interest whether or not the operation succeeds, unless reverted
     * @param mintAmount The amount of the underlying asset to supply
     * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
     */
    function mint(uint mintAmount) override external returns (uint) {
        mintInternal(mintAmount);
        return NO_ERROR;
    }

    /**
     * @notice Sender redeems cTokens in exchange for the underlying asset
     * @dev Accrues interest whether or not the operation succeeds, unless reverted
     * @param redeemTokens The number of cTokens to redeem into underlying
     * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
     */
    function redeem(uint redeemTokens) override external returns (uint) {
        redeemInternal(redeemTokens);
        return NO_ERROR;
    }

    /**
     * @notice Sender redeems cTokens in exchange for a specified amount of underlying asset
     * @dev Accrues interest whether or not the operation succeeds, unless reverted
     * @param redeemAmount The amount of underlying to redeem
     * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
     */
    function redeemUnderlying(uint redeemAmount) override external returns (uint) {
        redeemUnderlyingInternal(redeemAmount);
        return NO_ERROR;
    }

    /**
      * @notice Sender borrows assets from the protocol to their own address
      * @param borrowAmount The amount of the underlying asset to borrow
      * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
      */
    function borrow(uint borrowAmount) override external returns (uint) {
        borrowInternal(borrowAmount);
        return NO_ERROR;
    }

    /**
     * @notice Sender repays their own borrow
     * @param repayAmount The amount to repay, or -1 for the full outstanding amount
     * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
     */
    function repayBorrow(uint repayAmount) override external returns (uint) {
        repayBorrowInternal(repayAmount);
        return NO_ERROR;
    }

    /**
     * @notice Sender repays a borrow belonging to borrower
     * @param borrower the account with the debt being payed off
     * @param repayAmount The amount to repay, or -1 for the full outstanding amount
     * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
     */
    function repayBorrowBehalf(address borrower, uint repayAmount) override external returns (uint) {
        repayBorrowBehalfInternal(borrower, repayAmount);
        return NO_ERROR;
    }

    /**
     * @notice The sender liquidates the borrowers collateral.
     *  The collateral seized is transferred to the liquidator.
     * @param borrower The borrower of this cToken to be liquidated
     * @param repayAmount The amount of the underlying borrowed asset to repay
     * @param cTokenCollateral The market in which to seize collateral from the borrower
     * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
     */
    function liquidateBorrow(address borrower, uint repayAmount, CTokenInterface cTokenCollateral) override external returns (uint) {
        liquidateBorrowInternal(borrower, repayAmount, cTokenCollateral);
        return NO_ERROR;
    }

    /**
     * @notice A public function to sweep accidental ERC-20 transfers to this contract. Tokens are sent to admin (timelock)
     * @param token The address of the ERC-20 token to sweep
     */
    function sweepToken(EIP20NonStandardInterface token) override external {
        require(msg.sender == admin, "CErc20::sweepToken: only admin can sweep tokens");
        require(address(token) != underlying, "CErc20::sweepToken: can not sweep underlying token");
        uint256 balance = token.balanceOf(address(this));
        token.transfer(admin, balance);
    }

    /*** Safe Token ***/

    /**
     * @notice Gets balance of this contract in terms of the underlying
     * @dev This excludes the value of the current message, if any
     * @return The quantity of underlying tokens owned by this contract
     */
    function getCashPrior() virtual override internal view returns (uint) {
        EIP20Interface token = EIP20Interface(underlying);
        return token.balanceOf(address(this));
    }

    /**
     * @dev Similar to EIP20 transfer, except it handles a False result from `transferFrom` and reverts in that case.
     *      This will revert due to insufficient balance or insufficient allowance.
     *      This function returns the actual amount received,
     *      which may be less than `amount` if there is a fee attached to the transfer.
     *
     *      Note: This wrapper safely handles non-standard ERC-20 tokens that do not return a value.
     *            See here: https://medium.com/coinmonks/missing-return-value-bug-at-least-130-tokens-affected-d67bf08521ca
     */
    function doTransferIn(address from, uint amount) virtual override internal returns (uint) {
        // Read from storage once
        address underlying_ = underlying;
        EIP20NonStandardInterface token = EIP20NonStandardInterface(underlying_);
        uint balanceBefore = EIP20Interface(underlying_).balanceOf(address(this));
        token.transferFrom(from, address(this), amount);

        bool success;
        assembly {
            switch returndatasize()
                case 0 {                       // This is a non-standard ERC-20
                    success := not(0)          // set success to true
                }
                case 32 {                      // This is a compliant ERC-20
                    returndatacopy(0, 0, 32)
                    success := mload(0)        // Set `success = returndata` of override external call
                }
                default {                      // This is an excessively non-compliant ERC-20, revert.
                    revert(0, 0)
                }
        }
        require(success, "TOKEN_TRANSFER_IN_FAILED");

        // Calculate the amount that was *actually* transferred
        uint balanceAfter = EIP20Interface(underlying_).balanceOf(address(this));
        return balanceAfter - balanceBefore;   // underflow already checked above, just subtract
    }

    /**
     * @dev Similar to EIP20 transfer, except it handles a False success from `transfer` and returns an explanatory
     *      error code rather than reverting. If caller has not called checked protocol's balance, this may revert due to
     *      insufficient cash held in this contract. If caller has checked protocol's balance prior to this call, and verified
     *      it is >= amount, this should not revert in normal conditions.
     *
     *      Note: This wrapper safely handles non-standard ERC-20 tokens that do not return a value.
     *            See here: https://medium.com/coinmonks/missing-return-value-bug-at-least-130-tokens-affected-d67bf08521ca
     */
    function doTransferOut(address payable to, uint amount) virtual override internal {
        EIP20NonStandardInterface token = EIP20NonStandardInterface(underlying);
        token.transfer(to, amount);

        bool success;
        assembly {
            switch returndatasize()
                case 0 {                      // This is a non-standard ERC-20
                    success := not(0)          // set success to true
                }
                case 32 {                     // This is a compliant ERC-20
                    returndatacopy(0, 0, 32)
                    success := mload(0)        // Set `success = returndata` of override external call
                }
                default {                     // This is an excessively non-compliant ERC-20, revert.
                    revert(0, 0)
                }
        }
        require(success, "TOKEN_TRANSFER_OUT_FAILED");
    }

    /**
    * @notice Admin call to delegate the votes of the COMP-like underlying
    * @param compLikeDelegatee The address to delegate votes to
    * @dev CTokens whose underlying are not CompLike should revert here
    */
    function _delegateCompLikeTo(address compLikeDelegatee) external {
        require(msg.sender == admin, "only the admin may set the comp-like delegate");
        CompLike(underlying).delegate(compLikeDelegatee);
    }
}


// File contracts/Interfaces/ChainlinkAggregatorV3Interface.sol


pragma solidity ^0.8.10;

interface ChainlinkAggregatorV3Interface {
    function decimals() external view returns (uint8);
    function description() external view returns (string memory);
    function version() external view returns (uint256);

    function getRoundData(uint80 _roundId) external view returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    );

    function latestRoundData() external view returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    );

}


// File contracts/Interfaces/PriceOracle.sol


pragma solidity ^0.8.10;

abstract contract PriceOracle {
    /// @notice Indicator that this is a PriceOracle contract (for inspection)
    bool public constant isPriceOracle = true;

    /**
      * @notice Get the underlying price of a cToken asset
      * @param cToken The cToken to get the underlying price of
      * @return The underlying asset price mantissa (scaled by 1e18).
      *  Zero means the price is unavailable.
      */
    function getUnderlyingPrice(CToken cToken) virtual external view returns (uint);
}


// File contracts/ChainlinkAdaptor.sol


pragma solidity ^0.8.10;





contract ChainlinkAdaptor is PriceOracle {
    using FixedMath for uint256;

    address public governance;

    mapping(address => ChainlinkAggregatorV3Interface) public assetsPriceSources;
    ChainlinkAggregatorV3Interface public nativeTokenPriceSource;

    PriceOracle public fallbackPriceOracle;

    event AssetPriceSourceUpdated(address indexed asset, address indexed source);
    event GovernanceTransferred(address indexed previousGovernance, address indexed newGovernance);

    modifier onlyGovernance {
        require(msg.sender == governance, "Governance required.");
        _;
    }

    constructor(address _nativeTokenPriceSource) {
        governance = msg.sender;
        nativeTokenPriceSource = ChainlinkAggregatorV3Interface(_nativeTokenPriceSource);
    }

    function getUnderlyingPrice(CToken cToken) external view override returns (uint) {
        if (cToken.isNativeToken()) {
            return 1e18;
        }

        address asset = address(CErc20(address(cToken)).underlying());
        ChainlinkAggregatorV3Interface priceSource = assetsPriceSources[asset];

        if (address(priceSource) == address(0x0)) {
            return getUnderlyingPriceFromFallback(cToken);
        }

        uint256 priceFromChainlink = getUnderlyingPriceFromChainlink(priceSource, cToken);
        if (priceFromChainlink == 0) {
            return getUnderlyingPriceFromFallback(cToken);
        }
        return priceFromChainlink;
    }

    function getUnderlyingPriceFromFallback(CToken cToken) public view returns (uint) {
        if (address(fallbackPriceOracle) != address(0x0)) {
            return fallbackPriceOracle.getUnderlyingPrice(cToken);
        }
        return 0;
    }

    function getUnderlyingPriceFromChainlink(ChainlinkAggregatorV3Interface chainlinkPriceSource, CToken cToken) view internal returns(uint256) {
        uint256 assetPriceDecimals = chainlinkPriceSource.decimals();
        address asset = address(CErc20(address(cToken)).underlying());

        uint256 assetDecimals = CErc20(address(asset)).decimals();
        uint256 assetPriceInUsd = getPrice(chainlinkPriceSource);

        uint256 nativeTokenPriceDecimals = nativeTokenPriceSource.decimals();
        uint256 nativeTokenPriceInUsd = getPrice(nativeTokenPriceSource);

        if (assetPriceInUsd == 0 || nativeTokenPriceInUsd == 0) {
            return 0;
        }
        if (assetPriceDecimals == nativeTokenPriceDecimals) {
            return assetPriceInUsd.mul_(10 ** 18).mul_(10 ** 18).div_(nativeTokenPriceInUsd.mul_(10 ** assetDecimals));
        } else {
            return assetPriceInUsd.mul_(10 ** 18).mul_(10 ** nativeTokenPriceDecimals).mul_(10 ** 18).div_(nativeTokenPriceInUsd.mul_(10 ** assetDecimals).mul_(10 ** assetPriceDecimals));
        }
    }

    function preCheckPrice(ChainlinkAggregatorV3Interface chainlinkPriceSource, CToken cToken) view external returns(uint256 priceFromChainlink, uint256 priceFromFallback) {
        (priceFromChainlink, priceFromFallback) = (getUnderlyingPriceFromChainlink(chainlinkPriceSource, cToken), getUnderlyingPriceFromFallback(cToken));
    }

    function getSourcePrice(address asset) view public returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) {
        return assetsPriceSources[asset].latestRoundData();
    }

    function getPrice(ChainlinkAggregatorV3Interface priceSource) public view returns (uint256) {
        (,int256 answer,,,) = priceSource.latestRoundData();
        if (answer > 0) {
            return uint256(answer);
        } else {
            return 0;
        }
    }

    function setAssetSources(address[] calldata assets, address[] calldata sources) external onlyGovernance {
        _setAssetsSources(assets, sources);
    }

    function updateNativeTokenPriceSource(ChainlinkAggregatorV3Interface priceSource) external onlyGovernance {
        nativeTokenPriceSource = priceSource;
    }

    function setFallbackPriceOracle(address _fallbackPriceOracle) external onlyGovernance {
        fallbackPriceOracle = PriceOracle(_fallbackPriceOracle);
    }

    function _setAssetsSources(address[] memory assets, address[] memory sources) internal {
        require(assets.length == sources.length, 'Inconsistent parameter length');
        for (uint256 i = 0; i < assets.length; i++) {
            assetsPriceSources[assets[i]] = ChainlinkAggregatorV3Interface(sources[i]);
            emit AssetPriceSourceUpdated(assets[i], sources[i]);
        }
    }

    function transferGovernance(address newGovernance) external onlyGovernance {
        require(newGovernance != address(0), "New governance is zero address");
        emit GovernanceTransferred(governance, newGovernance);
        governance = newGovernance;
    }
}
