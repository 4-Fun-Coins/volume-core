// SPDX-License-Identifier: GPLV3
pragma solidity ^0.8.4;

struct MileStone {
    uint256 startBlock;
    uint256 endBlock;
    string name;
    uint256 amountInPot; // total Vol deposited for this milestone rewards
    uint256 totalFuelAdded; // total fuel added during this milestone
}

struct UserFuel {
    address user;
    uint256 fuelAdded;
}

struct Listing {
    address nftAddress;
    uint256 id;
    uint256 price;
    uint status; // 0 - empty listing, 1 - waiting for nft, 2 - listed

    address owner;
    uint256 listingNumber;

    bool mutex;
}