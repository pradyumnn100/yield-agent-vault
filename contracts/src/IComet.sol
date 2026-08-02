// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IComet {
    function supply(address asset, uint256 amount) external;
    function withdrawTo(address to, address asset, uint256 amount) external;
    function balanceOf(address account) external view returns (uint256);
}