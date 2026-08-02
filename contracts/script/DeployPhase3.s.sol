// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {Vault} from "../src/Vault.sol";
import {AaveAdapter} from "../src/AaveAdapter.sol";
import {CompoundAdapter} from "../src/CompoundAdapter.sol";
import {MockAavePool} from "../test/mocks/MockAavePool.sol";
import {MockCompoundPool} from "../test/mocks/MockCompoundPool.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockDAI is ERC20 {
    constructor() ERC20("Mock DAI", "mDAI") { _mint(msg.sender, 1_000_000e18); }
}

contract DeployPhase3 is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address agentAddress = vm.envAddress("AGENT_ADDRESS");
        vm.startBroadcast(deployerKey);

        MockDAI dai = new MockDAI();
        MockAavePool aavePool = new MockAavePool(address(dai));
        MockCompoundPool compoundPool = new MockCompoundPool(address(dai));

        Vault vault = new Vault(dai, "Yield Vault DAI", "yvDAI", address(0));
        AaveAdapter aaveAdapter = new AaveAdapter(address(dai), address(aavePool.aToken()), address(vault), address(aavePool));
        CompoundAdapter compoundAdapter = new CompoundAdapter(address(dai), address(compoundPool), address(vault));

        vault.setStrategy(address(aaveAdapter));
        vault.approveStrategy(address(aaveAdapter));
        vault.approveStrategy(address(compoundAdapter));
        vault.grantRole(vault.AGENT_ROLE(), agentAddress);

        console.log("DAI:", address(dai));
        console.log("Vault:", address(vault));
        console.log("AaveAdapter:", address(aaveAdapter));
        console.log("CompoundAdapter:", address(compoundAdapter));

        vm.stopBroadcast();
    }
}