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

    VirtualMachineType[] public virtualMachineTypes;

    /// @notice Emitted when a new virtual machine type is created
    /// @param modelName The name of the virtual machine model
    /// @param pricePerHour The price per hour for the virtual machine model
    event TypeCreated(string modelName, uint256 pricePerHour);

    /// @notice Emitted when a virtual machine model name is updated
    /// @param modelName The updated model name
    event ModelNameUpdated(uint256 indexed index, string modelName);

    /// @notice Emitted when the price per hour is updated
    /// @param pricePerHour The updated price per hour
    event PricePerHourUpdated(uint256 indexed index, uint256 pricePerHour);

    /// @notice Emitted when the deprecated status is toggled
    /// @param deprecated The new deprecated status
    event DeprecatedStatusToggled(uint256 indexed index, bool deprecated);

    /**
     * @notice Creates a new virtual machine type
     * @param _modelName The name of the virtual machine model
     * @param _pricePerHour The price per hour for the virtual machine model
     */
    function createVirtualMachineType(string calldata _modelName, uint256 _pricePerHour) external {
        require(bytes(_modelName).length > 0, "Model name cannot be empty");
        require(_pricePerHour > 0, "Price per hour must be greater than 0");

        virtualMachineTypes.push(VirtualMachineType({
            modelName: _modelName,
            pricePerHour: _pricePerHour,
            deprecated: false
        }));

        emit TypeCreated(_modelName, _pricePerHour);
    }

    /**
     * @notice Checks if a virtual machine type exists at a given index
     * @param _index The index to check
     * @return bool True if the virtual machine type exists, false otherwise
     */
    function exists(uint256 _index) public view returns (bool) {
        return _index < virtualMachineTypes.length;
    }

    /**
     * @notice Retrieves the details of a virtual machine type
     * @param _index The index of the virtual machine type to retrieve
     * @return modelName The name of the virtual machine model
     * @return pricePerHour The price per hour for the virtual machine model
     * @return deprecated The deprecated status of the virtual machine model
     */
    function get(uint256 _index)
        public
        view
        returns (string memory modelName, uint256 pricePerHour, bool deprecated)
    {
        require(exists(_index), "Virtual machine type does not exist");

        VirtualMachineType storage virtualMachineType = virtualMachineTypes[_index];
        return (virtualMachineType.modelName, virtualMachineType.pricePerHour, virtualMachineType.deprecated);
    }

    /**
     * @notice Updates the model name of a virtual machine type
     * @param _index The index of the virtual machine type to update
     * @param _modelName The new model name
     */
    function updateVirtualMachineModelName(uint256 _index, string calldata _modelName) external {
        require(exists(_index), "Virtual machine type does not exist");
        require(bytes(_modelName).length > 0, "Model name cannot be empty");

        VirtualMachineType storage virtualMachineType = virtualMachineTypes[_index];
        virtualMachineType.modelName = _modelName;

        emit ModelNameUpdated(_index, _modelName);
    }

    /**
     * @notice Updates the price per hour of a virtual machine type
     * @param _index The index of the virtual machine type to update
     * @param _pricePerHour The new price per hour
     */
    function updateVirtualMachinePricePerHour(uint256 _index, uint256 _pricePerHour) external {
        require(exists(_index), "Virtual machine type does not exist");
        require(_pricePerHour > 0, "Price per hour must be greater than 0");

        VirtualMachineType storage virtualMachineType = virtualMachineTypes[_index];
        virtualMachineType.pricePerHour = _pricePerHour;

        emit PricePerHourUpdated(_index, _pricePerHour);
    }

    /**
     * @notice Toggles the deprecated status of a virtual machine type
     * @param _index The index of the virtual machine type to update
     */
    function toggleVirtualMachineDeprecatedStatus(uint256 _index) external {
        require(exists(_index), "Virtual machine type does not exist");

        VirtualMachineType storage virtualMachineType = virtualMachineTypes[_index];
        virtualMachineType.deprecated = !virtualMachineType.deprecated;

        emit DeprecatedStatusToggled(_index, virtualMachineType.deprecated);
    }
}
