// SPDX-License-Identifier: GPL-v3
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "./token/EnumerableNFT.sol";
import "./interfaces/IVolumeMarketplace.sol";
import "./token/IBEP20.sol";

contract VolumeNFTFactory is Context, IERC721Receiver {
    
    address owner;
    address treasury;
    address volume;

    struct Category {
        string name;
        address nftAddress;
        uint256 categoryNumber;
        uint256 basePrice;
        uint256 totalSupply;
    }

    Category[] categories;

    struct Listing {
        address nftAddress;
        uint256 tokenId;

        bool mutex;
    }

    mapping(uint256 => Listing[]) listings;

    constructor() {
        owner = _msgSender();
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) override external returns (bytes4) {
        (address _nftAddress) = abi.decode(data, (address));
        // TODO - make it buyable
        Category memory category = getCategoryByNFTAddress(_nftAddress);

        // Add to available
        listings[category.categoryNumber].push(Listing(category.nftAddress, tokenId, false));

        return IERC721Receiver.onERC721Received.selector;
    }

    /**
      * @dev The _URI should resolve to the storage address of the tokens.
      * Please use IPFS and number each image from 1 to the amount of NFTs you want to create.
      * For instance if your storage location is {"path/to/images/"} you want to name each image
      * their number in the enumeration. So image 1 will be called "0" with a full path of {"path/to/images/0"}.
      * The {_URI} will then be set to {"path/to/images"}.
      * Please see {EnumerableNFT.sol-_baseURI}
     */
    function addCategory(string memory _name, string memory _symbol, uint256 _numTokens, string memory _URI, uint256 _basePrice) external {
        require (_msgSender() == owner);

        EnumerableNFT newNFT = new EnumerableNFT(_name, _symbol, _URI);

        categories.push(Category(_name, address(newNFT), categories.length, _basePrice, _numTokens));

        for (uint256 i = 0; i < _numTokens; i++) {
            newNFT.mintNew(address(this));
        }
    }

    function addCategoryThirdParty(string memory _name, string memory _symbol, uint256 _numTokens, string memory _URI) external {
        // TODO - add 3rd party nft creation
    }

    function getNumberOfCategories() external view returns (uint256) {
        return categories.length;
    }

    function getCategoryByNumber(uint256 _categoryNum) external view returns (Category memory) {
        require(_categoryNum < categories.length, "Category number out of bounds");

        return categories[_categoryNum];
    }

    function getAllCategories() external view returns (Category[] memory) {
        return categories;
    }

    function getCategoryByNFTAddress(address _address) public view returns (Category memory) {
        require(_categoryExistsForAddress(_address), "There is no category for this address");

        for (uint256 i = 0; i < categories.length; i++) {
            if (categories[i].nftAddress == _address) {
                return categories[i];
            }
        }

        return Category("", address(0), 2**256-1, 0, 0);
    }

    function buyNFTForNFTAddress(address _address) external {
        require(_availableForNFTAddress(_address));

        // Generate random number between 0 and the amount available, buy that index
        Category memory category = getCategoryByNFTAddress(_address);
        // TODO - continue here (decide if randomness will be on/off chain)
    }

    // Helper functions
    function _categoryExistsForAddress(address _address) internal view returns (bool) {
        for (uint256 i = 0; i < categories.length; i++) {
            if (categories[i].nftAddress == _address) {
                return true;
            }
        }

        return false;
    }

    function _availableForNFTAddress(address _address) internal view returns (bool) {
        Category memory category = getCategoryByNFTAddress(_address);
        return listings[category.categoryNumber].length > 0;
    }
}