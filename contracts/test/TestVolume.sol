// SPDX-License-Identifier: GPL-v3
pragma solidity ^0.8.4;

import "../Volume.sol";

/**
    This is a contract used for testing only. If you want to deploy Volume to the 
    Mainnet, please deploy Volume.sol.
 */

contract TestVolume is Volume {
    
    constructor (address escrowAcc) Volume(escrowAcc) { }

    // === Test Functions === //
    function getLastRefuel() external view returns (uint256) {
        return lastRefuel;
    }

    function getPrevFuelTank() external view returns (uint256) {
        return prevFuelTank;
    }

    function getBlocksTravelled() external view returns (uint256) {
        return block.number - lastRefuel;
    }

    function getBlockNumber() external view returns (uint256) {
        return block.number;
    }

    function getFuelPile() external view returns (uint256) {
        return fuelPile;
    }

    function setFuelTank(uint256 newFuel) external {
        fuelTank = newFuel;
    }

    function getEscrowAddress() external view returns (address) {
        return escrow;
    }

    function _getLPAddress() internal pure override returns (address) {
        return 0xe420279D0bf665073f069cB576c28d6F77633b20; // dummy address 
    }
    
    function getLPAddress() external view returns (address) {
        return 0xe420279D0bf665073f069cB576c28d6F77633b20;
    }
    
    // === End of Test Functions === //
}