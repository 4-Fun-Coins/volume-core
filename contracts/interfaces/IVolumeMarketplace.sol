// SPDX-License-Identifier: GPLV3
pragma solidity ^0.8.4;

import '../data/structs.sol';

interface IVolumeMarketplace {
    function addListing(address _nft, uint256 _id, uint256 price) external;
    function ownerRemoveListingByNumber(uint256 _listingNumber) external;
    function buyListing(address _owner, uint256 _listingNumber) external;
    function hasActiveListing(address _owner) external view returns (bool);
    function findOwnerListings(address _owner) external view returns (Listing[] memory);
    function findOwnerListingByNFTAddressAndId(address _owner, address _nft, uint256 _id) external view returns (Listing memory);
    function findOwnerListingNumberByNFTAddressAndId(address _owner, address _nft, uint256 _id) external view returns (uint256);
    function findListingByOwnerAddressAndListingNumber(address _owner, uint256 _listingNumber) external view returns (Listing memory);
    function listingExists(address _owner, uint256 _listingNumber) external view returns (bool);
    function getAllListings() external view returns (Listing[] memory);
    function getActiveAddresses() external view returns (address[] memory);
}