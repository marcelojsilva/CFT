// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title C3ResourcePricing
/// @notice This contract manages the pricing and details of resource (e.g., virtual machines and volumes).
/// @dev Implements functions for creating, updating, and managing resource and their pricing.
contract C3ResourcePricing {
    /// @notice Enum for defining different resource
    enum ResourceType {
        VirtualMachine,
        Volume,
        Other
    }

    /// @notice Structure defining a resource (VirtualMachine or Volume)
    /// @dev Stores all relevant information about a resource
    struct Resource {
        string name; // Name of the resource model
        uint256 pricePerHour; // Price per hour of the resource
        bool deprecated; // Flag to indicate if the resource model is deprecated
        ResourceType resourceType; // Type of the resource (e.g., VirtualMachine, Volume)
    }

    /// @notice Mapping of resource IDs to their corresponding Resource structs
    mapping(uint256 => Resource) public resources;

    /// @notice Mapping to check if a resource ID exists
    mapping(uint256 => bool) public idExists;

    /// @notice Address of the contract owner
    address public owner;

    /// @notice Emitted when a new resource is created
    /// @param id The unique ID of the resource
    /// @param name The name of the resource
    /// @param pricePerHour The price per hour for the resource
    /// @param resourceType The type of the resource (e.g., VirtualMachine, Volume)
    event ResourceCreated(uint256 indexed id, string name, uint256 pricePerHour, ResourceType resourceType);

    /// @notice Emitted when a resource name is updated
    /// @param id The unique ID of the resource
    /// @param name The updated name
    event NameUpdated(uint256 indexed id, string name);

    /// @notice Emitted when the price per hour is updated
    /// @param id The unique ID of the resource
    /// @param pricePerHour The updated price per hour
    event PricePerHourUpdated(uint256 indexed id, uint256 pricePerHour);

    /// @notice Emitted when the deprecated status is toggled
    /// @param id The unique ID of the resource
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

    /// @notice Modifier to check if a resource exists
    /// @param id The ID of the resource to check
    modifier resourceExists(uint256 id) {
        require(idExists[id], "Resource does not exist");
        _;
    }

    /// @notice Creates a new resource
    /// @dev Only the contract owner can create new resources
    /// @param id The unique ID of the resource
    /// @param _name The name of the resource
    /// @param _pricePerHour The price per hour for the resource
    /// @param _resourceType The type of the resource (VirtualMachine or Volume)
    function createResource(uint256 id, string calldata _name, uint256 _pricePerHour, ResourceType _resourceType)
        external
        onlyOwner
    {
        require(bytes(_name).length > 0, "Model name cannot be empty");
        require(_pricePerHour > 0, "Price per hour must be greater than 0");
        require(!idExists[id], "ID already exists");

        resources[id] =
            Resource({name: _name, pricePerHour: _pricePerHour, deprecated: false, resourceType: _resourceType});

        idExists[id] = true;

        emit ResourceCreated(id, _name, _pricePerHour, _resourceType);
    }

    /// @notice Updates the name of a resource
    /// @dev Only the contract owner can update names
    /// @param id The ID of the resource to update
    /// @param _name The new name
    function updateName(uint256 id, string calldata _name) external onlyOwner resourceExists(id) {
        require(bytes(_name).length > 0, "Model name cannot be empty");

        resources[id].name = _name;

        emit NameUpdated(id, _name);
    }

    /// @notice Updates the price per hour of a resource
    /// @dev Only the contract owner can update prices
    /// @param id The ID of the resource to update
    /// @param _pricePerHour The new price per hour
    function updatePricePerHour(uint256 id, uint256 _pricePerHour) external onlyOwner resourceExists(id) {
        require(_pricePerHour > 0, "Price per hour must be greater than 0");

        resources[id].pricePerHour = _pricePerHour;

        emit PricePerHourUpdated(id, _pricePerHour);
    }

    /// @notice Toggles the deprecated status of a resource
    /// @dev Only the contract owner can toggle deprecated status
    /// @param id The ID of the resource to update
    function toggleDeprecatedStatus(uint256 id) external onlyOwner resourceExists(id) {
        resources[id].deprecated = !resources[id].deprecated;

        emit DeprecatedStatusToggled(id, resources[id].deprecated);
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

    /// @notice Retrieves the details of a resource
    /// @param id The ID of the resource to retrieve
    /// @return name The name of the resource
    /// @return pricePerHour The price per hour for the resource
    /// @return deprecated Whether the resource is deprecated
    /// @return resourceType The type of the resource (VirtualMachine or Volume)
    function getResource(uint256 id)
        external
        view
        resourceExists(id)
        returns (string memory name, uint256 pricePerHour, bool deprecated, ResourceType resourceType)
    {
        Resource storage resource = resources[id];
        return (resource.name, resource.pricePerHour, resource.deprecated, resource.resourceType);
    }
}
