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
    address btcUsdPriceFeed;
    address weth;
    address wbtc;

    address public USER = makeAddr("user");
    uint256 public constant AMOUNT_COLLATERAL = 10000 ether;
    uint256 public constant STARTING_USER_BALANCE = 100000 ether;

    function setUp() public {
        deployer = new DeployRSC();
        (rsc, rscEngine, helperConfig) = deployer.run();
        (ethUsdPriceFeed, btcUsdPriceFeed, weth, wbtc,) = helperConfig.activeNetworkConfig();

        ERC20Mock(weth).mint(USER, STARTING_USER_BALANCE);
        ERC20Mock(wbtc).mint(USER, STARTING_USER_BALANCE);
    }

    /////////////////////////////////////////////////
    // Constructor tests                            //
    /////////////////////////////////////////////////
    address[] tokenAddresses;
    address[] priceFeedAddresses;

    function testRevertIfTokenAddresseslengthDoesntMatchPriceFeedLength() public {
        tokenAddresses.push(weth);
        priceFeedAddresses.push(ethUsdPriceFeed);
        priceFeedAddresses.push(btcUsdPriceFeed);

        vm.expectRevert(RSCEngine.RSCEngine__TokenAddressesAndPriceFeedAddressesArrayMustBeSameLength.selector);
        new RSCEngine(tokenAddresses, priceFeedAddresses, address(rsc));
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

    function testGetTokenAmountFromUsd() public {
        uint256 usdAmount = 100 ether;
        uint256 expectedWeth = 0.05 ether;
        uint256 actualWeth = rscEngine.getTokenAmountFromUsd(weth, usdAmount);
        assertEq(actualWeth, expectedWeth);
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

    function testRevertsWhenuserDepositsUnapprovedToken() public {
        ERC20Mock randomToken = new ERC20Mock("RANDOM", "RANDOM", USER, AMOUNT_COLLATERAL);
        vm.startPrank(USER);
        vm.expectRevert(RSCEngine.RSCEngine__TokenNotAllowedAsCollateral.selector);
        rscEngine.depositCollateral(address(randomToken), AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    modifier depositedCollateral() {
        vm.startPrank(USER);
        // ERC20Mock(weth).approve(address(rscEngine), AMOUNT_COLLATERAL);
        // rscEngine.depositCollateral(weth, AMOUNT_COLLATERAL);
        ERC20Mock(wbtc).approve(address(rscEngine), AMOUNT_COLLATERAL);
        rscEngine.depositCollateral(wbtc, AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;
    }

    function testCanDepositCollateralAndGetAccountInfo() public depositedCollateral {
        (uint256 totalRSCMinted, uint256 collateralValueInUsd) = rscEngine.getAccountInformation(USER);

        uint256 expectedTotalRSCMinted = 0;
        uint256 expectedDepositAmount = rscEngine.getTokenAmountFromUsd(wbtc, collateralValueInUsd);

        assertEq(totalRSCMinted, expectedTotalRSCMinted);
        assertEq(expectedDepositAmount, AMOUNT_COLLATERAL);
    }
}
