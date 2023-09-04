//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {RomanStableCoin} from "../src/RomanStableCoin.sol";
import {RSCEngine} from "../src/RSCEngine.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployRSC is Script {
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function run() external returns (RomanStableCoin, RSCEngine) {
        HelperConfig helperConfig = new HelperConfig();

        (address wethUsdPriceFeed, address wbtcUsdPriceFeed, address weth, address wbtc, uint256 deployerKey) =
            helperConfig.activeNetworkConfig();

        tokenAddresses = [weth, wbtc];
        priceFeedAddresses = [wethUsdPriceFeed, wbtcUsdPriceFeed];

        vm.startBroadcast(deployerKey);
        RomanStableCoin rsc = new RomanStableCoin();
        RSCEngine rscEngine = new RSCEngine(tokenAddresses, priceFeedAddresses, address(rsc));

        rsc.transferOwnership(address(rscEngine));

        vm.stopBroadcast();

        return (rsc, rscEngine);
    }
}
