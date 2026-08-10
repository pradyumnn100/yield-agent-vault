// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Vault} from "../src/Vault.sol";
import {AaveAdapter} from "../src/AaveAdapter.sol";
import {CompoundAdapter} from "../src/CompoundAdapter.sol";
import {MockAavePool} from "./mocks/MockAavePool.sol";
import {MockCompoundPool} from "./mocks/MockCompoundPool.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockDAI is ERC20 {
    constructor() ERC20("Mock DAI", "mDAI") { _mint(msg.sender, 1_000_000e18); }
}

contract VaultRebalanceTest is Test {
    Vault vault;
    AaveAdapter aaveAdapter;
    CompoundAdapter compoundAdapter;
    MockAavePool aavePool;
    MockCompoundPool compoundPool;
    MockDAI dai;
    address user = address(0xBEEF);

    function setUp() public {
        dai = new MockDAI();
        aavePool = new MockAavePool(address(dai));
        compoundPool = new MockCompoundPool(address(dai));

        vault = new Vault(dai, "Yield Vault DAI", "yvDAI", address(0));
        aaveAdapter = new AaveAdapter(address(dai), address(aavePool.aToken()), address(vault), address(aavePool));
        compoundAdapter = new CompoundAdapter(address(dai), address(compoundPool), address(vault));

        vault.setStrategy(address(aaveAdapter));
        vault.grantRole(vault.AGENT_ROLE(), address(this));
        vault.proposeStrategy(address(compoundAdapter));
        vm.warp(block.timestamp + vault.STRATEGY_TIMELOCK() + 1);
        vault.approveStrategy(address(compoundAdapter));

        dai.transfer(user, 1_000e18);
    }

    function testRebalanceMovesFundsBetweenStrategies() public {
        vm.startPrank(user);
        dai.approve(address(vault), 100e18);
        vault.deposit(100e18, user);
        vm.stopPrank();

        assertEq(aaveAdapter.totalDeposited(), 100e18);
        assertEq(compoundAdapter.totalDeposited(), 0);
        console.log("Before rebalance - Aave:", aaveAdapter.totalDeposited());

        vault.rebalance(address(compoundAdapter));

        assertEq(aaveAdapter.totalDeposited(), 0);
        assertEq(compoundAdapter.totalDeposited(), 100e18);
        console.log("After rebalance - Compound:", compoundAdapter.totalDeposited());

        assertEq(vault.totalAssets(), 100e18); // share value unaffected by the move

        vm.startPrank(user);
        vault.redeem(vault.balanceOf(user), user, user);
        vm.stopPrank();

        assertEq(dai.balanceOf(user), 1_000e18);
        console.log("User balance after withdraw:", dai.balanceOf(user));
    }

    function testCannotApproveStrategyBeforeTimelock() public {
        address fakeStrategy = address(0x9999);
        vault.proposeStrategy(fakeStrategy);

        vm.expectRevert("timelock not elapsed");
        vault.approveStrategy(fakeStrategy);
    }
}