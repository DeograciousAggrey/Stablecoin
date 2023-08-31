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

    ////////////////////////////////////////////////
    // State Variables                             //
    ////////////////////////////////////////////////
    uint256 private constant ADDITIONAL_PRICEFEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50;
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1;

    mapping(address token => address priceFeed) private s_priceFeed; //tokenTopriceFeed
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralAmountDeposited;
    mapping(address user => uint256 amountRSCminted) private s_RSCMinted;
    address[] private s_collateralTokens;

    RomanStableCoin private immutable i_rsc;

    ////////////////////////////////////////////////
    // Events                                     //
    ////////////////////////////////////////////////
    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);

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

    function depositCollateralAndMintRSC() external {}

    /**
     * @notice Follows CEI
     * @param tokenCollateralAddress The address of the token to deposit as collateral
     * @param amountCollateral The amount of collateral to deposit
     */
    function depositColllateral(address tokenCollateralAddress, uint256 amountCollateral)
        external
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

    function redeemCollateralForRsc() external {}

    function redeemCollateral() external {}

    /**
     * @notice Follows CEI
     * @param amountOfRscToMint The amount of RomanstableCoin to mint
     * @notice They must have more collateral value than the minimu threshold
     */
    function mintRsc(uint256 amountOfRscToMint) external moreThanZero(amountOfRscToMint) nonReentrant {
        s_RSCMinted[msg.sender] += amountOfRscToMint;
        _revertIfHealthFactorIsBroken(msg.sender);
        bool minted = i_rsc.mint(msg.sender, amountOfRscToMint);
        if (!minted) {
            revert RSCEngine__MintFailed();
        }
    }

    function burnRsc() external {}

    function liquidate() external {}

    function getHealthFactor() external view {}

    ////////////////////////////////////////////////
    // Private & Internal View Functions           //
    ////////////////////////////////////////////////

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
