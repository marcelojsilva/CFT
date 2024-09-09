// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./C3ResourcePricing.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title C3VirtualMachine
/// @notice This contract manages the lifecycle of virtual machines, including creation, pausing, resuming, and stopping.
/// @dev Implements a token locking mechanism to prevent withdrawal of tokens in use by active VMs.
contract C3VirtualMachine {
    /// @notice Enum representing the possible states of a virtual machine
    enum VMStatus {
        Running,
        Paused,
        Stopped
    }

    /// @notice Struct representing a virtual machine
    /// @dev Stores all relevant information about a virtual machine, including locked tokens
    struct VirtualMachine {
        address vmOwner; // Owner of the virtual machine
        uint256 resourceId; // Resource id of the virtual machine
        uint256 startTime; // Timestamp when the VM was last started or resumed
        uint256 totalHoursToRun; // Total hours the VM is supposed to run
        uint256 pricePerHour; // Price per hour for running the VM
        uint256 consumedHours; // Total hours consumed so far
        VMStatus status; // Current status of the VM
        uint256 lastPausedTime; // Timestamp when the VM was last paused
        uint256 lockedTokens; // Amount of tokens locked for this VM
    }

    /// @notice Address of the ERC20 token used for payments
    address public immutable tokenAddress;

    /// @notice Address of the ResourcePricing contract
    address public immutable resourcePricing;

    /// @notice Address of the manager with special privileges
    address public immutable manager;

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
    event VirtualMachineCreated(uint256 indexed vmId, address indexed vmOwner, uint256 keyPairId);

    /// @notice Emitted when a virtual machine is paused
    /// @param vmId The ID of the paused VM
    event VirtualMachinePaused(uint256 indexed vmId);

    /// @notice Emitted when a virtual machine is resumed
    /// @param vmId The ID of the resumed VM
    event VirtualMachineResumed(uint256 indexed vmId);

    /// @notice Emitted when a virtual machine is stopped
    /// @param vmId The ID of the stopped VM
    /// @param refundedCredits The amount of credits refunded to the owner
    event VirtualMachineStopped(uint256 indexed vmId, uint256 refundedCredits);

    /// @notice Emitted when tokens are deposited
    /// @param user The address of the user who deposited tokens
    /// @param amount The amount of tokens deposited
    event TokensDeposited(address indexed user, uint256 amount);

    /// @notice Emitted when tokens are withdrawn
    /// @param user The address of the user who withdrew tokens
    /// @param amount The amount of tokens withdrawn
    event TokensWithdrawn(address indexed user, uint256 amount);

    /// @notice Emitted when a manager stops a VM
    /// @param vmId The ID of the stopped VM
    /// @param vmOwner The address of the VM owner
    event ManagerStopped(uint256 indexed vmId, address indexed vmOwner);

    /// @notice Modifier to restrict function access to VM owner
    /// @param vmId The ID of the virtual machine
    modifier onlyVMOwner(uint256 vmId) {
        require(virtualMachines[vmId].vmOwner == msg.sender, "Not the VM owner");
        _;
    }

    /// @notice Modifier to restrict function access to the manager
    modifier onlyManager() {
        require(msg.sender == manager, "Not the manager");
        _;
    }

    /// @notice Constructor to initialize the contract
    /// @param _tokenAddress The address of the ERC20 token contract
    /// @param _resourcePricing The address of the ResourcePricing contract
    /// @param _manager The address of the manager
    constructor(address _tokenAddress, address _resourcePricing, address _manager) {
        require(_tokenAddress != address(0), "Invalid token address");
        require(_resourcePricing != address(0), "Invalid resource pricing address");
        require(_manager != address(0), "Invalid manager address");

        tokenAddress = _tokenAddress;
        resourcePricing = _resourcePricing;
        manager = _manager;
    }

    /// @notice Creates a new virtual machine
    /// @param resourceId The id of the virtual machine flavour to create
    /// @param totalHoursToRun The total hours the virtual machine is supposed to run
    /// @param keyPairId The ID of the key pair to associate with the virtual machine
    /// @return The ID of the newly created virtual machine
    /// @dev Locks the required tokens for the duration of the VM's runtime
    function createVirtualMachine(uint256 resourceId, uint256 totalHoursToRun, uint256 keyPairId)
        public
        returns (uint256)
    {
        require(totalHoursToRun > 0, "Total hours to run must be greater than 0");

        C3ResourcePricing pricingContract = C3ResourcePricing(resourcePricing);
        require(pricingContract.idExists(resourceId), "Virtual machine resource id does not exist");

        (, uint256 _pricePerHour, bool _deprecated, C3ResourcePricing.ResourceType _resourceType) =
            pricingContract.getResource(resourceId);
        require(!_deprecated, "Virtual machine resource is deprecated");
        require(_resourceType == C3ResourcePricing.ResourceType.VirtualMachine, "Resource is not a virtual machine");

        uint256 creditsToConsume = _pricePerHour * totalHoursToRun;
        address sender = msg.sender;
        require(userCredits[sender] >= creditsToConsume, "Insufficient balance to start virtual machine");

        unchecked {
            nextId++;
        }

        virtualMachines[nextId] = VirtualMachine({
            vmOwner: sender,
            resourceId: resourceId,
            startTime: block.timestamp,
            totalHoursToRun: totalHoursToRun,
            pricePerHour: _pricePerHour,
            consumedHours: 0,
            status: VMStatus.Running,
            lastPausedTime: 0,
            lockedTokens: creditsToConsume
        });

        userCredits[sender] -= creditsToConsume;
        ownerToVms[sender].push(nextId);

        emit VirtualMachineCreated(nextId, sender, keyPairId);

        return nextId;
    }

    /// @notice Pauses a running virtual machine
    /// @param vmId The ID of the virtual machine to pause
    /// @dev Calculates consumed credits and unlocks them
    function pauseVirtualMachine(uint256 vmId) external onlyVMOwner(vmId) {
        VirtualMachine storage vm = virtualMachines[vmId];
        require(vm.status == VMStatus.Running, "VM is not running");

        uint256 consumedHours = (block.timestamp - vm.startTime) / 1 hours;
        uint256 consumedCredits = consumedHours * vm.pricePerHour;

        if (consumedCredits > vm.lockedTokens) {
            consumedCredits = vm.lockedTokens;
        }

        vm.consumedHours += consumedHours;
        vm.lockedTokens -= consumedCredits;
        vm.lastPausedTime = block.timestamp;
        vm.status = VMStatus.Paused;

        emit VirtualMachinePaused(vmId);
    }

    /// @notice Resumes a paused virtual machine
    /// @param vmId The ID of the virtual machine to resume
    /// @dev Requires and locks additional credits if needed
    function resumeVirtualMachine(uint256 vmId) external onlyVMOwner(vmId) {
        VirtualMachine storage vm = virtualMachines[vmId];
        require(vm.status == VMStatus.Paused, "VM is not paused");

        uint256 remainingHours = vm.totalHoursToRun - vm.consumedHours;
        uint256 requiredCredits = remainingHours * vm.pricePerHour;

        require(userCredits[msg.sender] >= requiredCredits, "Insufficient credits to resume VM");

        userCredits[msg.sender] -= requiredCredits;
        vm.lockedTokens += requiredCredits;
        vm.startTime = block.timestamp;
        vm.status = VMStatus.Running;

        emit VirtualMachineResumed(vmId);
    }

    /// @notice Stops a virtual machine and refunds unused credits
    /// @param vmId The ID of the virtual machine to stop
    function stopVirtualMachine(uint256 vmId) external onlyVMOwner(vmId) {
        _stopVirtualMachine(vmId);
    }

    /// @notice Allows the manager to stop any virtual machine
    /// @param vmId The ID of the virtual machine to stop
    function managerStopVirtualMachine(uint256 vmId) external onlyManager {
        VirtualMachine storage vm = virtualMachines[vmId];
        require(vm.status != VMStatus.Stopped, "VM is already stopped");

        address vmOwner = vm.vmOwner;
        _stopVirtualMachine(vmId);

        emit ManagerStopped(vmId, vmOwner);
    }

    /// @notice Internal function to stop a virtual machine
    /// @param vmId The ID of the virtual machine to stop
    /// @dev Calculates consumed credits and refunds unused ones
    function _stopVirtualMachine(uint256 vmId) internal {
        VirtualMachine storage vm = virtualMachines[vmId];
        require(vm.status != VMStatus.Stopped, "VM is already stopped");

        uint256 totalConsumedHours = vm.consumedHours;
        if (vm.status == VMStatus.Running) {
            totalConsumedHours += (block.timestamp - vm.startTime) / 1 hours;
        }

        uint256 consumedCredits = totalConsumedHours * vm.pricePerHour;
        if (consumedCredits > vm.lockedTokens) {
            consumedCredits = vm.lockedTokens;
        }

        uint256 refundCredits = vm.lockedTokens - consumedCredits;
        userCredits[vm.vmOwner] += refundCredits;
        vm.lockedTokens = 0;
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
        require(amount > 0, "Deposit amount must be greater than 0");
        IERC20 token = IERC20(tokenAddress);
        require(token.transferFrom(msg.sender, address(this), amount), "Token transfer failed");

        userCredits[msg.sender] += amount;
        emit TokensDeposited(msg.sender, amount);
    }

    /// @notice Withdraws ERC20 tokens from the user's balance
    /// @param amount The amount of tokens to withdraw
    function withdrawTokens(uint256 amount) external {
        require(amount > 0, "Withdrawal amount must be greater than 0");
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

    /// @notice Gets the amount of locked tokens for a virtual machine
    /// @param vmId The ID of the virtual machine
    /// @return The amount of locked tokens
    function getLockedTokens(uint256 vmId) external view returns (uint256) {
        return virtualMachines[vmId].lockedTokens;
    }
}
