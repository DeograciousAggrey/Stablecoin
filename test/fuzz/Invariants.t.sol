//SPDX-License-Identifier: MIT

//Have our invariants aka properties that should always hold
//What are our invariants?

pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {RSCEngine} from "../../src/RSCEngine.sol";
import {RomanStableCoin} from "../../src/RomanStableCoin.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DeployRSC} from "../../script/DeployRSC.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Handler} from "./Handler.t.sol";

contract InvariantsTest is StdInvariant, Test {
    DeployRSC deployer;
    RomanStableCoin rsc;
    RSCEngine rscEngine;
    HelperConfig helperConfig;
    address ethUsdPriceFeed;
    address btcUsdPriceFeed;
    address weth;
    address wbtc;
    Handler handler;

    function setUp() external {
        deployer = new DeployRSC();
        (rsc, rscEngine, helperConfig) = deployer.run();
        (,, weth, wbtc,) = helperConfig.activeNetworkConfig();
        // targetContract(address(rscEngine));
        handler = new Handler(rscEngine, rsc);
        targetContract(address(handler));
    }

    function invariant_protocolMustHaveMoreValueThanTotalSupply() public view {
        // get the value of all the collateral in the protocol
        // Compare it to all the debt (RSC)
        uint256 totalSupply = rsc.totalSupply();
        uint256 totalWethDeposited = IERC20(weth).balanceOf(address(rscEngine));
        uint256 totalWbtcDeposited = IERC20(wbtc).balanceOf(address(rscEngine));

        uint256 wethValue = rscEngine.getUsdValue(weth, totalWethDeposited);
        uint256 wbtcValue = rscEngine.getUsdValue(wbtc, totalWbtcDeposited);

        uint256 totalValue = wethValue + wbtcValue;
        assert(totalValue >= totalSupply);
    }
}
