// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Vault} from "../src/Vault.sol";
import {AaveAdapter} from "../src/AaveAdapter.sol";
import {MockAavePool, MockAToken} from "./mocks/MockAavePool.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockDAI is ERC20 {
    constructor() ERC20("Mock DAI", "mDAI") { _mint(msg.sender, 1_000_000e18); }
}

contract VaultAaveMockTest is Test {
    Vault vault;
    AaveAdapter adapter;
    MockAavePool pool;
    MockDAI dai;
    address user = address(0xBEEF);

    function setUp() public {
        dai = new MockDAI();
        pool = new MockAavePool(address(dai));

        vault = new Vault(dai, "Yield Vault DAI", "yvDAI", address(0));
        adapter = new AaveAdapter(address(dai), address(pool.aToken()), address(vault), address(pool));
        vault.setStrategy(address(adapter));

        dai.transfer(user, 1_000e18);
    }

    function testDepositAndWithdraw() public {
        vm.startPrank(user);
        dai.approve(address(vault), 100e18);
        vault.deposit(100e18, user);
        vm.stopPrank();

        assertEq(vault.totalAssets(), 100e18);
        console.log("Total assets after deposit:", vault.totalAssets());

        vm.startPrank(user);
        vault.redeem(vault.balanceOf(user), user, user);
        vm.stopPrank();

        assertEq(dai.balanceOf(user), 1_000e18);
        console.log("User balance after withdraw:", dai.balanceOf(user));
    }
}