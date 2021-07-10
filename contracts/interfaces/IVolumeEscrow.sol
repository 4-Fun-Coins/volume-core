// SPDX-License-Identifier: GPLV3
// contracts/VolumeEscrow.sol
pragma solidity ^0.8.4;

interface IVolumeEscrow {

    function initialize ( uint256[] memory allocations_ , address volumeAddress_) external;
 
    function sendVolForPorpuse (uint id_ , uint256 amount_, address to_) external;

    function addLPCreator(address newLpCreator_) external;

    function removeLPCreator(address lpCreatorToRemove_) external;

    function createLPWBNBFromSender ( uint256 amount_ , uint slipage_) external;

    function createLPFromWBNBBalance (uint slipage_) external;

    function rugPullSimulation (uint slipage_) external;

    function redeemVolAfterRugPull (uint256 amount_ , address to_) external ;

    function transferToken (address token_ , uint256 amount_ , address to_) external;

    function setLPAddress (address poolAddress_) external;

    function setVolumeJackpot (address volumeJackpotAddress_) external;

    function getLPAddress () external view returns (address);

    function getVolumeAddress () external view returns (address);

    function getJackpotAddress () external view returns (address);

    function getAllocation (uint id_) external view returns (uint256);

    function estimateRedeamOutForIn(uint256 amountIn_) external view returns (uint);
}

