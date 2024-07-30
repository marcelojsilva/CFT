// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import './C3VirtualMachinePricing.sol';

interface IERC20 {
    function transferFrom(address _from, address _to, uint256 _value) external returns (bool success);
    function transfer(address _to, uint256 _value) external returns (bool success);
    function balanceOf(address _owner) external view returns (uint256 balance);
}

/**
 * @title C3VirtualMachine
 * @dev This contract manages the creation and pricing of virtual machines, utilizing ERC20 tokens for payment.
 */
contract C3VirtualMachine {
    struct VirtualMachine {
        address vmOwner; // Owner of the virtual machine
        uint256 vmType; // Type of the virtual machine
        uint256 startTime; // Timestamp when the virtual machine was started
        uint256 totalHoursToRun; // Total hours the virtual machine is supposed to run
        uint256 pricePerHour; // Price per hour of the virtual machine
    }

    address public tokenAddress;
    address public vmPricing;
    uint256 private nextId;

    mapping(uint256 => VirtualMachine) public virtualMachines;
    mapping(address => uint256[]) private ownerToVms; // Mapping from owner to their VMs
    mapping(address => uint256) public userCredits;

    /// @notice Emitted when a virtual machine is created
    /// @param vmId The unique ID of the virtual machine
    /// @param vmOwner The owner of the virtual machine
    event VirtualMachineCreated(uint256 vmId, address indexed vmOwner);

    /// @notice Emitted when tokens are deposited
    /// @param user The user who deposited the tokens
    /// @param amount The amount of tokens deposited
    event TokensDeposited(address indexed user, uint256 amount);

    /// @notice Emitted when tokens are withdrawn
    /// @param user The user who withdrew the tokens
    /// @param amount The amount of tokens withdrawn
    event TokensWithdrawn(address indexed user, uint256 amount);

    /**
     * @dev Sets the ERC20 token address used for payments.
     * @param _tokenAddress The address of the ERC20 token contract.
     * @param _vmPricing The address of the C3VirtualMachinePricing contract.
     */
    constructor(address _tokenAddress, address _vmPricing) {
        nextId = 0;
        tokenAddress = _tokenAddress;
        vmPricing = _vmPricing;
    }

    /**
     * @notice Creates a new virtual machine
     * @param vmType The type of the virtual machine to create
     * @param totalHoursToRun The total hours the virtual machine is supposed to run
     * @return vmId The ID of the created virtual machine
    */
    function createVirtualMachine(uint256 vmType, uint256 totalHoursToRun) public returns (uint256) {
        require(totalHoursToRun > 0, "Total hours to run must be greater than 0");

        C3VirtualMachinePricing pricingContract = C3VirtualMachinePricing(vmPricing);
        require(pricingContract.idExists(vmType), "Virtual machine type does not exist");

        // Access only the necessary fields individually
        (, uint256 _pricePerHour, bool _deprecated) = pricingContract.virtualMachineTypes(vmType);
        require(!_deprecated, "Virtual machine type is deprecated");

        uint256 creditsToConsume = _pricePerHour * totalHoursToRun;
        address sender = msg.sender;
        require(userCredits[sender] >= creditsToConsume, "Insufficient balance to start virtual machine");

        nextId += 1;

        virtualMachines[nextId] = VirtualMachine({
            vmOwner: sender,
            vmType: vmType,
            startTime: block.timestamp,
            totalHoursToRun: totalHoursToRun,
            pricePerHour: _pricePerHour
        });

        userCredits[sender] -= creditsToConsume;
        ownerToVms[sender].push(nextId); // Update owner to VMs mapping

        emit VirtualMachineCreated(nextId, sender);

        return nextId;
    }

    /**
     * @notice Retrieves the virtual machines owned by the caller
     * @return myVirtualMachines An array of virtual machine IDs owned by the caller
     */
    function getMyVirtualMachines() external view returns (uint256[] memory) {
        return ownerToVms[msg.sender];
    }

    /**
     * @notice Deposits ERC20 tokens to the user's balance
     * @param amount The amount of tokens to deposit
     */
    function depositTokens(uint256 amount) external {
        IERC20 token = IERC20(tokenAddress);
        require(token.transferFrom(msg.sender, address(this), amount), "Token transfer failed");

        userCredits[msg.sender] += amount;
        emit TokensDeposited(msg.sender, amount); // Emit event for deposit
    }

    /**
     * @notice Withdraws ERC20 tokens from the user's balance
     * @param amount The amount of tokens to withdraw
     */
    function withdrawTokens(uint256 amount) external {
        require(userCredits[msg.sender] >= amount, "Insufficient balance to withdraw");
        IERC20 token = IERC20(tokenAddress);
        require(token.transfer(msg.sender, amount), "Token transfer failed");

        userCredits[msg.sender] -= amount;
        emit TokensWithdrawn(msg.sender, amount); // Emit event for withdrawal
    }
}
