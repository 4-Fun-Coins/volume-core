// SPDX-License-Identifier: GPL-v3
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract VolumeMarketplace is Context, IERC721Receiver {
    
    using SafeMath for uint256;

    bool addressMutex;

    modifier _addressLock() {
        require(!addressMutex);

        addressMutex = true;
        _;
        addressMutex = false;
    }

    modifier _listingLock(address _owner, uint256 _listingNumber) {
        require(listingExists(_owner, _listingNumber), "This listing does not exist");
        uint256 listingIndex = _findIndexOfListingNumber(_owner, _listingNumber);

        Listing storage _listing = listings[_owner][listingIndex];

        require(!_listing.mutex, "Listing is currently being updated");
        _listing.mutex = true;
        _;
        _listing.mutex = false;
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

    address[] activeAddresses;

    mapping(address => Listing[]) listings;
    uint256 totalNumListings;
    mapping(address => uint256) listingNumbers;

    address volumeAddress;

    constructor(address _volumeAddress) {
        volumeAddress = _volumeAddress;
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) override external returns (bytes4) {
        // Find the listing
        (address _nftAddress) = abi.decode(data, (address));
        uint256 listingNum = findOwnerListingNumberByNFTAddressAndId(from, _nftAddress, tokenId);

        // Make sure the status is 1
        require(listings[from][listingNum].status == 1, "No listing created yet - please create a listing first");

        // Change the status to 2 (listed)
        listings[from][listingNum].status = 2;

        return IERC721Receiver.onERC721Received.selector;
    }

    function addListing(address _nft, uint256 _id, uint256 price) external {
        if(!hasActiveListing(_msgSender()))
            _addAddress(_msgSender());

        // Add listing to the end of the array with status = 1 (waiting for NFT)
        listings[_msgSender()].push(Listing(_nft, _id, price, 1, _msgSender(), listingNumbers[_msgSender()], false));
        totalNumListings++;
        listingNumbers[_msgSender()]++;

        // Send the NFT here
        IERC721 nft = IERC721(_nft);
        nft.safeTransferFrom(_msgSender(), address(this), _id);
    }

    function ownerRemoveListingByNumber(uint256 _listingNumber) _listingLock(_msgSender(), _listingNumber) external {
        uint256 listingIndex = _findIndexOfListingNumber(_msgSender(), _listingNumber);

        // Owner is removing - send back the NFT
        IERC721 nft = IERC721(listings[_msgSender()][listingIndex].nftAddress);
        nft.safeTransferFrom(address(this), _msgSender(), listings[_msgSender()][listingIndex].id);

        _removeListing(_msgSender(), listingIndex);
    }

    function buyListing(address _owner, uint256 _listingNumber) _listingLock(_owner, _listingNumber) external {
        require(_msgSender() != _owner, "Already own this NFT");
        uint256 listingIndex = _findIndexOfListingNumber(_owner, _listingNumber);

        Listing storage listing = listings[_owner][listingIndex];
        // Transfer VOLUME to owner, then transfer NFT to buyer
        IERC20 volume = IERC20(volumeAddress);

        require(volume.balanceOf(_msgSender()) >= listing.price, "Insufficient VOL balance");

        if (volume.transferFrom(_msgSender(), _owner, listing.price)) {
            // Successfully transferred volume, send NFT to buyer
            IERC721 nft = IERC721(listing.nftAddress);
            nft.safeTransferFrom(address(this), _msgSender(), listing.id);

            _removeListing(_owner, listingIndex);
        }
    }

    // TODO - add buy with custom token

    function _removeListing(address _owner, uint256 _listingIndex) internal {
        uint256 numListings = listings[_owner].length;

        listings[_owner][_listingIndex] = listings[_owner][numListings - 1];
        listings[_owner].pop();
        totalNumListings--;

        if(!hasActiveListing(_owner)){
            _removeAddress(_owner);
        }
    }

    function hasActiveListing(address _owner) public view returns (bool) {
        return findOwnerListings(_owner).length > 0;
    }

    function findOwnerListings(address _owner) public view returns (Listing[] memory) {
        return listings[_owner];
    }

    function findOwnerListingByNFTAddressAndId(address _owner, address _nft, uint256 _id) external view returns (Listing memory) {
        Listing[] memory ownerListings = findOwnerListings(_owner);
        uint256 ownerNumListings = ownerListings.length;

        for (uint256 i = 0; i < ownerNumListings; i++) {
            if (ownerListings[i].nftAddress == _nft && ownerListings[i].id == _id)
                return ownerListings[i];
        }

        revert ("Owner Listing: Owner does not own an nft with that address and ID");
    }

    function findOwnerListingNumberByNFTAddressAndId(address _owner, address _nft, uint256 _id) public view returns (uint256) {
        Listing[] memory ownerListings = findOwnerListings(_owner);
        uint256 ownerNumListings = ownerListings.length;

        for (uint256 i = 0; i < ownerNumListings; i++) {
            if (ownerListings[i].nftAddress == _nft && ownerListings[i].id == _id)
                return i;
        }

        revert ("Listing Number: Owner does not own an nft with that address and ID");
    }

    function findListingByOwnerAddressAndListingNumber(address _owner, uint256 _listingNumber) public view returns (Listing memory) {
        require(listingExists(_owner, _listingNumber), "This listing does not exist");

        for (uint256 i = 0; i < listings[_owner].length; i++) {
            if (listings[_owner][i].listingNumber == _listingNumber)
                return listings[_owner][i];
        }

        return Listing(address(0), 0, 0, 0, address(0), 0, false);
    }

    function listingExists(address _owner, uint256 _listingNumber) public view returns (bool) {
        for (uint256 i = 0; i < listings[_owner].length; i++) {
            if (listings[_owner][i].listingNumber == _listingNumber)
                return true;
        }

        return false;
    }

    function getAllListings() external view returns (Listing[] memory) {
        Listing[] memory allListings = new Listing[](totalNumListings);
        uint256 tempCount = 0;
        for (uint256 i = 0; i < activeAddresses.length; i++) {
            address activeAddress = activeAddresses[i];
            for (uint256 j = 0; j < listings[activeAddress].length; j++) {
                allListings[tempCount] = listings[activeAddress][j];
                tempCount++;
            }
        }

        return allListings;
    }

    function getActiveAddresses() public view returns (address[] memory) {
        return activeAddresses;
    }

    // Helper functions
    function _addAddress(address _a) _addressLock internal {
        activeAddresses.push(_a);
    }

    function _removeAddress(address _a) _addressLock internal {
        for (uint256 i = 0; i < activeAddresses.length; i++) {
            if (activeAddresses[i] == _a) {
                // Copy last element here
                activeAddresses[i] = activeAddresses[activeAddresses.length - 1];
                // Delete last element
                activeAddresses.pop();
            }
        }
    }

    function _findIndexOfListingNumber(address _owner, uint256 _listingNumber) internal view returns (uint256) {
        require (listingExists(_owner, _listingNumber), "Listing does not exist for address");

        for (uint256 i = 0; i < listings[_owner].length; i++) {
            if (listings[_owner][i].listingNumber == _listingNumber)
                return i;
        }

        return 0;
    }
}