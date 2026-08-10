// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IStrategyAdapter} from "./IStrategyAdapter.sol";
import {IPool} from "./IPool.sol";

contract AaveAdapter is IStrategyAdapter {
    using SafeERC20 for IERC20;

    IERC20 public immutable asset;
    IERC20 public immutable aToken;
    address public immutable vault;

    modifier onlyVault() {
        require(msg.sender == vault, "not vault");
        _;
    }
    IPool public immutable AAVE_POOL;

    constructor(address asset_, address aToken_, address vault_, address pool_) {
    require(vault_ != address(0), "zero address");
    asset = IERC20(asset_);
    aToken = IERC20(aToken_);
    vault = vault_;
    AAVE_POOL = IPool(pool_);
}

    function deposit(uint256 amount) external onlyVault {
        asset.safeTransferFrom(msg.sender, address(this), amount);
        asset.forceApprove(address(AAVE_POOL), amount);
        AAVE_POOL.supply(address(asset), amount, address(this), 0);
    }

    function withdraw(uint256 amount) external onlyVault {
        AAVE_POOL.withdraw(address(asset), amount, msg.sender);
    }

    function totalDeposited() external view returns (uint256) {
        return aToken.balanceOf(address(this)); // aTokens are 1:1 with underlying + accrued interest
    }

    uint256 public mockAPY;

function setMockAPY(uint256 apy) external {
    mockAPY = apy;
}

function currentAPY() external view returns (uint256) {
    return mockAPY;
}
}