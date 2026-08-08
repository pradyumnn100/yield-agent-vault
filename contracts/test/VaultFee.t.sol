// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Vault} from "../src/Vault.sol";
import {AaveAdapter} from "../src/AaveAdapter.sol";
import {MockAavePool} from "./mocks/MockAavePool.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockDAI is ERC20 {
    constructor() ERC20("Mock DAI", "mDAI") { _mint(msg.sender, 1_000_000e18); }
}

contract VaultFeeTest is Test {
    Vault vault;
    AaveAdapter adapter;
    MockAavePool pool;
    MockDAI dai;
    address user = address(0xBEEF);
    address feeCollector = address(0xFEE5);

    function setUp() public {
        dai = new MockDAI();
        pool = new MockAavePool(address(dai));

        vault = new Vault(dai, "Yield Vault DAI", "yvDAI", address(0));
        adapter = new AaveAdapter(address(dai), address(pool.aToken()), address(vault), address(pool));
        vault.setStrategy(address(adapter));

        vault.setFeeCollector(feeCollector);
        vault.setWithdrawalFee(50); // 0.5%

        dai.transfer(user, 1_000e18);
    }

    function testWithdrawalFeeSplitsCorrectly() public {
        vm.startPrank(user);
        dai.approve(address(vault), 100e18);
        vault.deposit(100e18, user);

        uint256 userBalBefore = dai.balanceOf(user);
        vault.redeem(vault.balanceOf(user), user, user);
        vm.stopPrank();

        uint256 userReceived = dai.balanceOf(user) - userBalBefore;
        uint256 feeCollected = dai.balanceOf(feeCollector);

        // 0.5% of 100 DAI = 0.5 DAI fee, 99.5 DAI to user
        assertEq(feeCollected, 0.5e18);
        assertEq(userReceived, 99.5e18);
        assertEq(feeCollected + userReceived, 100e18); // no funds lost or created

        console.log("User received:", userReceived);
        console.log("Fee collected:", feeCollected);
    }

    function testZeroFeeByDefault() public {
        // Confirms existing behavior is unaffected when fee isn't configured
        Vault freshVault = new Vault(dai, "No Fee Vault", "nfDAI", address(0));
        AaveAdapter freshAdapter = new AaveAdapter(address(dai), address(pool.aToken()), address(freshVault), address(pool));
        freshVault.setStrategy(address(freshAdapter));

        vm.startPrank(user);
        dai.approve(address(freshVault), 50e18);
        freshVault.deposit(50e18, user);
        uint256 before = dai.balanceOf(user);
        freshVault.redeem(freshVault.balanceOf(user), user, user);
        vm.stopPrank();

        assertEq(dai.balanceOf(user) - before, 50e18); // full amount back, zero fee
    }
}