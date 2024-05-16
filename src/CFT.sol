// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

interface ERC20 {
    function transferFrom(address _from, address _to, uint256 _value) external returns (bool success);
    function transfer(address _to, uint256 _value) external returns (bool success);
    function balanceOf(address _owner) external view returns (uint256 balance);
}

contract CFT {

    // Struct to represent a virtual machine
    struct VirtualMachine {
        address owner; // Owner of the virtual machine
        address currentOperator; // Current operator of the virtual machine
        bool isRunning; // Indicates whether the virtual machine is running
        uint256 startTime; // Timestamp when the virtual machine was started
        uint256 totalMinutesConsumed; // Total minutes consumed for running the virtual machine
    }

    // Mapping from VM ID to VirtualMachine struct
    mapping(uint256 => VirtualMachine) public virtualMachines;

    // Counter for generating sequential IDs
    uint256 public nextId = 1;

    // Address of the ERC20 token contract
    address public tokenAddress;

    // Mapping from user address to their deposited tokens (representing minute credits)
    mapping(address => uint256) public userMinuteCredits;

    // Event emitted when a virtual machine is created
    event VirtualMachineCreated(uint256 vmId, address operator);

    // Event emitted when a virtual machine is started
    event VirtualMachineStarted(uint256 vmId, address operator);

    // Event emitted when a virtual machine is stopped
    event VirtualMachineStopped(uint256 vmId, address operator);

    // Modifier to ensure that only the owner of the virtual machine or the current operator can perform certain actions

    modifier onlyOwnerOrOperator(uint256 vmId) {
        require(
            msg.sender == virtualMachines[vmId].owner ||
            msg.sender == virtualMachines[vmId].currentOperator,
            "Only owner or operator can perform this action"
        );

        _;
    }

    // Constructor to set the address of the ERC20 token contract
    constructor(address _tokenAddress) {
        tokenAddress = _tokenAddress;
    }

    // Function to create a virtual machine
    function createVirtualMachine() external returns (uint256) {
        uint256 vmId = nextId;
        virtualMachines[vmId].owner = msg.sender;

        // Increment the ID counter for the next virtual machine

        nextId++;

        // Emit event
        emit VirtualMachineCreated(vmId, msg.sender);
        return vmId;
    }

    // Function to start a virtual machine
    function startVirtualMachine(uint256 vmId) external onlyOwnerOrOperator(vmId) {
        require(!virtualMachines[vmId].isRunning, "Virtual machine is already running");

        // Ensure user has enough minute credits convert to 18 decimals
        require(virtualMachines[vmId].totalMinutesConsumed * 10 ** 18 < userMinuteCredits[msg.sender], "Insufficient minute credits");

        // Ensure user has enough minute credits
        require(userMinuteCredits[msg.sender] > 0, "Insufficient minute credits");

        // Mark the virtual machine as running
        virtualMachines[vmId].isRunning = true;
        virtualMachines[vmId].currentOperator = msg.sender;
        virtualMachines[vmId].startTime = block.timestamp;

        // Emit event
        emit VirtualMachineStarted(vmId, msg.sender);
    }


    // Function to stop a virtual machine
    function stopVirtualMachine(uint256 vmId) external onlyOwnerOrOperator(vmId) {
        require(virtualMachines[vmId].isRunning, "Virtual machine is not running");

        // Calculate total minutes consumed based on time since last start
        uint256 secondsDifference  = block.timestamp - virtualMachines[vmId].startTime;
        uint256 secondsWithDecimals = secondsDifference * 10 ** 18;
        uint256 minutesWithDecimals = secondsWithDecimals / (60 * 10 ** 18);
        virtualMachines[vmId].totalMinutesConsumed += minutesWithDecimals;

        // Mark the virtual machine as stopped
        virtualMachines[vmId].isRunning = false;

        // Emit event
        emit VirtualMachineStopped(vmId, msg.sender);

    }

    // Function to deposit tokens and convert them into minute credits
    function depositTokens(uint256 amount) external {
        //require owner only
        // Transfer tokens from sender to contract
        ERC20 token = ERC20(tokenAddress);
        require(token.transferFrom(msg.sender, address(this), amount), "Token transfer failed");

        userMinuteCredits[msg.sender] += amount;
    }

    // View function to get total minutes consumed by a virtual machine
    function getTotalMinutesConsumed(uint256 vmId) external view returns (uint256) {
        // Calculate total minutes consumed based on whether the virtual machine is running or not
        if (virtualMachines[vmId].isRunning) {
            // Calculate minutes consumed until current time
            uint256 uptime = block.timestamp - virtualMachines[vmId].startTime;
            uint256 minute = (virtualMachines[vmId].totalMinutesConsumed + uptime / 60) * 10 ** 18; // Assuming 1 minute per block
            return minute;
        } else {
            // Return total minutes consumed if the virtual machine is stopped
            return virtualMachines[vmId].totalMinutesConsumed * 10 ** 18;
        }
    }
}
