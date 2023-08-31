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

    ////////////////////////////////////////////////
    // State Variables                             //
    ////////////////////////////////////////////////
    mapping(address token => address priceFeed) private s_priceFeed; //tokenTopriceFeed
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralAmountDeposited;

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

    function mintRsc() external {}

    function burnRsc() external {}

    function liquidate() external {}

    function getHealthFactor() external view {}
}
