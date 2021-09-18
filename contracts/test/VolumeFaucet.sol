// SPDX-License-Identifier: GPL-v3
pragma solidity ^0.8.4;

import "../utils/VolumeOwnable.sol";
import "../token/IBEP20.sol";

contract VolumeFaucet is VolumeOwnable {
    uint256 constant ONE_DAY_IN_BLOCKS = 24 * 60 * 60 / 3;  // 3seconds per block one day worth of blocks

    uint256 claimableAmount = 10000 * 10 ** 18;
    address immutable volume;
    mapping(address => uint256) public lastClaimedOn;

    constructor (address owner_, address volumeAddress) VolumeOwnable(owner_){
        volume = volumeAddress;
    }

    function sendVolTo(uint256 amount, address receiver) external onlyOwner {
        IBEP20(volume).transfer(receiver, amount);
    }

    function ChangeClaimableAmount(uint256 newAmount) external onlyOwner {
        claimableAmount = newAmount;
    }

    function resetCounterFor(address user_) external onlyOwner {
        lastClaimedOn[user_] = 0;
    }

    function claimTestVol() external {
        require(canClaim(_msgSender()), "Can only claim once a day");
        IBEP20(volume).transfer(_msgSender(), claimableAmount);
        lastClaimedOn[_msgSender()] = block.number;
    }

    function getLastClaimedOn(address user_) external view returns (uint256) {
        return lastClaimedOn[user_];
    }

    function canClaim(address user_) public view returns (bool) {
        return block.number - lastClaimedOn[user_] > ONE_DAY_IN_BLOCKS;
    }
}
