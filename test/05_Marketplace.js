const Marketplace = artifacts.require("VolumeMarketplace");
const NFT = artifacts.require('EnumerableNFT');
const Volume = artifacts.require('TestVolume');
const truffleAssert = require('truffle-assertions');

const { fromWei, toWei } = web3.utils;

let marketplace;
let nft;
let listings;
let ownerListings;

contract('Marketplace', async (accounts) => {
    let marketplace = accounts[0];
    let user = accounts[1];
    let buyer = accounts[2];

    before(async () => {
        marketplace = await Marketplace.deployed();
        nft = await NFT.deployed();
        volume = await Volume.deployed();

        // Create 2 NFTs to test listings
        await nft.mintNew(user);
        await nft.mintNew(user);

        // approve marketplace to transfer
        await nft.approve(Marketplace.address, 0, {from: user});
        await nft.approve(Marketplace.address, 1, {from: user});
    });

    it('Should have approval to interact with token', async () => {
        let approval = await nft.getApproved(0);
        assert.equal(approval, Marketplace.address);
    })

    it('Should have no listings', async () => {
        listings = await marketplace.getAllListings();
        assert.equal(listings.length, 0);
    });

    describe('Adding Listing', () => {
        it('Should return empty array', async () => {
            await marketplace.getActiveAddresses();
        });

        it('Should add a listing for token 0', async () => {
            await marketplace.addListing(NFT.address, '0', toWei('1000000'), {from: user});
            listings = await marketplace.getAllListings();
            assert.equal(listings.length, 1);

            let ownerListings = await marketplace.findOwnerListings(user);
            assert.equal(ownerListings.length, 1);
        });

        it('Should have send the NFT to the Marketplace', async () => {
            let ownerOf = await nft.ownerOf(0);
            assert.equal(ownerOf, Marketplace.address);
        });
    
        it('Should have the correct listing information', async () => {
            assert.equal(listings[0].nftAddress, NFT.address);
            assert.equal(listings[0].id, 0);
            assert.equal(fromWei(listings[0].price), 1000000);
            assert.equal(listings[0].status, '2');
        });

        it('Should have added owner to activeAddresses', async () => {
            let activeAddresses = await marketplace.getActiveAddresses();
            assert.equal(activeAddresses[0], user);
        });

        it('Should fail when trying to relist the same token', async () => {
            await truffleAssert.reverts(
                marketplace.addListing(NFT.address, '0', toWei('1000000'), {from: user}),
                "ERC721: transfer of token that is not own."
            );
        });
    });

    describe('Removing listing', () => {
        it('Should remove the listing as owner', async () => {
            await marketplace.ownerRemoveListingByNumber(listings[0].listingNumber, {from: user});

            let ownerListings = await marketplace.findOwnerListings(user);
            assert.equal(ownerListings.length, 0);

            listings = await marketplace.getAllListings();
            assert.equal(listings.length, 0);
        });

        it('Should have removed owner from activeAddresses', async () => {
            let activeAddresses = await marketplace.getActiveAddresses();
            assert.equal(activeAddresses.length, 0);
        });

        it('Should have returned the NFT to the original owner', async () => {
            let ownerOf = await nft.ownerOf(0);
            assert.equal(ownerOf, user);
        });
    });

    describe('List both tokens and buy one', async () => {
        before(async () => {
            // Approve 0 again
            await nft.approve(Marketplace.address, 0, {from: user});

            // Add listing
            await marketplace.addListing(NFT.address, '0', toWei('1000000'), {from: user});
            await marketplace.addListing(NFT.address, '1', toWei('1000000'), {from: user});

            // Mint volume to the buyer
            await volume.mintTo(buyer, toWei('10000000'));
            // Approve marketplace spending
            await volume.approve(Marketplace.address, toWei('10000000'), {from: buyer});
        });

        it('Should have added 2 listings for owner', async () => {
            ownerListings = await marketplace.findOwnerListings(user);
            assert.equal(ownerListings.length, 2);
        });

        it('Should have the owner as an active address', async () => {
            let activeAddresses = await marketplace.getActiveAddresses();
            assert.equal(activeAddresses.length, 1);
            assert.equal(activeAddresses[0], user);
        });

        it('Should send the volume amount to the owner & the NFT to the buyer', async () => {
            await marketplace.buyListing(ownerListings[0].owner, ownerListings[0].listingNumber, {from: buyer});

            let balanceOfUser = await volume.balanceOf(user);
            assert.equal(fromWei(balanceOfUser), 1000000);

            let ownerOfNFT = await nft.ownerOf(ownerListings[0].id);
            assert.equal(ownerOfNFT, buyer);
            let nftBalanceOfBuyer = await nft.balanceOf(buyer);
            assert.equal(nftBalanceOfBuyer, 1);
        });

        it('Should have removed the sold listing', async () => {
            listings = await marketplace.getAllListings();
            assert.equal(listings.length, 1);
            assert.notEqual(listings[0].listingNumber, ownerListings[0].listingNumber);
        });

        it('Should still have the owner as an active address', async () => {
            let activeAddresses = await marketplace.getActiveAddresses();
            assert.equal(activeAddresses.length, 1);
            assert.equal(activeAddresses[0], user);
        });

        it('Should fail to repurchase the listing that has already been bought', async () => {
            await truffleAssert.reverts(
                marketplace.buyListing(ownerListings[0].owner, ownerListings[0].listingNumber, {from: buyer}),
                'This listing does not exist'
            );
        });
    });

    describe('Fail cases', () => {
        it('Should fail to purchase a listing with an insufficient balance', async () => {
            await truffleAssert.reverts(
                marketplace.buyListing(ownerListings[1].owner, ownerListings[1].listingNumber, {from: accounts[5]}),
                "Insufficient VOL balance"
            );
        });

        it('Should fail to remove a listing with invalid listing number', async () => {
            await truffleAssert.reverts(
                marketplace.ownerRemoveListingByNumber(ownerListings[0].listingNumber, {from: user}),
                "This listing does not exist"
            );
        });

        it('Should fail to find a listing with unlisted address and wrong listing number', async () => {
            await truffleAssert.reverts(
                marketplace.findListingByOwnerAddressAndListingNumber(buyer, ownerListings[0].listingNumber),
                "This listing does not exist"
            );
        });

        it('Should fail to find a listing with the wrong listing number but right address', async () => {
            await truffleAssert.reverts(
                marketplace.findListingByOwnerAddressAndListingNumber(user, ownerListings[0].listingNumber),
                "This listing does not exist"
            );
        });
    });
});