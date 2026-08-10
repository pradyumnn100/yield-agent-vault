// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IStrategyAdapter} from "./IStrategyAdapter.sol";

contract Vault is ERC4626, AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    bytes32 public constant AGENT_ROLE = keccak256("AGENT_ROLE");

    IStrategyAdapter public activeStrategy;
        uint256 public constant MAX_FEE_BPS = 500; // hard cap at 5%, sanity bound against admin error
        uint256 public withdrawalFeeBps; // e.g. 50 = 0.5%. Defaults to 0.
        address public feeCollector;
        uint256 public constant STRATEGY_TIMELOCK = 1 hours;
        mapping(address => uint256) public strategyProposedAt;

        event StrategyProposed(address indexed strategy, uint256 executeAfter);
        event StrategyApproved(address indexed strategy);
        event FeeCollected(address indexed collector, uint256 amount);
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

    function proposeStrategy(address strategy) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(strategy != address(0), "zero address");
        strategyProposedAt[strategy] = block.timestamp;
        emit StrategyProposed(strategy, block.timestamp + STRATEGY_TIMELOCK);
    }

    function approveStrategy(address strategy) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 proposedAt = strategyProposedAt[strategy];
        require(proposedAt != 0, "not proposed");
        require(block.timestamp >= proposedAt + STRATEGY_TIMELOCK, "timelock not elapsed");
        isApprovedStrategy[strategy] = true;
        emit StrategyApproved(strategy);
    }

    function cancelStrategyProposal(address strategy) external onlyRole(DEFAULT_ADMIN_ROLE) {
        delete strategyProposedAt[strategy];
    }

    function setWithdrawalFee(uint256 feeBps) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(feeBps <= MAX_FEE_BPS, "fee too high");
            withdrawalFeeBps = feeBps;
    }

    function setFeeCollector(address collector) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(collector != address(0), "zero address");
            feeCollector = collector;
    }

    function rebalance(address newStrategy) external onlyRole(AGENT_ROLE) nonReentrant {
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
        activeStrategy.withdraw(assets); // pull back from strategy into the vault, unchanged from before

        if (caller != owner) {
            _spendAllowance(owner, caller, shares);
        }
        _burn(owner, shares);

        uint256 fee = (assets * withdrawalFeeBps) / 10_000;
        uint256 netAssets = assets - fee;

        IERC20(asset()).safeTransfer(receiver, netAssets);

        if (fee > 0 && feeCollector != address(0)) {
            IERC20(asset()).safeTransfer(feeCollector, fee);
            emit FeeCollected(feeCollector, fee);
        }

        emit Withdraw(caller, receiver, owner, assets, shares);
    }
}