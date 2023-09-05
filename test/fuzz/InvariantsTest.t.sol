//SPDX-License-Identifier: MIT

//Have our invariants aka properties that should always hold
//What are our invariants?

//1. The total supply of RSC should always be less than the total value of collateral
//2. Getter view functions should never revert <- evergreen invariant

pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {RSCEngine} from "../../src/RSCEngine.sol";
import {RomanStableCoin} from "../../src/RomanStableCoin.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";

contract InvariantsTest is StdInvariant, Test {
    function setUp() external {}
}
