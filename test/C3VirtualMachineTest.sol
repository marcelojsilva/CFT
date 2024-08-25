// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../src/C3VirtualMachine.sol";
import "../src/C3VirtualMachinePricing.sol";

contract C3VirtualMachineTest is Test {
    C3VirtualMachinePricing private c3VMPricing;
    C3VirtualMachine private c3VM;
    C3U private c3u;
    address private owner;
    address private user;
    uint256 private constant INITIAL_BALANCE = 1000 ether; // Use a larger initial balance
    uint256 private constant VM_TYPE_ID = 1;
    uint256 private constant PRICE_PER_HOUR = 0.1 ether; // Use a more realistic price

    function setUp() public {
        owner = address(this);
        user = address(0x1234);
        
        // Deploy pricing contract
        c3VMPricing = new C3VirtualMachinePricing();

        // Create a virtual machine type
        c3VMPricing.createVirtualMachineType(VM_TYPE_ID, "Basic", PRICE_PER_HOUR);

        c3u = new C3U();

        // Deploy the virtual machine contract
        c3VM = new C3VirtualMachine(address(c3u), address(c3VMPricing), 1000); // Add token per ETH rate

        // Mint tokens to the owner and approve the VM contract
        c3u.mint(owner, INITIAL_BALANCE);
        c3u.approve(address(c3VM), INITIAL_BALANCE);

        // Deposit tokens to the VM contract
        c3VM.depositTokens(INITIAL_BALANCE);
    }

    function testPriceExist() public {
        bool pricingExists = c3VMPricing.idExists(VM_TYPE_ID);
        assertTrue(pricingExists, "Pricing should exist");
    }

    function testInitialCredit() public {
        uint256 userCredits = c3VM.userCredits(owner);
        assertEq(userCredits, INITIAL_BALANCE, "User credits should be equal to initial balance");
    }

    function testCreateVirtualMachine() public {
        uint256 hoursToRun = 5;
        uint256 expectedCost = PRICE_PER_HOUR * hoursToRun;
        uint256 initialCredits = c3VM.userCredits(owner);

        uint256 newVmId = c3VM.createVirtualMachine(VM_TYPE_ID, hoursToRun);
        assertEq(newVmId, 1, "New VM ID should be 1");

        (address vmOwner, , , , , , ,) = c3VM.virtualMachines(newVmId);
        assertEq(vmOwner, owner, "VM owner should be the contract creator");
    
        uint256 userCredits = c3VM.userCredits(owner);
        assertEq(userCredits, initialCredits - expectedCost, "User credits should decrease by the expected cost");
    }
    
    function testDepositTokens() public {
        uint256 initialCredits = c3VM.userCredits(owner);
        uint256 depositAmount = 500 ether;

        c3u.approve(address(c3VM), depositAmount);
        c3VM.depositTokens(depositAmount);

        uint256 newCredits = c3VM.userCredits(owner);
        assertEq(newCredits, initialCredits + depositAmount, "User credits should increase by deposit amount");
    }

    function testCannotWithdrawTokens() public {
        uint256 withdrawAmount = INITIAL_BALANCE + 1 ether;

        vm.expectRevert("Insufficient balance to withdraw");
        c3VM.withdrawTokens(withdrawAmount);
    }

    function testCannotCreateVirtualMachineWithoutSufficientCredits() public {
        uint256 excessiveHours = INITIAL_BALANCE / PRICE_PER_HOUR + 1;

        vm.expectRevert("Insufficient balance to start virtual machine");
        c3VM.createVirtualMachine(VM_TYPE_ID, excessiveHours);
    }

    function testToggleVirtualMachineDeprecatedStatus() public {
        c3VMPricing.toggleVirtualMachineDeprecatedStatus(VM_TYPE_ID);
        (, , bool deprecated) = c3VMPricing.virtualMachineTypes(VM_TYPE_ID);
        assertTrue(deprecated, "Virtual machine type should be deprecated");

        c3VMPricing.toggleVirtualMachineDeprecatedStatus(VM_TYPE_ID);
        (, , deprecated) = c3VMPricing.virtualMachineTypes(VM_TYPE_ID);
        assertFalse(deprecated, "Virtual machine type should not be deprecated");
    }

    function testUpdateVirtualMachineModelName() public {
        string memory newName = "Advanced";
        c3VMPricing.updateVirtualMachineModelName(VM_TYPE_ID, newName);

        (string memory modelName, , ) = c3VMPricing.virtualMachineTypes(VM_TYPE_ID);
        assertEq(modelName, newName, "Model name should be updated");
    }

    function testUpdateVirtualMachinePricePerHour() public {
        uint256 newPrice = 0.2 ether;
        c3VMPricing.updateVirtualMachinePricePerHour(VM_TYPE_ID, newPrice);

        (, uint256 pricePerHour, ) = c3VMPricing.virtualMachineTypes(VM_TYPE_ID);
        assertEq(pricePerHour, newPrice, "Price per hour should be updated");
    }
}

contract C3U is ERC20 {
    constructor() ERC20("C3U", "C3U") {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}