// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./libraries/FighterLibrary.sol";
import "./interfaces/ILocationOracle.sol";

/**
 * @title FighterRegistry
 * @dev Contrat pour gérer l'inscription et les données des bagarreurs
 */
contract FighterRegistry is Ownable {
    using FighterLibrary for *;

    enum FighterStatus {
        Available,
        Busy,
        Suspended
    }

    struct Fighter {
        address wallet;
        string pseudo;
        uint8 height; // en cm
        uint8 weight; // en kg
        bool isPro;
        uint8 experienceYears;
        FighterLibrary.MartialArt martialArt;
        uint16 winRate; // sur 10000 (ex: 7500 = 75%)
        FighterLibrary.FighterCategory category;
        FighterStatus status;
        uint256 totalEarnings;
        uint256 completedMissions;
        bool isRegistered;
        uint256 registrationDate;
    }

    mapping(address => Fighter) public fighters;
    address[] public registeredFighters;
    ILocationOracle public locationOracle;

    event FighterRegistered(
        address indexed fighter,
        string pseudo,
        FighterLibrary.FighterCategory category
    );
    event FighterStatusChanged(
        address indexed fighter,
        FighterStatus newStatus
    );
    event FighterStatsUpdated(
        address indexed fighter,
        uint256 earnings,
        uint256 missions
    );

    modifier onlyRegisteredFighter() {
        require(fighters[msg.sender].isRegistered, "Fighter not registered");
        _;
    }

    constructor(address _locationOracle) Ownable(msg.sender) {
        locationOracle = ILocationOracle(_locationOracle);
    }

    /**
     * @dev Inscription d'un nouveau bagarreur
     */
    function registerFighter(
        string memory _pseudo,
        uint8 _height,
        uint8 _weight,
        bool _isPro,
        uint8 _experienceYears,
        FighterLibrary.MartialArt _martialArt,
        uint16 _winRate,
        int256 _latitude,
        int256 _longitude
    ) external {
        require(
            !fighters[msg.sender].isRegistered,
            "Fighter already registered"
        );
        require(_height > 0 && _height < 250, "Invalid height");
        require(_weight > 0 && _weight < 200, "Invalid weight");
        require(_winRate <= 10000, "Invalid win rate");
        require(bytes(_pseudo).length > 0, "Pseudo required");

        FighterLibrary.FighterCategory category = FighterLibrary
            .calculateFighterCategory(
                _height,
                _weight,
                _isPro,
                _experienceYears,
                _martialArt,
                _winRate
            );

        fighters[msg.sender] = Fighter({
            wallet: msg.sender,
            pseudo: _pseudo,
            height: _height,
            weight: _weight,
            isPro: _isPro,
            experienceYears: _experienceYears,
            martialArt: _martialArt,
            winRate: _winRate,
            category: category,
            status: FighterStatus.Available,
            totalEarnings: 0,
            completedMissions: 0,
            isRegistered: true,
            registrationDate: block.timestamp
        });

        registeredFighters.push(msg.sender);

        // Enregistrer la localisation initiale
        locationOracle.updateLocation(msg.sender, _latitude, _longitude);

        emit FighterRegistered(msg.sender, _pseudo, category);
    }

    /**
     * @dev Changer le statut d'un bagarreur
     */
    function setFighterStatus(
        FighterStatus _status
    ) external onlyRegisteredFighter {
        require(
            _status != FighterStatus.Busy,
            "Cannot manually set busy status"
        );
        fighters[msg.sender].status = _status;
        emit FighterStatusChanged(msg.sender, _status);
    }

    /**
     * @dev Mettre à jour la localisation d'un bagarreur
     */
    function updateLocation(
        int256 _latitude,
        int256 _longitude
    ) external onlyRegisteredFighter {
        locationOracle.updateLocation(msg.sender, _latitude, _longitude);
    }

    /**
     * @dev Obtenir les bagarreurs disponibles
     */
    function getAvailableFighters() external view returns (address[] memory) {
        uint256 count = 0;

        for (uint i = 0; i < registeredFighters.length; i++) {
            if (
                fighters[registeredFighters[i]].status ==
                FighterStatus.Available
            ) {
                count++;
            }
        }

        address[] memory availableFighters = new address[](count);
        uint256 index = 0;

        for (uint i = 0; i < registeredFighters.length; i++) {
            if (
                fighters[registeredFighters[i]].status ==
                FighterStatus.Available
            ) {
                availableFighters[index] = registeredFighters[i];
                index++;
            }
        }

        return availableFighters;
    }

    /**
     * @dev Fonctions d'administration
     */
    function updateFighterStats(
        address _fighter,
        uint256 _earnings,
        uint256 _missions
    ) external onlyOwner {
        require(fighters[_fighter].isRegistered, "Fighter not registered");
        fighters[_fighter].totalEarnings += _earnings;
        fighters[_fighter].completedMissions += _missions;
        emit FighterStatsUpdated(_fighter, _earnings, _missions);
    }

    function setFighterStatusAdmin(
        address _fighter,
        FighterStatus _status
    ) external onlyOwner {
        require(fighters[_fighter].isRegistered, "Fighter not registered");
        fighters[_fighter].status = _status;
        emit FighterStatusChanged(_fighter, _status);
    }

    function getFighter(
        address _fighter
    ) external view returns (Fighter memory) {
        return fighters[_fighter];
    }

    function getFighterCount() external view returns (uint256) {
        return registeredFighters.length;
    }
}
