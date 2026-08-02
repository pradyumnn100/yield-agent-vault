// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockCompoundPool {
    IERC20 public asset;
    mapping(address => uint256) public balances;

    constructor(address asset_) {
        asset = IERC20(asset_);
    }

    function supply(address, uint256 amount) external {
        asset.transferFrom(msg.sender, address(this), amount);
        balances[msg.sender] += amount;
    }

    function withdrawTo(address to, address, uint256 amount) external {
        balances[msg.sender] -= amount;
        asset.transfer(to, amount);
    }

    function balanceOf(address account) external view returns (uint256) {
        return balances[account];
    }
}