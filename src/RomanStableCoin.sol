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

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title RomanStableCoin
 * @author Deogracious Aggrey
 * Collateral: Exogenous (ETH & BTC)
 * Minting: Algorithmic
 * Relative Stability: Pegged to USD
 * 
 *This is the contract meant to be governed by RSCEngine. This contract is just the ERC20 implementation of our stablecoin system
 *  

 */

contract RomanStableCoin is ERC20Burnable, Ownable {
    error RomanStableCoin__MustBeMoreThanZero();
    error RomanStableCoin__BurnAmountExceedsBalance();
    error RomanStableCoin__NotZeroAddress();

    constructor() ERC20("RomanStableCoin", "RSC") {}

    function burn(uint256 _amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);
        if (_amount <= 0) {
            revert RomanStableCoin__MustBeMoreThanZero();
        }
        if (balance < _amount) {
            revert RomanStableCoin__BurnAmountExceedsBalance();
        }
        super.burn(_amount);
    }

    function mint(
        address _to,
        uint256 _amount
    ) external onlyOwner returns (bool) {
        if (_to == address(0)) {
            revert RomanStableCoin__NotZeroAddress();
        }
        if (_amount <= 0) {
            revert RomanStableCoin__MustBeMoreThanZero();
        }

        _mint(_to, _amount);
        return true;
    }
}
