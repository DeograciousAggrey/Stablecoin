//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {RSCEngine} from "../../src/RSCEngine.sol";
import {RomanStableCoin} from "../../src/RomanStableCoin.sol";
import {DeployRSC} from "../../script/DeployRSC.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

contract RSCEngineTest is Test {
    DeployRSC deployer;
    RomanStableCoin rsc;
    RSCEngine rscEngine;
    HelperConfig helperConfig;
    address ethUsdPriceFeed;
    address weth;

    address public USER = makeAddr("user");
    uint256 public constant AMOUNT_COLLATERAL = 10000 ether;
    uint256 public constant STARTING_USER_BALANCE = 100 ether;

    function setUp() public {
        deployer = new DeployRSC();
        (rsc, rscEngine, helperConfig) = deployer.run();
        (ethUsdPriceFeed,, weth,,) = helperConfig.activeNetworkConfig();

        ERC20Mock(weth).mint(USER, STARTING_USER_BALANCE);
    }

    ////////////////////////////////////////////////////
    // Price tests                                   //
    ////////////////////////////////////////////////////

    function testGetUsdValue() public {
        uint256 ethAmount = 15e18;
        //15e18 * 2000/ ETH =30000e18;
        uint256 expectedUsdValue = 30000e18;
        uint256 actualUsdValue = rscEngine.getUsdValue(weth, ethAmount);
        assertEq(actualUsdValue, expectedUsdValue);
    }

    /////////////////////////////////////////////////
    // Deposit Collateral tests                    //
    /////////////////////////////////////////////////

    function testRevertsIfCollateralIsZero() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(rscEngine), AMOUNT_COLLATERAL);

        vm.expectRevert(RSCEngine.RSCEngine__NeedsmoreThanZero.selector);
        rscEngine.depositCollateral(weth, 0);
        vm.stopPrank();
    }
}
