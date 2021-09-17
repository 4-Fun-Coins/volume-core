// SPDX-License-Identifier: GPL-v3
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./utils/VolumeOwnable.sol";
import "./token/IBEP20.sol";
import "./token/SafeBEP20.sol";
import "./interfaces/IVolumeBEP20.sol";
import "./interfaces/IVolumeEscrow.sol";
import './data/structs.sol';
import "./interfaces/IVolumeJackpot.sol";

contract VolumeJackpot is VolumeOwnable, ReentrancyGuard, IVolumeJackpot {

    using Address for address payable;
    using SafeBEP20 for IBEP20;

    uint256 constant public MAX_INT_TYPE = type(uint256).max;
    uint256 constant public BASE = 10 ** 18;

    address immutable escrow;

    // block number where this allocation of jackpot starts also referred to as the milestoneId in the code
    MileStone[] milestones;
    //   milestoneId => index of this milestone in the milestones array 
    mapping(uint256 => uint256) milestoneIndex; // startBlock => index
    //   milestoneId => address => amount
    mapping(uint256 => mapping(address => uint256)) participantsAmounts; // this will hold the index of each participant in the Milestone mapping (structs can't hold nested mapping)
    // milestoneID => user => fuelAddedToMilestone
    mapping(uint256 => mapping(address => uint256)) participantsAddedFuel;
    //   milestoneId => milestoneParticipants[]
    mapping(uint256 => address[]) milestoneParticipants; // this will hold the index of each participant in the Milestone mapping (structs can't hold nested mapping)

    //   milestoneId => winner => amount
    mapping(uint256 => mapping(address => uint256)) milestoneWinnersAmounts;
    mapping(uint256 => mapping(address => bool)) winningsClaimed;


    // for historical data
    // milestoneId => winners[]
    mapping(uint256 => address[]) winners;
    // milestoneId => winningAmounts[]
    mapping(uint256 => uint256[]) winningAmounts;

    mapping(address => bool) depositors;

    constructor (address multisig_, address escrow_)  VolumeOwnable(multisig_) {
        escrow = escrow_;

        IVolumeEscrow(escrow_).setVolumeJackpot(address(this));
        // link this jackpot to the escrow

        _createMilestone(0, 'genesis');
        // we occupy the 0 index with a dummy milestone (all indexes are stored in a uint mapping so every entry that was not created will return 0)
    }


    /**
     * @dev Throws if called by any account who is not a depositor the volumeBEP contract is always a depositor
     */
    modifier onlyDepositors() {
        require(depositors[_msgSender()] || _msgSender() == IVolumeEscrow(escrow).getVolumeAddress(), "Caller does not have the right to deposit");
        _;
    }

    modifier onlyWhenFlying(){
        require(IVolumeBEP20(IVolumeEscrow(escrow).getVolumeAddress()).getFuel() > 0, "VolumeJackpot");
        _;
    }

    /**
        @dev creates a new milestone at the start block , this will end the previous milestone at the startBlock-1
     */
    function createMilestone(uint256 startBlock_, string memory milestoneName_) override external onlyWhenFlying {
        require(_msgSender() == owner() || _msgSender() == IVolumeEscrow(escrow).getVolumeAddress(), "VolumeJackpot: only owner or volume BEP20 can call");
        require(block.number < startBlock_, "VolumeJackpot: start block needs to be in to future ");
        if (milestones.length == 1) {
            _createMilestone(startBlock_, milestoneName_);
        } else {
            // set endblock for the previous milestone
            milestones[milestones.length - 1].endBlock = startBlock_ - 1;
            // create a new one 
            _createMilestone(startBlock_, milestoneName_);
        }
    }


    /**
        the order of the array is sorted according to the leader board
        winners should be the top fuel suppliers
        winners are halved each milestone down to a minimum of 10;
        pot is divided as follow
        first spot : 25%
        second place: 15%
        third place: 10%
        rest of participants 50% / rest 
    */
    function setWinnersForMilestone(uint milestoneId_, address[] memory winners_, uint256[] memory amounts_) override external onlyOwner onlyWhenFlying {
        require(milestoneIndex[milestoneId_] != 0, "VolumeJackpot: This milestone does not exist");
        require(milestones[milestoneIndex[milestoneId_]].endBlock < block.number, "VolumeJackpot: milestone is not over yet");

        require(winners_.length == amounts_.length, 'VolumeJackpot: winners_ length != amounts_ length');
        require(winners[milestoneId_].length == 0 && winningAmounts[milestoneId_].length == 0, "VolumeJackpot: winners already set");
        winners[milestoneId_] = winners_;
        winningAmounts[milestoneId_] = amounts_;

        uint256 totalAmounts;
        uint256 prevParticipation = MAX_INT_TYPE;

        // max winners is 1000 for the first milestone 
        // next milestones will half the number of winners
        for (uint i = 0; i < winners_.length; i++) {
            require(prevParticipation >= participantsAmounts[milestoneId_][winners_[i]], 'VolumeJackpot: not sorted properly');
            milestoneWinnersAmounts[milestoneId_][winners_[i]] = amounts_[i];
            totalAmounts += amounts_[i];
            prevParticipation = participantsAmounts[milestoneId_][winners_[i]];
        }
        require(totalAmounts == milestones[milestoneIndex[milestoneId_]].amountInPot);
    }

    /**
        @dev Deposits amount_ to active milestone's jackpot and gives its credit to creditsTo_
         fuelContributed_ is the amounts of blocks this deposit has added (used for stats and other calculations)
     */
    function deposit(uint256 amount_, uint fuelContributed_, address creditsTo_) override external nonReentrant onlyDepositors onlyWhenFlying {
        require(IVolumeEscrow(escrow).getVolumeAddress() != address(0), "VolumeJackpot: volume BEP20 address was not set yet");
        IBEP20(IVolumeEscrow(escrow).getVolumeAddress()).safeTransferFrom(_msgSender(), address(this), amount_);

        MileStone memory activeMilestone = getCurrentActiveMilestone();

        require(activeMilestone.startBlock != 0, "VolumeJackpot: no active milestone");

        milestones[milestoneIndex[activeMilestone.startBlock]].amountInPot += amount_;
        milestones[milestoneIndex[activeMilestone.startBlock]].totalFuelAdded += fuelContributed_;

        // if this creditor does not exists in our map
        if (participantsAmounts[activeMilestone.startBlock][creditsTo_] == 0) {
            milestoneParticipants[activeMilestone.startBlock].push(creditsTo_);
        }

        participantsAmounts[activeMilestone.startBlock][creditsTo_] += amount_;
        participantsAddedFuel[activeMilestone.startBlock][creditsTo_] += fuelContributed_;
    }

    /**
    @dev use this function to deposit an amount of volume to this milestone rewards 
        could be useful if we decide to use a portion of the marketing or  reward volume allocation as an incentive
        by adding it to the next milestone reward
     */
    function depositIntoMilestone(uint256 amount_, uint256 milestoneId_) override external onlyDepositors onlyWhenFlying {
        require(milestoneIndex[milestoneId_] != 0, 'VolumeJackPot: milestone does not exist');
        require(milestones[milestoneIndex[milestoneId_]].endBlock >= block.number, "VolumeJackPot: milestone already passed");

        require(IVolumeEscrow(escrow).getVolumeAddress() != address(0), "VolumeJackpot: volume BEP20 address was not set yet");
        IBEP20(IVolumeEscrow(escrow).getVolumeAddress()).safeTransferFrom(_msgSender(), address(this), amount_);

        milestones[milestoneIndex[milestoneId_]].amountInPot += amount_;
    }

    /**
        claims the pending rewards for this user
     */
    function claim(address user_) override external onlyWhenFlying {
        require(milestones.length > 1, "VolumeJackpot: no milestone set");

        uint256 amountOut;
        for (uint i = 1; i < milestones.length; i++) {
            amountOut += getClaimableAmountForMilestone(user_, milestones[i].startBlock);
            winningsClaimed[milestones[i].startBlock][user_] = true;
        }

        require(amountOut > 0, 'VolumeJackpot: nothing to claim');

        require(bytes(IVolumeBEP20(IVolumeEscrow(escrow).getVolumeAddress()).getNicknameForAddress(user_)).length > 0, 'VolumeJackpot: you have to claim a nickname first');

        IBEP20(IVolumeEscrow(escrow).getVolumeAddress()).safeTransfer(user_, amountOut);
    }


    /**
        @dev
     */
    function addDepositor(address allowedDepositor_) override external onlyOwner {
        depositors[allowedDepositor_] = true;
    }

    /**
        @dev
     */
    function removeDepositor(address depositorToBeRemoved_) override external onlyOwner {
        depositors[depositorToBeRemoved_] = false;
    }

    /**
        can only be called by escrow and can only be called when we crash 
        will burn all the balance we have here any unclaimed winnings will be lost for ever
     */
    function burnItAfterCrash() override external {
        require(_msgSender() == escrow || _msgSender() == owner(), "VolumeJackpot: only escrow or owner can call this ");
        require(IVolumeBEP20(IVolumeEscrow(escrow).getVolumeAddress()).getFuel() == 0, "VolumeJackpot: we have not crashed yet");
        uint256 balance = IBEP20(IVolumeEscrow(escrow).getVolumeAddress()).balanceOf(address(this));
        if (balance > 0)
            IVolumeBEP20(IVolumeEscrow(escrow).getVolumeAddress()).directBurn(balance);
    }

    /**
        @dev
     */
    function isDepositor(address potentialDepositor_) override external view returns (bool){
        return depositors[potentialDepositor_];
    }

    /**
        `milestoneID` is the start block of the milestone
     */
    function getPotAmountForMilestone(uint256 milestoneId_) override external view returns (uint256){
        return milestones[milestoneIndex[milestoneId_]].amountInPot;
    }

    /*
        for historical data 
    */
    function getWinningAmount(address user_, uint256 milestone_) override external view returns (uint256){
        return milestoneWinnersAmounts[milestone_][user_];
    }

    /**
    
     */
    function getClaimableAmount(address user_) override external view returns (uint256 claimableAmount) {
        for (uint i = 1; i < milestones.length; i++) {
            claimableAmount += getClaimableAmountForMilestone(user_, milestones[i].startBlock);
        }
    }

    function getAllParticipantsInMilestone(uint256 milestoneId_) override external view returns (address[] memory) {
        return milestoneParticipants[milestoneId_];
    }

    function getParticipationAmountInMilestone(uint256 milestoneId_, address participant_) override external view returns (uint256){
        return participantsAmounts[milestoneId_][participant_];
    }

    function getFuelAddedInMilestone(uint256 milestoneId_, address participant_) override external view returns (uint256){
        return participantsAddedFuel[milestoneId_][participant_];
    }

    function getMilestoneForId(uint256 milestoneId_) override external view returns (MileStone memory){
        return milestones[milestoneIndex[milestoneId_]];
    }

    function getMilestoneAtIndex(uint256 milestoneIndex_) override external view returns (MileStone memory){
        return milestones[milestoneIndex_];
    }

    function getMilestoneIndex(uint256 milestoneId_) override external view returns (uint256){
        return milestoneIndex[milestoneId_];
    }

    function getAllMilestones() override external view returns (MileStone[] memory) {
        return milestones;
    }

    function getMilestonesLength() override external view returns (uint) {
        return milestones.length;
    }

    function getWinners(uint256 milestoneId_) override external view returns (address[] memory) {
        return winners[milestoneId_];
    }

    function getWinningAmounts(uint256 milestoneId_) override external view returns (uint256[] memory){
        return winningAmounts[milestoneId_];
    }

    /**
      *     Returns the amount available to claim by the user_ for milestone_
      */
    function getClaimableAmountForMilestone(address user_, uint256 milestone_) override public view returns (uint256 claimableAmount){
        if (!winningsClaimed[milestone_][user_]) {
            claimableAmount = milestoneWinnersAmounts[milestone_][user_];
        } else {
            claimableAmount = 0;
        }
    }

    function getCurrentActiveMilestone() override public view returns (MileStone memory) {

        for (uint i = 1; i < milestones.length; i++) {// starting to count from 1 is not a typo the 0 is filled with a dummy milestone
            if (milestones[i].startBlock <= block.number && milestones[i].endBlock >= block.number) {// if this is true this is the current milestone
                // add this amount to amountInPot
                return milestones[i];
            }
        }
        // should never happen
        return milestones[0];
    }

    function _createMilestone(uint256 start, string memory name) internal {
        milestones.push(
            MileStone(
                start,
                MAX_INT_TYPE,
                name,
                0,
                0
            ));
        milestoneIndex[start] = milestones.length - 1;
    }
}