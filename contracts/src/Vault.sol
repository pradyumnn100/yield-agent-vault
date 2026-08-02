// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IStrategyAdapter} from "./IStrategyAdapter.sol";

contract Vault is ERC4626, AccessControl {
    using SafeERC20 for IERC20;

    bytes32 public constant AGENT_ROLE = keccak256("AGENT_ROLE");

    IStrategyAdapter public activeStrategy;
    mapping(address => bool) public isApprovedStrategy;

    constructor(
        IERC20 asset_,
        string memory name_,
        string memory symbol_,
        address strategy_
    ) ERC4626(asset_) ERC20(name_, symbol_) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        activeStrategy = IStrategyAdapter(strategy_);
    }

    function setStrategy(address newStrategy) external onlyRole(DEFAULT_ADMIN_ROLE) {
        activeStrategy = IStrategyAdapter(newStrategy);
    }

    function approveStrategy(address strategy) external onlyRole(DEFAULT_ADMIN_ROLE) {
        isApprovedStrategy[strategy] = true;
    }

    function rebalance(address newStrategy) external onlyRole(AGENT_ROLE) {
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
        super._deposit(caller, receiver, assets, shares);
        IERC20(asset()).forceApprove(address(activeStrategy), assets);
        activeStrategy.deposit(assets);
    }

    function _withdraw(address caller, address receiver, address owner, uint256 assets, uint256 shares) internal override {
        activeStrategy.withdraw(assets);
        super._withdraw(caller, receiver, owner, assets, shares);
    }
}