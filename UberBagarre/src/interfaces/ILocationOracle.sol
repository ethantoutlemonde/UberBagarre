pragma solidity ^0.8.19;

/**
 * @title ILocationOracle
 * @dev Interface pour l'Oracle de géolocalisation
 */
interface ILocationOracle {
    struct LocationData {
        int256 latitude; // Multiplié par 10^6 pour éviter les décimales
        int256 longitude; // Multiplié par 10^6 pour éviter les décimales
        uint256 timestamp;
        bool isValid;
    }

    function requestLocation(address user, bytes32 locationHash) external;
    function getLocation(
        address user
    ) external view returns (LocationData memory);
    function findNearestFighter(
        address[] memory fighters,
        int256 clientLat,
        int256 clientLng
    ) external view returns (address);
    function updateLocation(
        address user,
        int256 latitude,
        int256 longitude
    ) external;

    event LocationRequested(address indexed user, bytes32 locationHash);
    event LocationUpdated(
        address indexed user,
        int256 latitude,
        int256 longitude
    );
}
