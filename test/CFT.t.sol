// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../src/C3VirtualMachine.sol";
import "../src/C3VirtualMachinePricing.sol";

contract CFTTest is Test {
    C3VirtualMachinePricing private c3VMPricing;
    C3VirtualMachine private c3VM;
    C3U private c3u;
    address private owner;
    address private user;
    uint256 private vmId;

    function setUp() public {
        owner = address(this);
        
        // Deploy pricing contract
        c3VMPricing = new C3VirtualMachinePricing();

        // Create a virtual machine type
        c3VMPricing.createVirtualMachineType(1, "Basic", 10 wei);

        c3u = new C3U();

        // Deploy the virtual machine contract
        c3VM = new C3VirtualMachine(address(c3u), address(c3VMPricing));

        // Transfer tokens to the virtual machine contract
        c3u.approve(address(c3VM), 1000 wei);

        // Set initial balances
        c3VM.depositTokens(1000 wei);
    }

    function testPriceExist() view public {
        bool pricingExists = c3VMPricing.idExists(1);
        assertTrue(pricingExists, "Pricing should exist");
    }

    function testCreditShouldBe1000() view public {
        uint256 userCredits = c3VM.userCredits(owner);
        assertEq(userCredits, 1000 wei, "User credits should be 1000");
    }

    function testCreateAndOwnerVirtualMachine() public {
        uint256 newVmId = c3VM.createVirtualMachine(1, 10);
        assertEq(newVmId, 1, "New VM ID should be 1");

        (address vmOwner,,,,) = c3VM.virtualMachines(newVmId);
        assertEq(vmOwner, owner, "VM owner should be the contract creator");
    }
}

contract C3U is ERC20 {
    constructor() ERC20("C3U", "C3U") {
        _mint(msg.sender, 1000 * 10 ** 18);
    }
}
