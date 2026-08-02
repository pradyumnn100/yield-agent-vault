// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Vault} from "../src/Vault.sol";
import {AaveAdapter} from "../src/AaveAdapter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract VaultAaveForkTest is Test {
    Vault public vault;
    AaveAdapter public adapter;

    address constant ASSET = 0xFF34B3d4Aee8ddCd6F9AFFFB6Fe49bD371b8a357;  // DAI
    address constant ATOKEN = 0x29598b72eb5CeBd806C5dCD549490FdA35B13cD8; // aDAI
    address user = address(0xBEEF);

    function setUp() public {
        vm.createSelectFork(vm.envString("SEPOLIA_RPC_URL"));

        vault = new Vault(IERC20(ASSET), "Yield Vault USDC", "yvUSDC", address(0));
        adapter = new AaveAdapter(ASSET, ATOKEN, address(vault));
        vault.setStrategy(address(adapter));

        deal(ASSET, user, 10e18); // adjust decimals if your test asset isn't 6-decimal
    }

    function testDepositAccrueWithdraw() public {
        vm.startPrank(user);
        IERC20(ASSET).approve(address(vault), 10e18);
        vault.deposit(10e18, user);
        vm.stopPrank();

        uint256 afterDeposit = vault.totalAssets();
        assertGt(afterDeposit, 0);
        console.log("Total assets after deposit:", afterDeposit);

        vm.warp(block.timestamp + 30 days);
        vm.roll(block.number + 1);

        uint256 afterTime = vault.totalAssets();
        console.log("Total assets after 30 days:", afterTime);
        assertGe(afterTime, afterDeposit); // interest should never make this go down

        vm.startPrank(user);
        vault.redeem(vault.balanceOf(user), user, user);
        vm.stopPrank();

        uint256 userBalance = IERC20(ASSET).balanceOf(user);
        console.log("User balance after withdraw:", userBalance);
        assertGt(userBalance, 0);
    }
}