// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../src/C3VirtualMachine.sol";
import "../src/C3ResourcePricing.sol";
import "../src/C3U.sol";

contract C3VirtualMachineTest is Test {
    C3ResourcePricing private c3ResourcePricing;
    C3VirtualMachine private c3VM;
    C3U private c3uToken;
    address private owner;
    address private user;
    uint256 private constant VM_ID = 1;
    uint256 private constant RESOURCE_ID = 1;
    uint256 private constant PRICE_PER_HOUR = 0.1 ether; // Realistic price
    uint256 private constant INITIAL_BALANCE = 1000 ether;

    event VirtualMachineCreated(uint256 indexed vmId, address indexed vmOwner, uint256 keyPairId);
    event TokensDeposited(address indexed user, uint256 amount);
    event TokensWithdrawn(address indexed user, uint256 amount);

    function setUp() public {
        owner = address(this);
        user = address(0x1234);

        // Deploy pricing contract
        c3ResourcePricing = new C3ResourcePricing();

        // Create a virtual machine type
        c3ResourcePricing.createResource(
            RESOURCE_ID, "Basic", PRICE_PER_HOUR, C3ResourcePricing.ResourceType.VirtualMachine
        );

        // Deploy the utility token contract (C3U)
        c3uToken = new C3U();

        // Mint tokens to the owner address
        c3uToken.mint(owner, INITIAL_BALANCE + 1000 ether);

        // Deploy the virtual machine contract
        c3VM = new C3VirtualMachine(address(c3uToken), address(c3ResourcePricing), owner);

        c3uToken.approve(address(c3VM), INITIAL_BALANCE);

        // Deposit tokens to the VM contract
        c3VM.depositTokens(INITIAL_BALANCE);
    }

    function testUserInitialCreditAfterDeposit() public view {
        uint256 userCredits = c3VM.userCredits(owner);

        assertEq(userCredits, INITIAL_BALANCE, "User credits should match initial deposit balance");
    }

    function testPriceExist() public view {
        bool pricingExists = c3ResourcePricing.idExists(RESOURCE_ID);
        assertTrue(pricingExists, "Pricing should exist");

        // Test non-existent ID
        bool nonExistentPricing = c3ResourcePricing.idExists(999);
        assertFalse(nonExistentPricing, "Pricing should not exist for non-existent ID");
    }

    function testCreateVirtualMachineWithSufficientCredits() public {
        uint256 hoursToRun = 5;
        uint256 expectedCost = PRICE_PER_HOUR * hoursToRun;
        uint256 keyPairId = 1;

        vm.expectEmit(true, true, false, false);
        emit VirtualMachineCreated(VM_ID, owner, keyPairId);

        uint256 newVmId = c3VM.createVirtualMachine(RESOURCE_ID, hoursToRun, keyPairId);
        assertEq(newVmId, VM_ID);

        uint256 userCreditsAfter = c3VM.userCredits(owner);
        assertEq(userCreditsAfter, INITIAL_BALANCE - expectedCost, "User credits should decrease by the expected cost");
    }

    function testCreateVirtualMachineWithMaxCredits() public {
        uint256 initialBalance = c3uToken.balanceOf(address(this));
        uint256 maxHours = initialBalance / PRICE_PER_HOUR; // Max hours user can run the VM
        uint256 keyPairId = 2;

        vm.expectEmit(true, true, false, false);
        emit VirtualMachineCreated(VM_ID, owner, keyPairId);

        uint256 newVmId = c3VM.createVirtualMachine(RESOURCE_ID, maxHours, keyPairId);
        assertEq(newVmId, VM_ID, "Incorrect VM ID");

        uint256 userCreditsAfter = c3VM.userCredits(owner);
        assertEq(userCreditsAfter, 0, "User credits should be zero after VM creation with maximum allowed hours");
    }

    // function testDepositTokens() public {
    //     uint256 depositAmount = 500 ether;

    //     vm.expectEmit(true, true, false, false);
    //     emit TokensDeposited(owner, depositAmount);

    //     c3uToken.approve(address(c3VM), depositAmount);
    //     c3VM.depositTokens(depositAmount);

    //     uint256 newCredits = c3VM.userCredits(owner);
    //     assertEq(newCredits, depositAmount, "User credits should increase by deposit amount");
    // }

    // function testWithdrawExactBalance() public {
    //     uint256 initialBalance = c3uToken.balanceOf(address(this));

    //     vm.expectEmit(true, true, false, false);
    //     emit TokensWithdrawn(owner, initialBalance);

    //     c3VM.withdrawTokens(initialBalance); // Withdraw the exact balance

    //     uint256 newCredits = c3VM.userCredits(owner);
    //     assertEq(newCredits, 0, "User credits should be zero after withdrawing the exact balance");
    // }

    // function testCannotWithdrawExcessTokens() public {
    //     uint256 initialBalance = c3uToken.balanceOf(address(this));
    //     uint256 withdrawAmount = initialBalance + 1 ether;

    //     vm.expectRevert("Insufficient balance to withdraw");
    //     c3VM.withdrawTokens(withdrawAmount);
    // }

    // function testCannotCreateVirtualMachineWithoutSufficientCredits() public {
    //     uint256 initialBalance = c3uToken.balanceOf(address(this));
    //     uint256 excessiveHours = (initialBalance / PRICE_PER_HOUR) + 1;

    //     vm.expectRevert("Insufficient balance to start virtual machine");
    //     c3VM.createVirtualMachine(RESOURCE_ID, excessiveHours);
    // }

    // function testtoggleDeprecatedStatus() public {
    //     // Deprecate VM type
    //     c3ResourcePricing.toggleDeprecatedStatus(RESOURCE_ID);
    //     (,, bool deprecated,) = c3ResourcePricing.getResource(RESOURCE_ID);
    //     assertTrue(deprecated, "Virtual machine type should be deprecated");

    //     // Re-enable VM type
    //     c3ResourcePricing.toggleDeprecatedStatus(RESOURCE_ID);
    //     (,, deprecated,) = c3ResourcePricing.getResource(RESOURCE_ID);
    //     assertFalse(deprecated, "Virtual machine type should not be deprecated");
    // }

    // function testFailingTokenDepositWithoutApproval() public {
    //     uint256 depositAmount = 500 ether;

    //     // Do not approve tokens
    //     vm.expectRevert("ERC20: transfer amount exceeds allowance");
    //     c3VM.depositTokens(depositAmount); // This should fail because there is no approval
    // }

    // function testupdateName() public {
    //     string memory newName = "Advanced";
    //     c3ResourcePricing.updateName(RESOURCE_ID, newName);

    //     (string memory modelName,,,) = c3ResourcePricing.getResource(RESOURCE_ID);
    //     assertEq(modelName, newName, "Model name should be updated");
    // }

    // function testupdatePricePerHour() public {
    //     uint256 newPrice = 0.2 ether;
    //     c3ResourcePricing.updatePricePerHour(RESOURCE_ID, newPrice);

    //     (, uint256 pricePerHour,,) = c3ResourcePricing.getResource(RESOURCE_ID);
    //     assertEq(pricePerHour, newPrice, "Price per hour should be updated");
    // }

    // // Additional boundary test: Ensure 0-hour creation fails
    // function testCannotCreateZeroHourVM() public {
    //     vm.expectRevert("Hours to run must be greater than 0");
    //     c3VM.createVirtualMachine(RESOURCE_ID, 0);
    // }

    // // Additional test: Only owner can deprecate VM types
    // function testOnlyOwnerCanDeprecateVM() public {
    //     vm.prank(user); // Simulate a call from a non-owner
    //     vm.expectRevert("Ownable: caller is not the owner");
    //     c3ResourcePricing.toggleDeprecatedStatus(RESOURCE_ID);
    // }

    // // Gas profiling test for creating virtual machines
    // function testGasUsageForCreatingVirtualMachine() public {
    //     uint256 hoursToRun = 5;

    //     // Measure gas consumption
    //     uint256 gasBefore = gasleft();
    //     c3VM.createVirtualMachine(RESOURCE_ID, hoursToRun);
    //     uint256 gasAfter = gasleft();

    //     emit log_named_uint("Gas used for createVirtualMachine", gasBefore - gasAfter);
    // }
}
