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
        c3VMPricing.createVirtualMachineType(1, "Basic", 100 wei);

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

    function testCreateVirtualMachine() public {
        uint256 newVmId = c3VM.createVirtualMachine(1, 5);
        assertEq(newVmId, 1, "New VM ID should be 1");

        (address vmOwner, , , ,) = c3VM.virtualMachines(newVmId);
        assertEq(vmOwner, owner, "VM owner should be the contract creator");
    
        uint256 userCredits = c3VM.userCredits(owner);
        assertEq(userCredits, 1000 - 100 * 5, "User credits should decrease by the price multiplied by the hours");

    }
    
    function testDepositTokens() public {
        uint256 initialCredits = c3VM.userCredits(owner);
        uint256 depositAmount = 500 wei;

        c3u.approve(address(c3VM), depositAmount);
        c3VM.depositTokens(depositAmount);

        uint256 newCredits = c3VM.userCredits(owner);
        assertEq(newCredits, initialCredits + depositAmount, "User credits should increase by deposit amount");
    }

    function testCannotWithdrawTokens() public {
        uint256 withdrawAmount = 2000 wei;

        vm.expectRevert("Insufficient balance to withdraw");
        c3VM.withdrawTokens(withdrawAmount);
    }

    function testCannotCreateVirtualMachineWithoutSufficientCredits() public {
        uint256 excessiveHours = 20;

        vm.expectRevert("Insufficient balance to start virtual machine");
        c3VM.createVirtualMachine(1, excessiveHours);
    }

    function testToggleVirtualMachineDeprecatedStatus() public {
        c3VMPricing.toggleVirtualMachineDeprecatedStatus(1);
        (, , bool deprecated) = c3VMPricing.virtualMachineTypes(1);
        assertTrue(deprecated, "Virtual machine type should be deprecated");

        c3VMPricing.toggleVirtualMachineDeprecatedStatus(1);
        (, , deprecated) = c3VMPricing.virtualMachineTypes(1);
        assertFalse(deprecated, "Virtual machine type should not be deprecated");
    }

    function testUpdateVirtualMachineModelName() public {
        string memory newName = "Advanced";
        c3VMPricing.updateVirtualMachineModelName(1, newName);

        (string memory modelName, , ) = c3VMPricing.virtualMachineTypes(1);
        assertEq(modelName, newName, "Model name should be updated");
    }

    function testUpdateVirtualMachinePricePerHour() public {
        uint256 newPrice = 20 wei;
        c3VMPricing.updateVirtualMachinePricePerHour(1, newPrice);

        (, uint256 pricePerHour, ) = c3VMPricing.virtualMachineTypes(1);
        assertEq(pricePerHour, newPrice, "Price per hour should be updated");
    }
}

contract C3U is ERC20 {
    constructor() ERC20("C3U", "C3U") {
        _mint(msg.sender, 1000 * 10 ** 18);
    }
}
