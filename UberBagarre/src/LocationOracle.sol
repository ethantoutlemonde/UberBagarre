// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/ILocationOracle.sol";

/**
 * @title LocationOracle
 * @dev Oracle pour gérer les données de géolocalisation
 */
contract LocationOracle is ILocationOracle, Ownable {
    mapping(address => LocationData) private userLocations;
    mapping(address => bool) public authorizedCallers;

    modifier onlyAuthorized() {
        require(
            authorizedCallers[msg.sender] || msg.sender == owner(),
            "Not authorized"
        );
        _;
    }

    constructor() Ownable(msg.sender) {
        authorizedCallers[msg.sender] = true;
    }

    /**
     * @dev Demander une mise à jour de localisation
     */
    function requestLocation(
        address user,
        bytes32 locationHash
    ) external onlyAuthorized {
        emit LocationRequested(user, locationHash);
    }

    /**
     * @dev Obtenir la localisation d'un utilisateur
     */
    function getLocation(
        address user
    ) external view returns (LocationData memory) {
        return userLocations[user];
    }

    /**
     * @dev Mettre à jour la localisation d'un utilisateur
     */
    function updateLocation(
        address user,
        int256 latitude,
        int256 longitude
    ) external onlyAuthorized {
        userLocations[user] = LocationData({
            latitude: latitude,
            longitude: longitude,
            timestamp: block.timestamp,
            isValid: true
        });

        emit LocationUpdated(user, latitude, longitude);
    }

    /**
     * @dev Trouver le bagarreur le plus proche
     */
    function findNearestFighter(
        address[] memory fighters,
        int256 clientLat,
        int256 clientLng
    ) external view returns (address) {
        if (fighters.length == 0) return address(0);

        address nearestFighter = address(0);
        uint256 shortestDistance = type(uint256).max;

        for (uint i = 0; i < fighters.length; i++) {
            LocationData memory fighterLocation = userLocations[fighters[i]];

            if (!fighterLocation.isValid) continue;

            // Calculer la distance (approximation simplifiée)
            uint256 distance = _calculateDistance(
                clientLat,
                clientLng,
                fighterLocation.latitude,
                fighterLocation.longitude
            );

            if (distance < shortestDistance) {
                shortestDistance = distance;
                nearestFighter = fighters[i];
            }
        }

        return nearestFighter;
    }

    /**
     * @dev Calculer la distance entre deux points (formule haversine simplifiée)
     */
    function _calculateDistance(
        int256 lat1,
        int256 lng1,
        int256 lat2,
        int256 lng2
    ) internal pure returns (uint256) {
        if (lat1 == lat2 && lng1 == lng2) return 0;

        int256 deltaLat = lat1 - lat2;
        int256 deltaLng = lng1 - lng2;

        // Distance euclidienne simplifiée (pour éviter les calculs trigonométriques complexes)
        uint256 distance = uint256(deltaLat * deltaLat + deltaLng * deltaLng);
        return distance;
    }

    /**
     * @dev Autoriser un appelant
     */
    function addAuthorizedCaller(address caller) external onlyOwner {
        authorizedCallers[caller] = true;
    }

    /**
     * @dev Révoquer l'autorisation d'un appelant
     */
    function removeAuthorizedCaller(address caller) external onlyOwner {
        authorizedCallers[caller] = false;
    }

    /**
     * @dev Nettoyer les anciennes données de localisation
     */
    function cleanupOldLocations(
        address[] memory users,
        uint256 maxAge
    ) external onlyOwner {
        uint256 cutoffTime = block.timestamp - maxAge;

        for (uint i = 0; i < users.length; i++) {
            if (userLocations[users[i]].timestamp < cutoffTime) {
                userLocations[users[i]].isValid = false;
            }
        }
    }
}
