const NFT = artifacts.require("EnumerableNFT");
const truffleAssert = require('truffle-assertions');

const PREDETERMINED_URI = "https://images.unsplash.com/photo-1626327547387-b2663804dd50?ixlib=rb-1.2.1&ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8&auto=format&fit=crop&w=1489&q=";

const { fromWei } = web3.utils;

let nft;
let tokenIds = [];

contract('NFT', async (accounts) => {
    let owner = accounts[0];
    let nonOwner = accounts[1];

    before(async () => {
        nft = await NFT.deployed();

        // Mint new NFT to owner
        await nft.mintNew(owner);
        tokenIds.push(0);
    });

    it('Should have minted to owner', async () => {
        let ownerBalance = await nft.balanceOf(owner);
        assert.equal(ownerBalance, 1);
    });

    it('Token 0 should belong to owner', async () => {
        let ownerOf = await nft.ownerOf(tokenIds[0]);
        assert.equal(ownerOf, owner);
    });

    it('Should have total supply of 1', async () => {
        let totalSupply = await nft.totalSupply();
        assert.equal(totalSupply, 1);
    });

    it('Should mint 10 more NFTs to owner', async () => {
        let mints = [];
        for (let i = 0; i < 10; i++) {
            mints.push(nft.mintNew(owner));
            tokenIds.push(i+1);
        }

        await Promise.all(mints);

        let ownerBalance = await nft.balanceOf(owner);
        assert.equal(ownerBalance, 11);
    });

    it('Should all have the correct URIs', async () => {
        let correct = true;

        let URIs = await Promise.all(tokenIds.map(async (id) => {
            return nft.tokenURI(id);
        }));

        for (let i = 0; i < URIs.length; i++) {
            if (URIs[i] !== PREDETERMINED_URI + i)
                correct = false;
        }

        assert(correct);
    });

    it('Should fail if mint called by non-deployer', async () => {
        await truffleAssert.reverts(
            nft.mintNew(nonOwner, {from: nonOwner}),
            'Not deployer'
        );
    });
});