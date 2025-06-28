// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./FighterRegistry.sol";
import "./interfaces/ILocationOracle.sol";

/**
 * @title MissionManager
 * @dev Contrat pour gérer les missions et leur attribution
 */
contract MissionManager is ReentrancyGuard, Ownable, Pausable {
    enum MissionStatus {
        Created,
        Assigned,
        Completed,
        Disputed,
        Cancelled
    }

    struct Mission {
        uint256 id;
        address client;
        bytes32 locationHash;
        int256 clientLatitude;
        int256 clientLongitude;
        uint256 totalAmount;
        uint256 fighterAmount;
        uint256 platformFee;
        address assignedFighter;
        MissionStatus status;
        uint256 createdAt;
        uint256 completedAt;
        string description;
        FighterLibrary.FighterCategory requiredCategory;
    }

    mapping(uint256 => Mission) public missions;
    mapping(address => uint256[]) public clientMissions;
    mapping(address => uint256[]) public fighterMissions;

    FighterRegistry public fighterRegistry;
    ILocationOracle public locationOracle;

    uint256 public nextMissionId = 1;
    uint256 public platformFeePercentage = 500; // 5%

    event MissionCreated(
        uint256 indexed missionId,
        address indexed client,
        uint256 amount
    );
    event FighterAssigned(uint256 indexed missionId, address indexed fighter);
    event MissionCompleted(
        uint256 indexed missionId,
        address indexed fighter,
        uint256 amount
    );
    event DisputeSignaled(uint256 indexed missionId, address indexed reporter);
    event MissionCancelled(uint256 indexed missionId);

    modifier onlyMissionClient(uint256 _missionId) {
        require(
            missions[_missionId].client == msg.sender,
            "Not mission client"
        );
        _;
    }

    modifier onlyAssignedFighter(uint256 _missionId) {
        require(
            missions[_missionId].assignedFighter == msg.sender,
            "Not assigned fighter"
        );
        _;
    }

    modifier validMission(uint256 _missionId) {
        require(
            _missionId > 0 && _missionId < nextMissionId,
            "Invalid mission ID"
        );
        _;
    }

    constructor(
        address _fighterRegistry,
        address _locationOracle
    ) Ownable(msg.sender) {
        fighterRegistry = FighterRegistry(_fighterRegistry);
        locationOracle = ILocationOracle(_locationOracle);
    }

    /**
     * @dev Création d'une mission avec géolocalisation
     */
    function createMission(
        bytes32 _locationHash,
        int256 _latitude,
        int256 _longitude,
        string memory _description,
        FighterLibrary.FighterCategory _requiredCategory
    ) external payable nonReentrant whenNotPaused {
        require(msg.value > 0, "Payment required");
        require(_locationHash != bytes32(0), "Location hash required");

        uint256 platformFee = (msg.value * platformFeePercentage) / 10000;
        uint256 fighterAmount = msg.value - platformFee;

        missions[nextMissionId] = Mission({
            id: nextMissionId,
            client: msg.sender,
            locationHash: _locationHash,
            clientLatitude: _latitude,
            clientLongitude: _longitude,
            totalAmount: msg.value,
            fighterAmount: fighterAmount,
            platformFee: platformFee,
            assignedFighter: address(0),
            status: MissionStatus.Created,
            createdAt: block.timestamp,
            completedAt: 0,
            description: _description,
            requiredCategory: _requiredCategory
        });

        clientMissions[msg.sender].push(nextMissionId);

        emit MissionCreated(nextMissionId, msg.sender, msg.value);
        nextMissionId++;
    }

    /**
     * @dev Attribution automatique du bagarreur le plus proche
     */
    function assignNearestFighter(
        uint256 _missionId
    ) external onlyMissionClient(_missionId) validMission(_missionId) {
        Mission storage mission = missions[_missionId];
        require(
            mission.status == MissionStatus.Created,
            "Mission not available"
        );

        // Obtenir les bagarreurs disponibles
        address[] memory availableFighters = fighterRegistry
            .getAvailableFighters();
        require(availableFighters.length > 0, "No available fighters");

        // Filtrer par catégorie requise
        address[] memory eligibleFighters = _filterByCategory(
            availableFighters,
            mission.requiredCategory
        );
        require(eligibleFighters.length > 0, "No eligible fighters found");

        // Trouver le plus proche via l'Oracle
        address nearestFighter = locationOracle.findNearestFighter(
            eligibleFighters,
            mission.clientLatitude,
            mission.clientLongitude
        );

        require(nearestFighter != address(0), "No fighter found");

        _assignFighter(_missionId, nearestFighter);
    }

    /**
     * @dev Attribution manuelle d'un bagarreur spécifique
     */
    function assignSpecificFighter(
        uint256 _missionId,
        address _fighter
    ) external onlyMissionClient(_missionId) validMission(_missionId) {
        Mission storage mission = missions[_missionId];
        require(
            mission.status == MissionStatus.Created,
            "Mission not available"
        );

        FighterRegistry.Fighter memory fighter = fighterRegistry.getFighter(
            _fighter
        );
        require(fighter.isRegistered, "Fighter not registered");
        require(
            fighter.status == FighterRegistry.FighterStatus.Available,
            "Fighter not available"
        );
        require(
            fighter.category >= mission.requiredCategory,
            "Fighter category too low"
        );

        _assignFighter(_missionId, _fighter);
    }

    /**
     * @dev Fonction interne d'attribution
     */
    function _assignFighter(uint256 _missionId, address _fighter) internal {
        Mission storage mission = missions[_missionId];

        mission.assignedFighter = _fighter;
        mission.status = MissionStatus.Assigned;

        // Mettre à jour le statut du bagarreur
        fighterRegistry.setFighterStatusAdmin(
            _fighter,
            FighterRegistry.FighterStatus.Busy
        );

        fighterMissions[_fighter].push(_missionId);

        emit FighterAssigned(_missionId, _fighter);
    }

    /**
     * @dev Filtrer les bagarreurs par catégorie
     */
    function _filterByCategory(
        address[] memory _fighters,
        FighterLibrary.FighterCategory _requiredCategory
    ) internal view returns (address[] memory) {
        uint256 count = 0;

        // Compter les bagarreurs éligibles
        for (uint i = 0; i < _fighters.length; i++) {
            FighterRegistry.Fighter memory fighter = fighterRegistry.getFighter(
                _fighters[i]
            );
            if (fighter.category >= _requiredCategory) {
                count++;
            }
        }

        // Créer le tableau filtré
        address[] memory eligibleFighters = new address[](count);
        uint256 index = 0;

        for (uint i = 0; i < _fighters.length; i++) {
            FighterRegistry.Fighter memory fighter = fighterRegistry.getFighter(
                _fighters[i]
            );
            if (fighter.category >= _requiredCategory) {
                eligibleFighters[index] = _fighters[i];
                index++;
            }
        }

        return eligibleFighters;
    }

    /**
     * @dev Marquer une mission comme terminée
     */
    function completeMission(
        uint256 _missionId
    )
        external
        onlyAssignedFighter(_missionId)
        validMission(_missionId)
        nonReentrant
    {
        Mission storage mission = missions[_missionId];
        require(
            mission.status == MissionStatus.Assigned,
            "Mission not assigned"
        );

        mission.status = MissionStatus.Completed;
        mission.completedAt = block.timestamp;

        // Remettre le bagarreur disponible
        fighterRegistry.setFighterStatusAdmin(
            msg.sender,
            FighterRegistry.FighterStatus.Available
        );

        // Mettre à jour les stats
        fighterRegistry.updateFighterStats(
            msg.sender,
            mission.fighterAmount,
            1
        );

        // Transferts
        payable(msg.sender).transfer(mission.fighterAmount);
        payable(owner()).transfer(mission.platformFee);

        emit MissionCompleted(_missionId, msg.sender, mission.fighterAmount);
    }

    /**
     * @dev Signaler un litige
     */
    function signalDispute(
        uint256 _missionId
    ) external validMission(_missionId) {
        Mission storage mission = missions[_missionId];
        require(
            msg.sender == mission.client ||
                msg.sender == mission.assignedFighter,
            "Not authorized"
        );
        require(
            mission.status == MissionStatus.Assigned,
            "Invalid mission status"
        );

        mission.status = MissionStatus.Disputed;
        emit DisputeSignaled(_missionId, msg.sender);
    }

    /**
     * @dev Résoudre un litige (admin)
     */
    function resolveDispute(
        uint256 _missionId,
        bool _favorClient
    ) external onlyOwner validMission(_missionId) nonReentrant {
        Mission storage mission = missions[_missionId];
        require(
            mission.status == MissionStatus.Disputed,
            "Mission not disputed"
        );

        if (_favorClient) {
            payable(mission.client).transfer(mission.fighterAmount);
        } else {
            fighterRegistry.updateFighterStats(
                mission.assignedFighter,
                mission.fighterAmount,
                1
            );
            payable(mission.assignedFighter).transfer(mission.fighterAmount);
        }

        payable(owner()).transfer(mission.platformFee);
        mission.status = MissionStatus.Completed;
        mission.completedAt = block.timestamp;

        fighterRegistry.setFighterStatusAdmin(
            mission.assignedFighter,
            FighterRegistry.FighterStatus.Available
        );
    }

    /**
     * @dev Annuler une mission
     */
    function cancelMission(
        uint256 _missionId
    )
        external
        onlyMissionClient(_missionId)
        validMission(_missionId)
        nonReentrant
    {
        Mission storage mission = missions[_missionId];
        require(
            mission.status == MissionStatus.Created,
            "Cannot cancel assigned mission"
        );

        mission.status = MissionStatus.Cancelled;

        uint256 refundAmount = (mission.totalAmount * 9900) / 10000; // 1% de pénalité
        payable(msg.sender).transfer(refundAmount);
        payable(owner()).transfer(mission.totalAmount - refundAmount);

        emit MissionCancelled(_missionId);
    }

    // Fonctions de vue
    function getMission(
        uint256 _missionId
    ) external view returns (Mission memory) {
        return missions[_missionId];
    }

    function getClientMissions(
        address _client
    ) external view returns (uint256[] memory) {
        return clientMissions[_client];
    }

    function getFighterMissions(
        address _fighter
    ) external view returns (uint256[] memory) {
        return fighterMissions[_fighter];
    }

    // Administration
    function setPlatformFee(uint256 _newFee) external onlyOwner {
        require(_newFee <= 1000, "Fee too high");
        platformFeePercentage = _newFee;
    }

    function pause() external onlyOwner {
        _pause();
    }
    function unpause() external onlyOwner {
        _unpause();
    }

    function emergencyWithdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    receive() external payable {}
}
