//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {RSCEngine} from "../../src/RSCEngine.sol";
import {RomanStableCoin} from "../../src/RomanStableCoin.sol";
import {DeployRSC} from "../../script/DeployRSC.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";

contract RSCEngineTest is Test {
    DeployRSC deployer;
    RomanStableCoin rsc;
    RSCEngine rscEngine;
    HelperConfig helperConfig;

    function setUp() public {
        deployer = new DeployRSC();
        (rsc, rscEngine, helperConfig) = deployer.run();
    }

    ////////////////////////////////////////////////////
    // Price tests
}
