// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Vault} from "../src/Vault.sol";
import {AaveAdapter} from "../src/AaveAdapter.sol";
import {MockAavePool} from "./mocks/MockAavePool.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockDAI is ERC20 {
    constructor() ERC20("Mock DAI", "mDAI") { _mint(msg.sender, 10_000_000e18); }
}

contract VaultHandler is Test {
    Vault public vault;
    MockDAI public dai;
    address[] public actors;

    constructor(Vault _vault, MockDAI _dai, address[] memory _actors) {
        vault = _vault;
        dai = _dai;
        actors = _actors;
    }

    function deposit(uint256 actorSeed, uint256 amount) external {
        address actor = actors[actorSeed % actors.length];
        amount = bound(amount, 0, dai.balanceOf(actor));
        if (amount == 0) return;
        vm.prank(actor);
        vault.deposit(amount, actor);
    }

    function withdraw(uint256 actorSeed, uint256 shareFraction) external {
        address actor = actors[actorSeed % actors.length];
        uint256 shares = vault.balanceOf(actor);
        if (shares == 0) return;
        uint256 toRedeem = bound(shareFraction, 0, shares);
        if (toRedeem == 0) return;
        vm.prank(actor);
        vault.redeem(toRedeem, actor, actor);
    }
}

contract VaultInvariantTest is Test {
    Vault vault;
    AaveAdapter adapter;
    MockAavePool pool;
    MockDAI dai;
    VaultHandler handler;

    function setUp() public {
        dai = new MockDAI();
        pool = new MockAavePool(address(dai));
        vault = new Vault(dai, "Yield Vault DAI", "yvDAI", address(0));
        adapter = new AaveAdapter(address(dai), address(pool.aToken()), address(vault), address(pool));
        vault.setStrategy(address(adapter));

        address[] memory actors = new address[](3);
        for (uint256 i = 0; i < 3; i++) {
            actors[i] = address(uint160(0x1000 + i));
            dai.transfer(actors[i], 100_000e18); // test contract holds the supply, funds actors directly
            vm.prank(actors[i]);
            dai.approve(address(vault), type(uint256).max);
        }

        handler = new VaultHandler(vault, dai, actors);
        targetContract(address(handler));
    }

    function invariant_totalAssetsCoversAllShares() public view {
        if (vault.totalSupply() == 0) return;
        uint256 assetsPerShare = vault.convertToAssets(1e18);
        assertGt(assetsPerShare, 0, "share value collapsed to zero");
    }

    function invariant_noValueCreatedFromNothing() public view {
    assertEq(
        vault.totalAssets(),
        adapter.aToken().balanceOf(address(adapter)),
        "totalAssets diverges from actual aToken holdings"
    );
    }
}