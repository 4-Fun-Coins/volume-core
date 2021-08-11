const NFT = artifacts.require("EnumerableNFT");
const truffleAssert = require('truffle-assertions');

const PREDETERMINED_URI = "https://images.unsplash.com/photo-1626327547387-b2663804dd50?ixlib=rb-1.2.1&ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8&auto=format&fit=crop&w=1489&q=";
const PREDETERMINED_LEVEL = 8;

const { fromWei } = web3.utils;

let nft;
let tokenIds = [];

let tokenLevels = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];

contract('NFT', async (accounts) => {
    let owner = accounts[0];
    let nonOwner = accounts[1];

    before(async () => {
        nft = await NFT.deployed();

        // Mint new NFT to owner
        await nft.mintNew(owner, PREDETERMINED_LEVEL);
        tokenIds.push(0);
    });

    it('Should have minted to owner', async () => {
        let ownerBalance = await nft.balanceOf(owner);
        assert.equal(ownerBalance, 1);
    });

    it('Token 0 should belong to owner', async () => {
        let ownerOf = await nft.ownerOf(0);
        assert.equal(ownerOf, owner);
    });

    it('Should have total supply of 1', async () => {
        let totalSupply = await nft.totalSupply();
        assert.equal(totalSupply, 1);
    });

    it('Should return the correct level', async () => {
        let actualLevel = await nft.getLevel(0);
        assert.equal(actualLevel, PREDETERMINED_LEVEL);
    });

    it('Should mint 10 more NFTs to owner', async () => {
        for (let i = 0; i < tokenLevels.length; i++) {
            tokenIds.push(tokenIds.length);
            await nft.mintNew(owner, tokenLevels[i]);
        }

        let ownerBalance = await nft.balanceOf(owner);
        assert.equal(ownerBalance, 11);
    });

    it('Should all have the correct URIs', async () => {
        let URIs = await Promise.all(tokenIds.map(async (tokenId) => {
            return nft.tokenURI(tokenId);
        }));

        for (let i = 0; i < URIs.length; i++) {
            assert.equal(URIs[i], PREDETERMINED_URI + i);
        }
    });

    it('Should all have the correct levels', async () => {
        let levels = await Promise.all(tokenIds.map((tokenId) => {
            return nft.getLevel(tokenId);
        }));

        for (let i = 1; i < levels.length; i++) {
            assert.equal(levels[i].toNumber(), tokenLevels[i-1]);
        }
    });

    it('Should fail if mint called by non-deployer', async () => {
        await truffleAssert.reverts(
            nft.mintNew(nonOwner, 5, {from: nonOwner}),
            'Not deployer'
        );
    });

    it('Should fail to mint nft out of level range', async () => {
        await truffleAssert.reverts(
            nft.mintNew(nonOwner, 0, {from: owner}),
            'Level should be > 0'
        );

        await truffleAssert.reverts(
            nft.mintNew(nonOwner, 11, {from: owner}),
            'Level should be <= 10'
        );
    });
});