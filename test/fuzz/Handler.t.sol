//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {RSCEngine} from "../../src/RSCEngine.sol";
import {RomanStableCoin} from "../../src/RomanStableCoin.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DeployRSC} from "../../script/DeployRSC.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

contract Handler is Test {
    RSCEngine rscEngine;
    RomanStableCoin rsc;

    ERC20Mock weth;
    ERC20Mock wbtc;

    uint256 MAX_DEPOSIT_SIZE = type(uint96).max;

    constructor(RSCEngine _rscEngine, RomanStableCoin _rsc) {
        rscEngine = _rscEngine;
        rsc = _rsc;

        address[] memory collateralTokens = rscEngine.getCollateralTokens();
        weth = ERC20Mock(collateralTokens[0]);
        wbtc = ERC20Mock(collateralTokens[1]);
    }

    //Redeem Collateral

    function depositCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        //rscEngine.depositCollateral(collateral, amountCollateral);
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        amountCollateral = bound(amountCollateral, 1, MAX_DEPOSIT_SIZE);

        vm.startPrank(msg.sender);
        collateral.mint(msg.sender, amountCollateral);
        collateral.approve(address(rscEngine), amountCollateral);

        rscEngine.depositCollateral(address(collateral), amountCollateral);
        vm.stopPrank();
    }

    //Helper Functions
    function _getCollateralFromSeed(uint256 collateralSeed) private view returns (ERC20Mock) {
        if (collateralSeed % 2 == 0) {
            return weth;
        } else {
            return wbtc;
        }
    }
}
