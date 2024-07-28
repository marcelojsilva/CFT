// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import '@openzeppelin/contracts/utils/Counters.sol';
import './C3VirtualMachinePricing.sol';

interface ERC20 {
    function transferFrom(address _from, address _to, uint256 _value) external returns (bool success);
    function transfer(address _to, uint256 _value) external returns (bool success);
    function balanceOf(address _owner) external view returns (uint256 balance);
}

/**
 * @title C3VirtualMachine
 * @dev This contract manages the creation and pricing of virtual machines, utilizing ERC20 tokens for payment.
 */
contract C3VirtualMachine is C3VirtualMachinePricing {
    using Counters for Counters.Counter;

    struct VirtualMachine {
        address vmOwner; // Owner of the virtual machine
        uint256 vmType; // Type of the virtual machine
        uint256 startTime; // Timestamp when the virtual machine was started
        uint256 totalHoursToRun; // Total hours the virtual machine is supposed to run
        uint256 pricePerHour; // Price per hour of the virtual machine
    }

    Counters.Counter private nextId;
    address public tokenAddress;
    mapping(uint256 => VirtualMachine) public virtualMachines;
    mapping(address => uint256) public userCredits;

    /// @notice Emitted when a new virtual machine is created
    /// @param vmId The ID of the created virtual machine
    /// @param vmOwner The owner of the created virtual machine
    event VirtualMachineCreated(uint256 vmId, address indexed vmOwner);

    /**
     * @dev Sets the ERC20 token address used for payments.
     * @param _tokenAddress The address of the ERC20 token contract.
     */
    constructor(address _tokenAddress) {
        tokenAddress = _tokenAddress;
    }

    /**
     * @notice Creates a new virtual machine
     * @param vmType The type of the virtual machine to create
     * @param totalHoursToRun The total hours the virtual machine is supposed to run
     * @return vmId The ID of the created virtual machine
     */
    function createVirtualMachine(uint256 vmType, uint256 totalHoursToRun) public returns (uint256) {
        require(exists(vmType), "Virtual machine type does not exist");
        require(!virtualMachineTypes[vmType].deprecated, "Virtual machine type is deprecated");
        require(totalHoursToRun > 0, "Total hours to run must be greater than 0");

        uint256 pricePerHour = virtualMachineTypes[vmType].pricePerHour;
        uint256 creditsToConsume = pricePerHour * totalHoursToRun;
        require(userCredits[msg.sender] >= creditsToConsume, "Insufficient balance to start virtual machine");

        nextId.increment();
        uint256 vmId = nextId.current();
        virtualMachines[vmId] = VirtualMachine({
            vmOwner: msg.sender,
            vmType: vmType,
            startTime: block.timestamp,
            totalHoursToRun: totalHoursToRun,
            pricePerHour: pricePerHour
        });

        userCredits[msg.sender] -= creditsToConsume;

        emit VirtualMachineCreated(vmId, msg.sender);

        return vmId;
    }

    /**
     * @notice Retrieves the virtual machines owned by the caller
     * @return myVirtualMachines An array of virtual machine IDs owned by the caller
     */
    function getMyVirtualMachines() external view returns (uint256[] memory) {
        uint256 count = 0;
        for (uint256 i = 1; i <= nextId.current(); i++) {
            if (virtualMachines[i].vmOwner == msg.sender) {
                count++;
            }
        }

        uint256[] memory myVirtualMachines = new uint256[](count);
        count = 0;
        for (uint256 i = 1; i <= nextId.current(); i++) {
            if (virtualMachines[i].vmOwner == msg.sender) {
                myVirtualMachines[count] = i;
                count++;
            }
        }

        return myVirtualMachines;
    }

    /**
     * @notice Deposits ERC20 tokens to the user's balance
     * @param amount The amount of tokens to deposit
     */
    function depositTokens(uint256 amount) external {
        ERC20 token = ERC20(tokenAddress);
        require(token.transferFrom(msg.sender, address(this), amount), "Token transfer failed");

        userCredits[msg.sender] += amount;
    }

    /**
     * @notice Withdraws ERC20 tokens from the user's balance
     * @param amount The amount of tokens to withdraw
     */
    function withdrawTokens(uint256 amount) external {
        require(userCredits[msg.sender] >= amount, "Insufficient balance to withdraw");
        ERC20 token = ERC20(tokenAddress);
        require(token.transfer(msg.sender, amount), "Token transfer failed");

        userCredits[msg.sender] -= amount;
    }

    /**
     * @notice Retrieves the balance of the caller's credits
     * @return The balance of the caller's credits
     */
    function myCreditsBalance() external view returns (uint256) {
        return userCredits[msg.sender];
    }
}
