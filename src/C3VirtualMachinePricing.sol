// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title C3VirtualMachinePricing
 * @dev This contract manages the pricing and details of virtual machine types.
 */
contract C3VirtualMachinePricing {

    struct VirtualMachineType {
        string modelName; // Name of the virtual machine model
        uint256 pricePerHour; // Price per hour of the virtual machine
        bool deprecated; // Flag to indicate if the virtual machine model is deprecated
    }

    mapping(uint256 => VirtualMachineType) public virtualMachineTypes;
    mapping(uint256 => bool) public idExists; // Changed to public

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

    modifier typeExists(uint256 id) {
        require(idExists[id], "Virtual machine type does not exist");
        _;
    }

    /**
     * @notice Creates a new virtual machine type
     * @param id The unique ID of the virtual machine model
     * @param _modelName The name of the virtual machine model
     * @param _pricePerHour The price per hour for the virtual machine model
     */
    function createVirtualMachineType(uint256 id, string calldata _modelName, uint256 _pricePerHour) external {
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

    /**
     * @notice Updates the model name of a virtual machine type
     * @param id The ID of the virtual machine type to update
     * @param _modelName The new model name
     */
    function updateVirtualMachineModelName(uint256 id, string calldata _modelName) external typeExists(id) {
        require(bytes(_modelName).length > 0, "Model name cannot be empty");

        virtualMachineTypes[id].modelName = _modelName;

        emit ModelNameUpdated(id, _modelName);
    }

    /**
     * @notice Updates the price per hour of a virtual machine type
     * @param id The ID of the virtual machine type to update
     * @param _pricePerHour The new price per hour
     */
    function updateVirtualMachinePricePerHour(uint256 id, uint256 _pricePerHour) external typeExists(id) {
        require(_pricePerHour > 0, "Price per hour must be greater than 0");

        virtualMachineTypes[id].pricePerHour = _pricePerHour;

        emit PricePerHourUpdated(id, _pricePerHour);
    }

    /**
     * @notice Toggles the deprecated status of a virtual machine type
     * @param id The ID of the virtual machine type to update
     */
    function toggleVirtualMachineDeprecatedStatus(uint256 id) external typeExists(id) {
        virtualMachineTypes[id].deprecated = !virtualMachineTypes[id].deprecated;

        emit DeprecatedStatusToggled(id, virtualMachineTypes[id].deprecated);
    }
}
