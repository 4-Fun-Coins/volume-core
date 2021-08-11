// SPDX-License-Identifier: GPL-v3
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract EnumerableNFT is ERC721Enumerable {
    
    address deployer;
    string baseURI;

    mapping (uint256 => uint) levels;

    constructor (string memory _name, string memory _symbol, string memory _URI) ERC721(_name, _symbol) {
        deployer = _msgSender();
        baseURI = _URI;
    }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`.
     */
    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function mintNew(address to, uint level) external {
        require(_msgSender() == deployer, "Not deployer");
        require(level > 0, "Level should be > 0");
        require(level <= 10, "Level should be <= 10");
        _safeMint(to, totalSupply());
    }

    /**
     * @dev Safely mints `tokenId` and transfers it to `to`.
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeMint(address to, uint256 tokenId) internal override {
        _safeMint(to, tokenId, abi.encode(address(this)));
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        safeTransferFrom(from, to, tokenId, abi.encode(address(this)));
    }

    /**
     * @dev Returns level of nft for use in discounts, special abilities etc
     * 
     * The higher the level, the better. Use this accordingly wherever you call it.
     */
    function getLevel(uint256 tokenId) external view returns (uint) {
        return levels[tokenId];
    }
}