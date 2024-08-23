// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import './C3VirtualMachinePricing.sol';

/// @title IERC20 Interface
/// @notice Interface for ERC20 token operations
interface IERC20 {
    function transferFrom(address _from, address _to, uint256 _value) external returns (bool success);
    function transfer(address _to, uint256 _value) external returns (bool success);
    function balanceOf(address _owner) external view returns (uint256 balance);
}

/// @title C3VirtualMachine
/// @notice This contract manages the creation, pricing, and lifecycle of virtual machines, utilizing ERC20 tokens for payment.
/// @dev Implements functions for creating, pausing, resuming, and stopping virtual machines, as well as token deposits and withdrawals.
contract C3VirtualMachine {
    /// @notice Enum representing the possible states of a virtual machine
    enum VMStatus { Running, Paused, Stopped }

    /// @notice Struct representing a virtual machine
    /// @dev Stores all relevant information about a virtual machine
    struct VirtualMachine {
        address vmOwner;        // Owner of the virtual machine
        uint256 vmType;         // Type of the virtual machine
        uint256 startTime;      // Timestamp when the VM was last started or resumed
        uint256 totalHoursToRun; // Total hours the VM is supposed to run
        uint256 pricePerHour;   // Price per hour for running the VM
        uint256 consumedHours;  // Total hours consumed so far
        VMStatus status;        // Current status of the VM
        uint256 lastPausedTime; // Timestamp when the VM was last paused
    }

    /// @notice Address of the ERC20 token used for payments
    address public tokenAddress;

    /// @notice Address of the VirtualMachinePricing contract
    address public vmPricing;

    /// @notice Counter for generating unique VM IDs
    uint256 private nextId;

    /// @notice Mapping of VM IDs to VirtualMachine structs
    mapping(uint256 => VirtualMachine) public virtualMachines;

    /// @notice Mapping of owner addresses to their VM IDs
    mapping(address => uint256[]) private ownerToVms;

    /// @notice Mapping of user addresses to their token credit balances
    mapping(address => uint256) public userCredits;

    /// @notice Emitted when a new virtual machine is created
    /// @param vmId The ID of the newly created VM
    /// @param vmOwner The address of the VM owner
    event VirtualMachineCreated(uint256 vmId, address indexed vmOwner);

    /// @notice Emitted when a virtual machine is paused
    /// @param vmId The ID of the paused VM
    event VirtualMachinePaused(uint256 vmId);

    /// @notice Emitted when a virtual machine is resumed
    /// @param vmId The ID of the resumed VM
    event VirtualMachineResumed(uint256 vmId);

    /// @notice Emitted when a virtual machine is stopped
    /// @param vmId The ID of the stopped VM
    /// @param refundedCredits The amount of credits refunded to the owner
    event VirtualMachineStopped(uint256 vmId, uint256 refundedCredits);

    /// @notice Emitted when tokens are deposited
    /// @param user The address of the user who deposited tokens
    /// @param amount The amount of tokens deposited
    event TokensDeposited(address indexed user, uint256 amount);

    /// @notice Emitted when tokens are withdrawn
    /// @param user The address of the user who withdrew tokens
    /// @param amount The amount of tokens withdrawn
    event TokensWithdrawn(address indexed user, uint256 amount);

    /// @notice Constructor to initialize the contract
    /// @param _tokenAddress The address of the ERC20 token contract
    /// @param _vmPricing The address of the VirtualMachinePricing contract
    constructor(address _tokenAddress, address _vmPricing) {
        nextId = 0;
        tokenAddress = _tokenAddress;
        vmPricing = _vmPricing;
    }

    /// @notice Modifier to restrict function access to VM owner
    /// @param vmId The ID of the virtual machine
    modifier onlyVMOwner(uint256 vmId) {
        require(virtualMachines[vmId].vmOwner == msg.sender, "Not the VM owner");
        _;
    }

    /// @notice Creates a new virtual machine
    /// @param vmType The type of the virtual machine to create
    /// @param totalHoursToRun The total hours the virtual machine is supposed to run
    /// @return The ID of the newly created virtual machine
    function createVirtualMachine(uint256 vmType, uint256 totalHoursToRun) public returns (uint256) {
        require(totalHoursToRun > 0, "Total hours to run must be greater than 0");

        C3VirtualMachinePricing pricingContract = C3VirtualMachinePricing(vmPricing);
        require(pricingContract.idExists(vmType), "Virtual machine type does not exist");

        (, uint256 _pricePerHour, bool _deprecated) = pricingContract.virtualMachineTypes(vmType);
        require(!_deprecated, "Virtual machine type is deprecated");

        uint256 creditsToConsume = _pricePerHour * totalHoursToRun;
        address sender = msg.sender;
        require(userCredits[sender] >= creditsToConsume, "Insufficient balance to start virtual machine");

        nextId++;

        virtualMachines[nextId] = VirtualMachine({
            vmOwner: sender,
            vmType: vmType,
            startTime: block.timestamp,
            totalHoursToRun: totalHoursToRun,
            pricePerHour: _pricePerHour,
            consumedHours: 0,
            status: VMStatus.Running,
            lastPausedTime: 0
        });

        userCredits[sender] -= creditsToConsume;
        ownerToVms[sender].push(nextId);

        emit VirtualMachineCreated(nextId, sender);

        return nextId;
    }

    /// @notice Pauses a running virtual machine
    /// @param vmId The ID of the virtual machine to pause
    function pauseVirtualMachine(uint256 vmId) external onlyVMOwner(vmId) {
        VirtualMachine storage vm = virtualMachines[vmId];
        require(vm.status == VMStatus.Running, "VM is not running");
        
        vm.consumedHours += (block.timestamp - vm.startTime) / 1 hours;
        vm.lastPausedTime = block.timestamp;
        vm.status = VMStatus.Paused;

        emit VirtualMachinePaused(vmId);
    }

    /// @notice Resumes a paused virtual machine
    /// @param vmId The ID of the virtual machine to resume
    function resumeVirtualMachine(uint256 vmId) external onlyVMOwner(vmId) {
        VirtualMachine storage vm = virtualMachines[vmId];
        require(vm.status == VMStatus.Paused, "VM is not paused");

        vm.startTime = block.timestamp;
        vm.status = VMStatus.Running;

        emit VirtualMachineResumed(vmId);
    }

    /// @notice Stops a virtual machine and refunds unused credits
    /// @param vmId The ID of the virtual machine to stop
    function stopVirtualMachine(uint256 vmId) external onlyVMOwner(vmId) {
        VirtualMachine storage vm = virtualMachines[vmId];
        require(vm.status != VMStatus.Stopped, "VM is already stopped");

        uint256 totalConsumedHours = vm.consumedHours;
        if (vm.status == VMStatus.Running) {
            totalConsumedHours += (block.timestamp - vm.startTime) / 1 hours;
        }

        uint256 refundCredits = (vm.totalHoursToRun - totalConsumedHours) * vm.pricePerHour;
        userCredits[msg.sender] += refundCredits;

        vm.status = VMStatus.Stopped;

        emit VirtualMachineStopped(vmId, refundCredits);
    }

    /// @notice Retrieves the list of virtual machine IDs owned by the caller
    /// @return An array of virtual machine IDs
    function getMyVirtualMachines() external view returns (uint256[] memory) {
        return ownerToVms[msg.sender];
    }

    /// @notice Deposits ERC20 tokens to the user's balance
    /// @param amount The amount of tokens to deposit
    function depositTokens(uint256 amount) external {
        IERC20 token = IERC20(tokenAddress);
        require(token.transferFrom(msg.sender, address(this), amount), "Token transfer failed");

        userCredits[msg.sender] += amount;
        emit TokensDeposited(msg.sender, amount);
    }

    /// @notice Withdraws ERC20 tokens from the user's balance
    /// @param amount The amount of tokens to withdraw
    function withdrawTokens(uint256 amount) external {
        require(userCredits[msg.sender] >= amount, "Insufficient balance to withdraw");
        IERC20 token = IERC20(tokenAddress);
        require(token.transfer(msg.sender, amount), "Token transfer failed");

        userCredits[msg.sender] -= amount;
        emit TokensWithdrawn(msg.sender, amount);
    }

    /// @notice Gets the current status of a virtual machine
    /// @param vmId The ID of the virtual machine
    /// @return The current status of the virtual machine
    function getVMStatus(uint256 vmId) external view returns (VMStatus) {
        return virtualMachines[vmId].status;
    }

    /// @notice Calculates the remaining hours for a virtual machine
    /// @param vmId The ID of the virtual machine
    /// @return The number of hours remaining for the virtual machine
    function getRemainingHours(uint256 vmId) external view returns (uint256) {
        VirtualMachine storage vm = virtualMachines[vmId];
        if (vm.status == VMStatus.Stopped) {
            return 0;
        }

        uint256 totalConsumedHours = vm.consumedHours;
        if (vm.status == VMStatus.Running) {
            totalConsumedHours += (block.timestamp - vm.startTime) / 1 hours;
        }

        if (totalConsumedHours >= vm.totalHoursToRun) {
            return 0;
        }

        return vm.totalHoursToRun - totalConsumedHours;
    }
}