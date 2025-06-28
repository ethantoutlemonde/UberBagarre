// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./FighterRegistry.sol";
import "./MissionManager.sol";
import "./LocationOracle.sol";
import "./libraries/FighterLibrary.sol";

/**
 * @title UberBagarre
 * @dev Contrat principal orchestrant toute la plateforme
 */
contract UberBagarre {
    FighterRegistry public immutable FIGHTER_REGISTRY;
    MissionManager public immutable MISSION_MANAGER;
    LocationOracle public immutable LOCATION_ORACLE;

    address public immutable OWNER;

    event PlatformDeployed(
        address fighterRegistry,
        address missionManager,
        address locationOracle
    );

    constructor() {
        OWNER = msg.sender;

        // Déployer l'Oracle de localisation
        LOCATION_ORACLE = new LocationOracle();

        // Déployer le registre des bagarreurs
        FIGHTER_REGISTRY = new FighterRegistry(address(LOCATION_ORACLE));

        // Déployer le gestionnaire de missions
        MISSION_MANAGER = new MissionManager(
            address(FIGHTER_REGISTRY),
            address(LOCATION_ORACLE)
        );

        // Configurer les autorisations
        LOCATION_ORACLE.addAuthorizedCaller(address(FIGHTER_REGISTRY));
        LOCATION_ORACLE.addAuthorizedCaller(address(MISSION_MANAGER));

        emit PlatformDeployed(
            address(FIGHTER_REGISTRY),
            address(MISSION_MANAGER),
            address(LOCATION_ORACLE)
        );
    }

    /**
     * @dev Obtenir toutes les adresses des contrats
     */
    function getContractAddresses()
        external
        view
        returns (
            address _fighterRegistry,
            address _missionManager,
            address _locationOracle
        )
    {
        return (
            address(FIGHTER_REGISTRY),
            address(MISSION_MANAGER),
            address(LOCATION_ORACLE)
        );
    }

    /**
     * @dev Fonction utilitaire pour obtenir le prix suggéré
     */
    function getSuggestedPrice(
        FighterLibrary.FighterCategory category
    ) external pure returns (uint256) {
        return FighterLibrary.getSuggestedPrice(category);
    }
}
