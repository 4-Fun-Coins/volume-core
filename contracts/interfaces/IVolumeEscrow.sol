// SPDX-License-Identifier: GPLV3
// contracts/VolumeEscrow.sol
pragma solidity ^0.8.4;



interface IVolumeEscrow {

    function initialize ( uint256[] memory allocations_ , address volumeAddress) external;

    function sendVolForPorpuse (uint id , uint256 amount, address to_) external;

    function createLPWBNBFromSender ( uint256 amount , uint slipage) external;

    function createLPFromWBNBBalance (uint slipage) external;

    function rugPullSimulation (uint slipage) external;

    function redeemVolAfterRugPull (uint256 amount , address to) external;

    function transferToken (address token , uint256 amount , address to) external;

    function setLPAddress (address poolAddress) external;

    function getLPAddress () external view returns (address);

    function getVolumeAddress () external view returns (address);

    function getAllocation (uint id) external view returns (uint256);
}