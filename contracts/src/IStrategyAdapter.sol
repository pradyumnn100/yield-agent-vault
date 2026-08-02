// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IStrategyAdapter {
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function totalDeposited() external view returns (uint256);
    function currentAPY() external view returns (uint256);
}