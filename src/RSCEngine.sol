// SPDX-License-Identifier: MIT

// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

pragma solidity ^0.8.19;

import {RomanStableCoin} from "./RomanStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/**
 * @title RSCEngine
 * @author Deogracious Aggrey
 *
 * The system is designed to be as minimal as possible, and have tokens maintain a 1 token == $1 peg
 * The stablecoin has the properties
 * -Exogenous collateral
 * -Dollar pegged
 * -Algorithmically stable
 *
 * It is similar to DAI ifDAI had no governance, no fees and was only backed by WETH & WBTC
 *
 * Our RSC should be overcollateralized. At no point, should the value of all collateral <= the $ backed value of all RSC.
 *
 * @notice This contract is the core of the RSC system. It handles all the logic for minting and redeeming RSC, as well as depositing and withdrwaing collateral
 * @notice This contract is very loosely based on the MakerDAO DSS (DAI) system
 */

contract RSCEngine is ReentrancyGuard {
    ////////////////
    // Errors     //
    ////////////////
    error RSCEngine__NeedsmoreThanZero();
    error RSCEngine__TokenAddressesAndPriceFeedAddressesArrayMustBeSameLength();
    error RSCEngine__TokenNotAllowedAsCollateral();
    error RSCEngine__TransferFailed();
    error RSCEngine__BreaksHealthFactor(uint256 healthFactor);
    error RSCEngine__MintFailed();
    error RSCEngine__HealthFactorOk();
    error RSCEngine__HealthFactorNotImproved();

    ////////////////////////////////////////////////
    // State Variables                             //
    ////////////////////////////////////////////////
    uint256 private constant ADDITIONAL_PRICEFEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50;
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    uint256 private constant LIQUIDATION_BONUS = 10;

    mapping(address token => address priceFeed) private s_priceFeed; //tokenTopriceFeed
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralAmountDeposited;
    mapping(address user => uint256 amountRSCminted) private s_RSCMinted;
    address[] private s_collateralTokens;

    RomanStableCoin private immutable i_rsc;

    ////////////////////////////////////////////////
    // Events                                     //
    ////////////////////////////////////////////////
    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);
    event CollateralRedeemed(
        address indexed redeemedFrom, address indexed redeemedTo, address indexed token, uint256 amount
    );

    ////////////////
    // Modifiers  //
    ////////////////
    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert RSCEngine__NeedsmoreThanZero();
        }
        _;
    }

    modifier isAllowedToken(address token) {
        if (s_priceFeed[token] == address(0)) {
            revert RSCEngine__TokenNotAllowedAsCollateral();
        }
        _;
    }

    ////////////////////////////////////////////////
    // Functions                                  //
    ////////////////////////////////////////////////
    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddresses, address rscAddress) {
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert RSCEngine__TokenAddressesAndPriceFeedAddressesArrayMustBeSameLength();
        }

        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeed[tokenAddresses[i]] = priceFeedAddresses[i];
            s_collateralTokens.push(tokenAddresses[i]);
        }
        i_rsc = RomanStableCoin(rscAddress);
    }

    ////////////////////////////////////////////////
    // External Functions                         //
    ////////////////////////////////////////////////

    /**
     * @notice Follows CEI
     * @param tokenCollateralAddress The address of the token to deposit as collateral
     * @param amountCollateral The amount of collateral to deposit
     * @param amountRSCToMint The amount of RomanstableCoin to mint
     * @notice This function will deposit collateral and mint RSC in one transaction
     */

    function depositCollateralAndMintRSC(
        address tokenCollateralAddress,
        uint256 amountCollateral,
        uint256 amountRSCToMint
    ) external {
        depositCollateral(tokenCollateralAddress, amountCollateral);
        mintRsc(amountRSCToMint);
    }

    /**
     * @notice Follows CEI
     * @param tokenCollateralAddress The address of the token to deposit as collateral
     * @param amountCollateral The amount of collateral to deposit
     */
    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        public
        moreThanZero(amountCollateral)
        isAllowedToken(tokenCollateralAddress)
        nonReentrant
    {
        s_collateralAmountDeposited[msg.sender][tokenCollateralAddress] += amountCollateral;
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);

        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral);
        if (!success) {
            revert RSCEngine__TransferFailed();
        }
    }
    /**
     * @param tokenCollateralAddress The address of collateral to reddem
     * @param amountCollateralToRedeem amount of collateral to redeem
     * @param amountRSCToBurn Amount of minted RSC to burn
     * This function burns RSC and redeem the underlying collateral in one tx
     */

    function redeemCollateralForRsc(
        address tokenCollateralAddress,
        uint256 amountCollateralToRedeem,
        uint256 amountRSCToBurn
    ) external {
        burnRsc(amountRSCToBurn);
        redeemCollateral(tokenCollateralAddress, amountCollateralToRedeem);
    }

    // Inorder to redeem collateral, their health factor must be above 1 after collateral is removed
    function redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        public
        moreThanZero(amountCollateral)
        nonReentrant
    {
        _redeemCollateral(tokenCollateralAddress, amountCollateral, msg.sender, msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    /**
     * @notice Follows CEI
     * @param amountOfRscToMint The amount of RomanstableCoin to mint
     * @notice They must have more collateral value than the minimu threshold
     */
    function mintRsc(uint256 amountOfRscToMint) public moreThanZero(amountOfRscToMint) nonReentrant {
        s_RSCMinted[msg.sender] += amountOfRscToMint;
        _revertIfHealthFactorIsBroken(msg.sender);
        bool minted = i_rsc.mint(msg.sender, amountOfRscToMint);
        if (!minted) {
            revert RSCEngine__MintFailed();
        }
    }

    function burnRsc(uint256 amount) public moreThanZero(amount) {
        _burnRsc(amount, msg.sender, msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    /**
     * @param collateral The address of the erc20 collateral to liquidate from the user
     * @param user The address of the user who has broken the health factor. Their _healthFactor must be below MIN_HEALTH_FACTOR
     * @param debtToCover The amount of RSC you want to burn to improve the users health factor
     * @notice You can partially liquidate a user
     * @notice You will get a liquidation bonus for liquidating the  user
     * @notice This function works on the assumption the protocol will be roughly 200% overcollateralized
     * @notice A knowm bug would be if the protocol were 100% or less collateralized, then we wouldn't be able to incentivize the liquidators
     * For example, if the price of the collateral plummeted before anyone could be liquidated
     */
    function liquidate(address collateral, address user, uint256 debtToCover) external moreThanZero(debtToCover) {
        uint256 startingUserHealthFactor = _healthFactor(user);
        if (startingUserHealthFactor >= MIN_HEALTH_FACTOR) {
            revert RSCEngine__HealthFactorOk();
        }
        //We want to burn their RSC debt
        //And take their collateral
        // E.g Bad usedr: $140 ETH, $100 src
        //debt to cover == $100
        //$100 of rsc == ?? eth ?
        uint256 tokenAmountFromDebtCovered = getTokenAmountFromUsd(collateral, debtToCover);

        //And give them a 10% bonus
        //So we are giving a liquidator $110 WETH for 100 RSC
        //We should implememnt a feature to liquidate in the event of insolvency
        //And sweep extra amounts into a treasury
        uint256 bonusCollateral = (tokenAmountFromDebtCovered * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;
        uint256 totalCollateralToTake = tokenAmountFromDebtCovered + bonusCollateral;
        _redeemCollateral(collateral, totalCollateralToTake, user, msg.sender);
        //Burn the RSC
        _burnRsc(debtToCover, user, msg.sender);

        //Check the health factor, should have improved the health factor else revert with error health factor not improved
        uint256 endingUserHealthFactor = _healthFactor(user);
        if (endingUserHealthFactor < startingUserHealthFactor) {
            revert RSCEngine__HealthFactorNotImproved();
        }

        //Revert if the health factor broken for liquidator
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function getHealthFactor() external view {}

    ////////////////////////////////////////////////
    // Private & Internal View Functions           //
    ////////////////////////////////////////////////
    /**
     * @dev Low level internal function, do not call unless the function calling it is checking the health factor being broken
     */
    function _burnRsc(uint256 amountRscToBurn, address onBehalfOf, address rscFrom) private {
        s_RSCMinted[onBehalfOf] -= amountRscToBurn;
        bool success = i_rsc.transferFrom(rscFrom, address(this), amountRscToBurn);
        if (!success) {
            revert RSCEngine__TransferFailed();
        }
        i_rsc.burn(amountRscToBurn);
    }

    function _redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral, address from, address to)
        private
    {
        s_collateralAmountDeposited[from][tokenCollateralAddress] -= amountCollateral;
        emit CollateralRedeemed(from, to, tokenCollateralAddress, amountCollateral);

        bool success = IERC20(tokenCollateralAddress).transfer(to, amountCollateral);
        if (!success) {
            revert RSCEngine__TransferFailed();
        }
    }

    function _getAccountInformation(address user)
        private
        view
        returns (uint256 totalRSCMinted, uint256 collateralValueInUSD)
    {
        totalRSCMinted = s_RSCMinted[user];
        collateralValueInUSD = getAccountCollateralValue(user);
    }

    /**
     * Returns how close to liquidation a user is
     * @param user Address of user to view their health factor
     * If a user goes below 1, they can get liquidated
     */
    function _healthFactor(address user) private view returns (uint256) {
        //We need total rsc minted
        //total collateral value value
        (uint256 totalRSCMinted, uint256 collateralValueInUSD) = _getAccountInformation(user);
        uint256 collateralAdjustedForThreshold = (collateralValueInUSD * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return (collateralAdjustedForThreshold * PRECISION) / totalRSCMinted;
        // return (collateralValueInUSD / totalRSCMinted);
    }

    //1. Check health factor(Do they have enoughj collateral)
    //2. Revert if they don't
    function _revertIfHealthFactorIsBroken(address user) internal view {
        uint256 userHealthFactor = _healthFactor(user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert RSCEngine__BreaksHealthFactor(userHealthFactor);
        }
    }

    ////////////////////////////////////////////////
    // Public & External View Functions           //
    ////////////////////////////////////////////////
    function getTokenAmountFromUsd(address token, uint256 usdAmountInWei) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeed[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();

        return (usdAmountInWei * PRECISION) / (uint256(price) * ADDITIONAL_PRICEFEED_PRECISION);
    }

    function getAccountCollateralValue(address user) public view returns (uint256 totalCollateralValueInUsd) {
        //Loop through each collateral token, get the amount of collateral they have deposited, and map it to the price to get the USD value

        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            address token = s_collateralTokens[i];
            uint256 amount = s_collateralAmountDeposited[user][token];
            totalCollateralValueInUsd += getUsdValue(token, amount);
        }
        return totalCollateralValueInUsd;
    }

    function getUsdValue(address token, uint256 amount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeed[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();

        // If 1 eth = $1000
        //The returned value from CL will be 1000 * 1e8
        return ((uint256(price) * ADDITIONAL_PRICEFEED_PRECISION) * amount) / PRECISION;
    }
}
