// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./C3ResourcePricing.sol";

/// @title C3Volume
/// @notice This contract manages the creation and management of volumes.
/// @dev Implements functions for creating, updating, and managing volumes.
contract C3Volume {
    /// @notice Structure defining a volume
    /// @dev Stores all relevant information about a volume
    struct Volume {
        uint256 id; // Unique ID of the volume
        uint256 size; // Size of the volume in GB
        uint256 resourceId; // ID of the resource
        address volumeOwner; // Owner of the volume
        uint256 totalHoursToRun; // Total hours the volume is supposed to run
        uint256 pricePerHour; // Price per hour for running the volume
        uint256 consumedHours; // Total hours consumed so far
    }

    /// @notice Address of the ResourcePricing contract
    address public immutable resourcePricing;

    /// @notice Counter for generating unique Volume IDs
    uint256 private nextId;

    /// @notice Mapping of volume IDs to their corresponding Volume structs
    mapping(uint256 => Volume) public volumes;

    /// @notice Mapping to check if a volume ID exists
    mapping(uint256 => bool) public volumeExists;

    /// @notice Emitted when a new volume is created
    /// @param id The unique ID of the volume
    /// @param size The size of the volume in GB
    /// @param resourceId The ID of the resource
    /// @param totalHoursToRun Total hours the volume is expected to run
    event VolumeCreated(uint256 indexed id, uint256 size, uint256 resourceId, uint256 totalHoursToRun);

    /// @notice Emitted when the size of a volume is updated
    /// @param id The unique ID of the volume
    /// @param size The updated size of the volume
    event SizeUpdated(uint256 indexed id, uint256 size);

    /// @notice Emitted when a volume is deleted
    /// @param id The unique ID of the volume
    event VolumeDeleted(uint256 indexed id);

    /// @notice Modifier to restrict function access to Volume owner
    /// @param volumeId The ID of the Volume
    modifier onlyVolumeOwner(uint256 volumeId) {
        require(volumes[volumeId].volumeOwner == msg.sender, "Not the Volume owner");
        _;
    }

    /// @notice Constructor to initialize the ResourcePricing contract address
    /// @param _resourcePricing Address of the ResourcePricing contract
    constructor(address _resourcePricing) {
        require(_resourcePricing != address(0), "Invalid resource pricing address");
        resourcePricing = _resourcePricing;
    }

    /// @notice Function to create a new volume
    /// @param size The size of the volume in GB
    /// @param resourceId The ID of the resource
    /// @param totalHoursToRun Total hours the volume is expected to run
    function createVolume(uint256 size, uint256 resourceId, uint256 totalHoursToRun) external {
        require(size > 0, "Volume size must be greater than 0");
        require(size <= 1048576, "Volume size must be less than or equal to 1 TB");
        require(totalHoursToRun > 0, "Total hours to run must be greater than 0");
        require(totalHoursToRun <= 8760, "Total hours to run must be less than or equal to 1 year");

        C3ResourcePricing pricingContract = C3ResourcePricing(resourcePricing);
        require(pricingContract.idExists(resourceId), "Volume resource id does not exist");

        (, uint256 _pricePerHour, bool _deprecated, C3ResourcePricing.ResourceType _resourceType) =
            pricingContract.getResource(resourceId);
        require(!_deprecated, "Volume resource is deprecated");
        require(_resourceType == C3ResourcePricing.ResourceType.Volume, "Resource type is not Volume");

        nextId++;
        uint256 id = nextId;

        volumes[id] = Volume({
            id: id,
            size: size,
            resourceId: resourceId,
            volumeOwner: msg.sender, // Assigning ownership to the caller
            totalHoursToRun: totalHoursToRun,
            pricePerHour: _pricePerHour,
            consumedHours: 0 // Initializing with 0 consumed hours
        });

        volumeExists[id] = true;

        emit VolumeCreated(id, size, resourceId, totalHoursToRun);
    }

    /// @notice Function to update the consumed hours of a volume
    /// @param id The unique ID of the volume
    /// @param hoursToConsume The number of hours to add to the consumed hours
    function updateConsumedHours(uint256 id, uint256 hoursToConsume) external onlyVolumeOwner(id) {
        require(volumeExists[id], "Volume does not exist");
        require(hoursToConsume > 0, "Consumed hours must be greater than 0");

        Volume storage volume = volumes[id];

        require(volume.consumedHours + hoursToConsume <= volume.totalHoursToRun, "Exceeds total hours to run");

        volume.consumedHours += hoursToConsume;
    }

    /// @notice Function to calculate the total cost for the volume based on consumed hours
    /// @param id The unique ID of the volume
    /// @return totalCost The total cost based on consumed hours
    function calculateTotalCost(uint256 id) external view returns (uint256 totalCost) {
        require(volumeExists[id], "Volume does not exist");

        Volume storage volume = volumes[id];
        totalCost = volume.consumedHours * volume.pricePerHour;
    }

    /// @notice Function to delete a volume by ID
    /// @param id The unique ID of the volume
    function deleteVolume(uint256 id) external onlyVolumeOwner(id) {
        require(volumeExists[id], "Volume does not exist");

        delete volumes[id];
        volumeExists[id] = false;

        emit VolumeDeleted(id);
    }
}
