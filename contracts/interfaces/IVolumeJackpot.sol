// SPDX-License-Identifier: GPLV3
pragma solidity ^0.8.4;

struct MileStone {
    uint256 startBlock;
    uint256 endBlock;
    string name;
    uint256 amountInPot;
}

interface IVolumeJackpot {

    function createMilestone (uint256 startBlock_ , string memory milestoneName_) external;

    function setWinnersForMilestone ( uint milestoneId_ , address[] memory winners_ , uint256[] memory amounts_) external;

    function deposit (uint256 amount_, address creditsTo_) external;

    function depositIntoMilestone (uint256 amount_ , uint256 milestoneId_) external;

    function claim (address user_) external;

    function addDepositer (address allowedDepositer_) external;

    function removeDepositer (address depositerToBeRemoved_) external;

    function burnItAfterCrash () external;

    function isDepositer (address potentialDepositer_) external view returns (bool);

    function getPotAmountForMilestonre ( uint256 milestoneId_) external view returns (uint256);

    function getClaimableAmountForMilestone (address user_, uint256 milestone_) external view returns (uint256 claimableAmount);

    function getClaimableAmount (address user_) external view returns (uint256 claimableAmount);

    function getAllParticipantsInMilestone (uint256 milestoneId_) external view returns(address[] memory);

    function getParticipationAmountInMilestone (uint256 milestoneId_ , address participant_) external view returns (uint256);

    function getMilestoneForId (uint256 milestoneId_) external view returns (MileStone memory);

    function getMilestoneatIndex (uint256 milestoneIindex_) external view returns (MileStone memory);

    function getMilestoneIndex (uint256 milestoneId_) external view returns (uint256);

    function getAllMilestones () external view returns (MileStone[] memory );

    function getMilestonesLength () external view returns (uint);

    function getWinners (uint256 milestoneId_) external view returns (address[] memory);

    function getWinningAmounts (uint256 milestoneId_) external view returns (uint256[] memory);

    function isWinner (uint256 milestoneId_, address user_) external view returns (bool);

    function getCurrentActiveMilestone() external view returns(MileStone memory);
}