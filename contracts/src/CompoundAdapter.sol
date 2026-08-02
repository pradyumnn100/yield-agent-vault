// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IStrategyAdapter} from "./IStrategyAdapter.sol";
import {IComet} from "./IComet.sol";

contract CompoundAdapter is IStrategyAdapter {
    using SafeERC20 for IERC20;

    IERC20 public immutable asset;
    IComet public immutable comet;
    address public immutable vault;

    modifier onlyVault() {
        require(msg.sender == vault, "not vault");
        _;
    }

    constructor(address asset_, address comet_, address vault_) {
        asset = IERC20(asset_);
        comet = IComet(comet_);
        vault = vault_;
    }

    function deposit(uint256 amount) external onlyVault {
        asset.safeTransferFrom(msg.sender, address(this), amount);
        asset.forceApprove(address(comet), amount);
        comet.supply(address(asset), amount);
    }

    function withdraw(uint256 amount) external onlyVault {
        comet.withdrawTo(msg.sender, address(asset), amount); // sends straight back to vault
    }

    function totalDeposited() external view returns (uint256) {
        return comet.balanceOf(address(this));
    }

    function currentAPY() external pure returns (uint256) {
        return 0; // wired up in a later phase
    }
}