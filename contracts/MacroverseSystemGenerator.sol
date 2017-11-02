pragma solidity ^0.4.15;

import "./RNG.sol";
import "./RealMath.sol";

import "./AccessControl.sol";
import "./ControlledAccess.sol";

import "./MacroverseStarGenerator.sol";

/**
 * Represents a prorotype Macroverse Generator for a galaxy.
 *
 * Permission to call methods on this contract is regulated by a configurable
 * AccessControl contract. One such set of terms might be to require that the
 * account initiating a transaction have a certain minimum MRV token balance.
 *
 * The owner of this contract reserves the right to supersede it with a new
 * version, and to modify the terms for accessing this contract, at any time,
 * for any reason, and without notice. This includes the right to indefinitely
 * or permanently suspend or terminate access to this contract for any person,
 * account, or other contract, or for all persons, accounts, or other
 * contracts. The owner also reserves the right to not do any of the above.
 */
contract MacroverseSystemGenerator is ControlledAccess {
    // TODO: RNG doesn't get linked against because we can't pass the struct to the library...
    using RNG for *;
    using RealMath for *;
    // No SafeMath or it might confuse RealMath

    /**
     * Define different types of planet.
     */
    enum PlanetClass {Lunar, Terrestrial, Uranian, Jovian, AsteroidBelt}

    /**
     * Deploy a new copy of the MacroverseSystemGenerator.
     */
    function MacroverseSystemGenerator(address accessControlAddress) ControlledAccess(AccessControl(accessControlAddress)) {
        // Nothing to do!
    }
    
    /**
     * If the object has any planets at all, get theœplanet count. Will return
     * nonzero numbers always, so make sure to check getObjectHasPlanets in the
     * Star Generator.
     */
    function getObjectPlanetCount(bytes32 seed, MacroverseStarGenerator.ObjectClass objectClass,
        MacroverseStarGenerator.SpectralType spectralType) constant onlyControlledAccess returns (int16) {
        
        var node = RNG.RandNode(seed).derive("planetcount");
        
        
        int16 limit;

        if (objectClass == MacroverseStarGenerator.ObjectClass.MainSequence) {
            if (spectralType == MacroverseStarGenerator.SpectralType.TypeO ||
                spectralType == MacroverseStarGenerator.SpectralType.TypeB) {
                
                limit = 5;
            } else if (spectralType == MacroverseStarGenerator.SpectralType.TypeA) {
                limit = 7;
            } else if (spectralType == MacroverseStarGenerator.SpectralType.TypeF ||
                spectralType == MacroverseStarGenerator.SpectralType.TypeG ||
                spectralType == MacroverseStarGenerator.SpectralType.TypeK) {
                
                limit = 12;
            } else if (spectralType == MacroverseStarGenerator.SpectralType.TypeM) {
                limit = 14;
            }
        } else if (objectClass == MacroverseStarGenerator.ObjectClass.Giant) {
            limit = 2;
        } else if (objectClass == MacroverseStarGenerator.ObjectClass.Supergiant) {
            limit = 2;
        } else {
           // Black hole, neutron star, or white dwarf
           limit = 2;
        }
        
        var roll = int16(node.getIntBetween(1, limit));
        
        return roll;
    }
    
    /**
     * Decide what kind of planet a given planet is.
     * It depends on its place in the order.
     */
    function getPlanetClass(bytes32 seed, int16 planetNumber, int16 totalPlanets) constant onlyControlledAccess returns (PlanetClass) {
        // TODO: do something based on metallicity?
        var node = RNG.RandNode(seed).derive(planetNumber).derive("class");
        
        var roll = node.getIntBetween(1, 100);
        
        // Inner planets should be more planet-y, ideally smaller
        // Asteroid belts shouldn't be first that often
        
        if (planetNumber == 0 && totalPlanets != 1) {
            // Innermost planet of a multi-planet system
            // No asteroid belts allowed!
            if (roll < 70) {
                return PlanetClass.Lunar;
            } else if (roll < 80) {
                return PlanetClass.Terrestrial;
            } else if (roll < 90) {
                return PlanetClass.Uranian;
            } else {
                return PlanetClass.Jovian;
            }
        } else if (planetNumber < totalPlanets / 2) {
            // Inner system
            if (roll < 20) {
                return PlanetClass.Lunar;
            } else if (roll < 40) {
                return PlanetClass.Terrestrial;
            } else if (roll < 70) {
                return PlanetClass.Uranian;
            } else if (roll < 80) {
                return PlanetClass.Jovian;
            } else {
                return PlanetClass.AsteroidBelt;
            }
        } else {
            // Outer system
            if (roll < 20) {
                return PlanetClass.Lunar;
            } else if (roll < 30) {
                return PlanetClass.Terrestrial;
            } else if (roll < 60) {
                return PlanetClass.Uranian;
            } else if (roll < 90) {
                return PlanetClass.Jovian;
            } else {
                return PlanetClass.AsteroidBelt;
            }
        }
    }
    
    /**
     * Decide what the mass of the planet is. We can't do even the mass of
     * Jupiter in the ~88 bits we have in a real (should we have used int256 as
     * the backing type?) so we work in Earth masses.
     */
    function getPlanetMass(bytes32 seed, int8 planetNumber, PlanetClass class) constant onlyControlledAccess returns (int128) {
        var node = RNG.RandNode(seed).derive(planetNumber).derive("mass");
        
        if (class == PlanetClass.Lunar) {
            return node.getRealBetween(RealMath.fraction(1, 100), RealMath.fraction(9, 100));
        } else if (class == PlanetClass.Terrestrial) {
            return node.getRealBetween(RealMath.fraction(10, 100), RealMath.toReal(9));
        } else if (class == PlanetClass.Uranian) {
            return node.getRealBetween(RealMath.toReal(9), RealMath.toReal(20));
        } else if (class == PlanetClass.Jovian) {
            return node.getRealBetween(RealMath.toReal(50), RealMath.toReal(400));
        } else if (class == PlanetClass.AsteroidBelt) {
            return node.getRealBetween(RealMath.fraction(1, 100), RealMath.fraction(20, 100));
        } else {
            // Not real!
            revert();
        }
    }
    
    /**
     * Decide what the planet's orbit's periapsis is, in meters.
     * This is the first statistic about the orbit to be generated.
     * For the first planet, realPrevClearance is 0.
     */
    function getPlanetPeriapsis(bytes32 seed, int8 planetNumber, PlanetClass class, int128 realPrevClearance) constant onlyControlledAccess returns (int128) {
        
        var node = RNG.RandNode(seed).derive(planetNumber).derive("periapsis");
        
        // Define minimum and maximum periapsis distance above previous planet's
        // cleared band in millions of km
        int88 minimum;
        int88 maximum;
        if (class == PlanetClass.Lunar) {
            minimum = 20;
            maximum = 60;
        } else if (class == PlanetClass.Terrestrial) {
            minimum = 40;
            maximum = 70;
        } else if (class == PlanetClass.Uranian) {
            minimum = 1000;
            maximum = 2000;
        } else if (class == PlanetClass.Jovian) {
            minimum = 300;
            maximum = 500;
        } else if (class == PlanetClass.AsteroidBelt) {
            minimum = 20;
            maximum = 500;
        } else {
            // Not real!
            revert();
        }
        
        int128 realSeparation = node.getRealBetween(RealMath.toReal(minimum), RealMath.toReal(maximum));
        return realPrevClearance + RealMath.mul(realSeparation, RealMath.toReal(1000000000)); 
    }
    
    /**
     * Decide what the planet's orbit's apoapsis is, in meters.
     * This is the second statistic about the orbit to be generated.
     */
    function getPlanetApoapsis(bytes32 seed, int8 planetNumber, PlanetClass class, int128 realPeriapsis) constant onlyControlledAccess returns (int128) {
        
        var node = RNG.RandNode(seed).derive(planetNumber).derive("apoapsis");
        
        // Define minimum and maximum apoapsis distance above planet's periapsis
        int88 minimum;
        int88 maximum;
        if (class == PlanetClass.Lunar) {
            minimum = 0;
            maximum = 3;
        } else if (class == PlanetClass.Terrestrial) {
            minimum = 0;
            maximum = 5;
        } else if (class == PlanetClass.Uranian) {
            minimum = 20;
            maximum = 500;
        } else if (class == PlanetClass.Jovian) {
            minimum = 10;
            maximum = 100;
        } else if (class == PlanetClass.AsteroidBelt) {
            minimum = 10;
            maximum = 50;
        } else {
            // Not real!
            revert();
        }
        
        int128 realWidth = node.getRealBetween(RealMath.toReal(minimum), RealMath.toReal(maximum));
        return realPeriapsis + RealMath.mul(realWidth, RealMath.toReal(1000000000)); 
    }
    
    /**
     * Decide how far out the cleared band after the planet's orbit is.
     */
    function getPlanetClearance(bytes32 seed, int8 planetNumber, PlanetClass class, int128 realApoapsis) constant onlyControlledAccess returns (int128) {
        
        var node = RNG.RandNode(seed).derive(planetNumber).derive("cleared");
        
        // Define minimum and maximum clearance in millions of km.
        // TODO: Constants should be sort of like the periapsis constants I think? But maybe not identical.
        int88 minimum;
        int88 maximum;
        if (class == PlanetClass.Lunar) {
            minimum = 20;
            maximum = 60;
        } else if (class == PlanetClass.Terrestrial) {
            minimum = 40;
            maximum = 70;
        } else if (class == PlanetClass.Uranian) {
            minimum = 1000;
            maximum = 2000;
        } else if (class == PlanetClass.Jovian) {
            minimum = 300;
            maximum = 500;
        } else if (class == PlanetClass.AsteroidBelt) {
            minimum = 20;
            maximum = 500;
        } else {
            // Not real!
            revert();
        }
        
        int128 realSeparation = node.getRealBetween(RealMath.toReal(minimum), RealMath.toReal(maximum));
        return realApoapsis + RealMath.mul(realSeparation, RealMath.toReal(1000000000)); 
    }

}
 