// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {C3ResourcePricing} from "../src/C3ResourcePricing.sol";
import {C3VirtualMachine} from "../src/C3VirtualMachine.sol";
import {C3Volume} from "../src/C3Volume.sol";

contract DeployC3Contracts is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("SEPOLIA_PRIVATE_KEY");
        address manager = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        C3ResourcePricing c3ResourcePricing = new C3ResourcePricing();
        address pricingAddress = address(c3ResourcePricing);
        console.log("C3ResourcePricing deployed at:", pricingAddress);

        c3ResourcePricing.createResource(10, "RTX-A4000", 300000000, C3ResourcePricing.ResourceType.VirtualMachine);
        c3ResourcePricing.createResource(11, "RTX-A5000", 500000000, C3ResourcePricing.ResourceType.VirtualMachine);
        c3ResourcePricing.createResource(14, "Cloud-SSD", 96774, C3ResourcePricing.ResourceType.Volume);
        c3ResourcePricing.createResource(15, "PublicIP", 6720430, C3ResourcePricing.ResourceType.Other);

        address tokenAddress = vm.envAddress("SEPOLIA_TOKEN_ADDRESS");
        C3VirtualMachine c3VirtualMachine = new C3VirtualMachine(tokenAddress, pricingAddress, manager);
        address virtualMachineAddress = address(c3VirtualMachine);
        console.log("C3VirtualMachine deployed at:", virtualMachineAddress);

        C3Volume c3Volume = new C3Volume(pricingAddress);
        address volumeAddress = address(c3Volume);
        console.log("C3Volume deployed at:", volumeAddress);

        vm.stopBroadcast();
    }
}
