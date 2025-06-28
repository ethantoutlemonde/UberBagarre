// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title FighterLibrary
 * @dev Bibliothèque pour les calculs liés aux bagarreurs
 */
library FighterLibrary {
    enum FighterCategory {
        Novice,
        Warrior,
        Jedi,
        Thanos
    }
    enum MartialArt {
        None,
        MMA,
        JiuJitsu,
        Boxing,
        Karate,
        Muay_Thai,
        Street_Fighting,
        Wrestling
    }

    /**
     * @dev Calculer la catégorie d'un bagarreur
     */
    function calculateFighterCategory(
        uint8 _height,
        uint8 _weight,
        bool _isPro,
        uint8 _experienceYears,
        MartialArt _martialArt,
        uint16 _winRate
    ) internal pure returns (FighterCategory) {
        uint256 score = 0;

        // Points pour la taille et le poids
        if (_height > 180) score += 20;
        if (_weight > 80) score += 20;

        // Points pour l'expérience professionnelle
        if (_isPro) score += 40;

        // Points pour les années d'expérience
        score += _experienceYears * 5;

        // Points pour l'art martial
        if (_martialArt == MartialArt.MMA) score += 30;
        else if (
            _martialArt == MartialArt.JiuJitsu ||
            _martialArt == MartialArt.Boxing
        ) score += 25;
        else if (_martialArt != MartialArt.None) score += 15;

        score += _winRate / 100;

        if (score >= 200) return FighterCategory.Thanos;
        else if (score >= 120) return FighterCategory.Jedi;
        else if (score >= 60) return FighterCategory.Warrior;
        else return FighterCategory.Novice;
    }

    /**
     * @dev Calculer le prix suggéré pour une mission basé sur la catégorie
     */
    function getSuggestedPrice(
        FighterCategory _category
    ) internal pure returns (uint256) {
        if (_category == FighterCategory.Thanos) return 1 ether;
        else if (_category == FighterCategory.Jedi) return 0.5 ether;
        else if (_category == FighterCategory.Warrior) return 0.2 ether;
        else return 0.1 ether;
    }
}
