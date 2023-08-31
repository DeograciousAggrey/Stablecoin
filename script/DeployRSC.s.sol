//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {RomanStableCoin} from "../src/RomanStableCoin.sol";
import {RSCEngine} from "../src/RSCEngine.sol";

contract DeployRSC is Script {
    function run() external returns (RomanStableCoin, RSCEngine) {
        vm.startBroadcast();
        RomanStableCoin rsc = new RomanStableCoin();

        vm.stopBroadcast();
    }
}
