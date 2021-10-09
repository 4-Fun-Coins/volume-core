// SPDX-License-Identifier: GPLV3
pragma solidity ^0.8.4;

    struct MileStone {
        uint256 startBlock; // start block
        uint256 endBlock; // endblock 
        string name;
        uint256 amountInPot; // total Vol deposited for this milestone rewards
        uint256 totalFuelAdded; // total fuel added during this milestone
    }