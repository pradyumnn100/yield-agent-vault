// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IStrategyAdapter} from "./IStrategyAdapter.sol";

contract Vault is ERC4626, Ownable {
    using SafeERC20 for IERC20;

    IStrategyAdapter public activeStrategy;

    constructor(
        IERC20 asset_,
        string memory name_,
        string memory symbol_,
        address strategy_
    )
    
     ERC4626(asset_) ERC20(name_, symbol_) Ownable(msg.sender) {
        activeStrategy = IStrategyAdapter(strategy_);
    }
    function setStrategy(address newStrategy) external onlyOwner {
    activeStrategy = IStrategyAdapter(newStrategy);
}

    mapping(address => bool) public isApprovedStrategy;

    function approveStrategy(address strategy) external onlyOwner {
    isApprovedStrategy[strategy] = true;
}

    function rebalance(address newStrategy) external onlyOwner {
    require(isApprovedStrategy[newStrategy], "not whitelisted");
    uint256 amount = activeStrategy.totalDeposited();

    if (amount > 0) {
        activeStrategy.withdraw(amount);
        IERC20(asset()).forceApprove(newStrategy, amount);
    }

    activeStrategy = IStrategyAdapter(newStrategy);

    if (amount > 0) {
        activeStrategy.deposit(amount);
    }
}

    function totalAssets() public view override returns (uint256) {
        return activeStrategy.totalDeposited();
    }

    function _deposit(address caller, address receiver, uint256 assets, uint256 shares) internal override {
        super._deposit(caller, receiver, assets, shares); // pulls assets from depositor into vault
        IERC20(asset()).forceApprove(address(activeStrategy), assets);
        activeStrategy.deposit(assets); // forward into Aave
    }

    function _withdraw(address caller, address receiver, address owner, uint256 assets, uint256 shares) internal override {
        activeStrategy.withdraw(assets); // pull back from Aave first
        super._withdraw(caller, receiver, owner, assets, shares);
    }
}