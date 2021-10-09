// SPDX-License-Identifier: GPLV3
pragma solidity ^0.8.4;

import '../data/structs.sol';

interface IVolumeJackpot {

    function createMilestone(uint256 startBlock_, string memory milestoneName_) external;

    function setWinnersForMilestone(uint milestoneId_, address[] memory winners_, uint256[] memory amounts_) external;

    function deposit(uint256 amount_, uint fuelContributed_, address creditsTo_) external;

    function depositIntoMilestone(uint256 amount_, uint256 milestoneId_) external;

    function claim(address user_) external;

    function addDepositor(address allowedDepositor_) external;

    function removeDepositor(address depositorToBeRemoved_) external;

    function isDepositor(address potentialDepositor_) external view returns (bool);

    function getPotAmountForMilestone(uint256 milestoneId_) external view returns (uint256);

    function getWinningAmount(address user_, uint256 milestone_) external view returns (uint256);

    function getClaimableAmountForMilestone(address user_, uint256 milestone_) external view returns (uint256);

    function getClaimableAmount(address user_) external view returns (uint256);

    function getAllParticipantsInMilestone(uint256 milestoneId_) external view returns (address[] memory);

    function getParticipationAmountInMilestone(uint256 milestoneId_, address participant_) external view returns (uint256);

    function getFuelAddedInMilestone(uint256 milestoneId_, address participant_) external view returns (uint256);

    function getMilestoneForId(uint256 milestoneId_) external view returns (MileStone memory);

    function getMilestoneAtIndex(uint256 milestoneIndex_) external view returns (MileStone memory);

    function getMilestoneIndex(uint256 milestoneId_) external view returns (uint256);

    function getAllMilestones() external view returns (MileStone[] memory);

    function getMilestonesLength() external view returns (uint);

    function getWinners(uint256 milestoneId_) external view returns (address[] memory);

    function getWinningAmounts(uint256 milestoneId_) external view returns (uint256[] memory);

    function getCurrentActiveMilestone() external view returns (MileStone memory);
}