// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title C3VirtualMachinePricing
/// @notice This contract manages the pricing and details of virtual machine types.
/// @dev Implements functions for creating, updating, and managing virtual machine types and their pricing.
contract C3VirtualMachinePricing {

    /// @notice Structure defining a virtual machine type
    /// @dev Stores all relevant information about a virtual machine type
    struct VirtualMachineType {
        string modelName;     // Name of the virtual machine model
        uint256 pricePerHour; // Price per hour of the virtual machine
        bool deprecated;      // Flag to indicate if the virtual machine model is deprecated
    }

    /// @notice Mapping of VM type IDs to their corresponding VirtualMachineType structs
    mapping(uint256 => VirtualMachineType) public virtualMachineTypes;

    /// @notice Mapping to check if a VM type ID exists
    mapping(uint256 => bool) public idExists;

    /// @notice Address of the contract owner
    address public owner;

    /// @notice Emitted when a new virtual machine type is created
    /// @param id The unique ID of the virtual machine model
    /// @param modelName The name of the virtual machine model
    /// @param pricePerHour The price per hour for the virtual machine model
    event TypeCreated(uint256 indexed id, string modelName, uint256 pricePerHour);

    /// @notice Emitted when a virtual machine model name is updated
    /// @param id The unique ID of the virtual machine model
    /// @param modelName The updated model name
    event ModelNameUpdated(uint256 indexed id, string modelName);

    /// @notice Emitted when the price per hour is updated
    /// @param id The unique ID of the virtual machine model
    /// @param pricePerHour The updated price per hour
    event PricePerHourUpdated(uint256 indexed id, uint256 pricePerHour);

    /// @notice Emitted when the deprecated status is toggled
    /// @param id The unique ID of the virtual machine model
    /// @param deprecated The new deprecated status
    event DeprecatedStatusToggled(uint256 indexed id, bool deprecated);

    /// @notice Emitted when the contract owner is changed
    /// @param previousOwner The address of the previous owner
    /// @param newOwner The address of the new owner
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /// @notice Constructor to set the initial owner of the contract
    constructor() {
        owner = msg.sender;
    }

    /// @notice Modifier to restrict access to the contract owner
    modifier onlyOwner() {
        require(msg.sender == owner, "Not the contract owner");
        _;
    }

    /// @notice Modifier to check if a virtual machine type exists
    /// @param id The ID of the virtual machine type to check
    modifier typeExists(uint256 id) {
        require(idExists[id], "Virtual machine type does not exist");
        _;
    }

    /// @notice Creates a new virtual machine type
    /// @dev Only the contract owner can create new types
    /// @param id The unique ID of the virtual machine model
    /// @param _modelName The name of the virtual machine model
    /// @param _pricePerHour The price per hour for the virtual machine model
    function createVirtualMachineType(uint256 id, string calldata _modelName, uint256 _pricePerHour) external onlyOwner {
        require(bytes(_modelName).length > 0, "Model name cannot be empty");
        require(_pricePerHour > 0, "Price per hour must be greater than 0");
        require(!idExists[id], "ID already exists");

        virtualMachineTypes[id] = VirtualMachineType({
            modelName: _modelName,
            pricePerHour: _pricePerHour,
            deprecated: false
        });

        idExists[id] = true;

        emit TypeCreated(id, _modelName, _pricePerHour);
    }

    /// @notice Updates the model name of a virtual machine type
    /// @dev Only the contract owner can update model names
    /// @param id The ID of the virtual machine type to update
    /// @param _modelName The new model name
    function updateVirtualMachineModelName(uint256 id, string calldata _modelName) external onlyOwner typeExists(id) {
        require(bytes(_modelName).length > 0, "Model name cannot be empty");

        virtualMachineTypes[id].modelName = _modelName;

        emit ModelNameUpdated(id, _modelName);
    }

    /// @notice Updates the price per hour of a virtual machine type
    /// @dev Only the contract owner can update prices
    /// @param id The ID of the virtual machine type to update
    /// @param _pricePerHour The new price per hour
    function updateVirtualMachinePricePerHour(uint256 id, uint256 _pricePerHour) external onlyOwner typeExists(id) {
        require(_pricePerHour > 0, "Price per hour must be greater than 0");

        virtualMachineTypes[id].pricePerHour = _pricePerHour;

        emit PricePerHourUpdated(id, _pricePerHour);
    }

    /// @notice Toggles the deprecated status of a virtual machine type
    /// @dev Only the contract owner can toggle deprecated status
    /// @param id The ID of the virtual machine type to update
    function toggleVirtualMachineDeprecatedStatus(uint256 id) external onlyOwner typeExists(id) {
        virtualMachineTypes[id].deprecated = !virtualMachineTypes[id].deprecated;

        emit DeprecatedStatusToggled(id, virtualMachineTypes[id].deprecated);
    }

    /// @notice Transfers ownership of the contract to a new address
    /// @dev Only the current owner can transfer ownership
    /// @param newOwner The address to transfer ownership to
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "New owner cannot be the zero address");
        address oldOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    /// @notice Retrieves the details of a virtual machine type
    /// @param id The ID of the virtual machine type to retrieve
    /// @return modelName The name of the virtual machine model
    /// @return pricePerHour The price per hour for the virtual machine model
    /// @return deprecated Whether the virtual machine model is deprecated
    function getVirtualMachineType(uint256 id) external view typeExists(id) returns (string memory modelName, uint256 pricePerHour, bool deprecated) {
        VirtualMachineType storage vmType = virtualMachineTypes[id];
        return (vmType.modelName, vmType.pricePerHour, vmType.deprecated);
    }
}