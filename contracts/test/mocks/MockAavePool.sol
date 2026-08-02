// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockAToken is ERC20 {
    constructor() ERC20("Mock aToken", "aMOCK") {}
    function mint(address to, uint256 amount) external { _mint(to, amount); }
    function burn(address from, uint256 amount) external { _burn(from, amount); }
}

contract MockAavePool {
    MockAToken public aToken;
    IERC20 public underlying;

    constructor(address underlying_) {
        underlying = IERC20(underlying_);
        aToken = new MockAToken();
    }

    function supply(address asset, uint256 amount, address onBehalfOf, uint16) external {
        IERC20(asset).transferFrom(msg.sender, address(this), amount);
        aToken.mint(onBehalfOf, amount); // 1:1, no yield simulation yet — fine for Phase 1
    }

    function withdraw(address asset, uint256 amount, address to) external returns (uint256) {
        aToken.burn(msg.sender, amount);
        IERC20(asset).transfer(to, amount);
        return amount;
    }
}