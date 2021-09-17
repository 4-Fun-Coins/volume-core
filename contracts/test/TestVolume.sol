// SPDX-License-Identifier: GPL-v3
pragma solidity ^0.8.4;

import "../Volume.sol";

/**
    This is a contract used for testing only. If you want to deploy Volume to the 
    Mainnet, please deploy Volume.sol.
 */

contract TestVolume is Volume {
    uint256 private lastBlock;
    constructor (address escrowAcc, address mulitisig, address volumeJackpot) Volume(escrowAcc, mulitisig, volumeJackpot) {}

    // === Test Functions === //
    // we use this to push blocks forward in local environments
    function updateBlock() external returns (uint256) {
        lastBlock = block.number;
        return lastBlock;
    }

    function getCurrentBlock() external view returns (uint256){
        return block.number;
    }

    function getLastRefuel() external view returns (uint256) {
        return lastRefuel;
    }

    function getBlocksTravelled() external view returns (uint256) {
        return block.number - lastRefuel;
    }

    function getBlockNumber() external view returns (uint256) {
        return block.number;
    }

    function setFuelTank(uint256 newFuel) external {
        require(block.chainid != 56, "not available on main net");
        fuelTank = newFuel;
    }

    function getEscrowAddress() external view returns (address) {
        return escrow;
    }

    function getLPAddress() external view returns (address) {
        return _getLPAddress();
    }

    // === End of Test Functions === //
}