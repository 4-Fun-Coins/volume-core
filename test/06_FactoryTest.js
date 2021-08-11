const Factory = artifacts.require("VolumeNFTFactory");

const Big = require('big-js');
const { Category } = require('./classes/Category');
const NFTJson = require('../build/contracts/EnumerableNFT.json');
const { fromWei } = web3.utils;


const PREDETERMINED_URI = "https://images.unsplash.com/photo-1626327547387-b2663804dd50?ixlib=rb-1.2.1&ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8&auto=format&fit=crop&w=1489&q=";
const CAT_1_NAME = "AstroPunks";
const CAT_1_SYMBOL = "AP";
const CAT_1_SUPPLY = 10;

let NFT;
let factory;
let category;

contract('NFTFactory', async (accounts) => {

    let owner = accounts[0];

    before(async () => {
        factory = await Factory.deployed();
    });

    it('Should create an NFT and add it to a category', async () => {
        let categories = await factory.getAllCategories();

        assert.equal(categories.length, 0);

        await factory.addCategory(CAT_1_NAME, CAT_1_SYMBOL, CAT_1_SUPPLY, PREDETERMINED_URI);

        categories = await factory.getAllCategories();

        assert.equal(categories.length, 1);

        category = new Category(categories[0]);
    });

    it('Should have the correct category name', () => {
        assert.equal(category.name, CAT_1_NAME);
    });

    it('Should have the correct category number', () => {
        assert.equal(category.number, 0);
    });

    it('Should have created 10 NFTs and minted them to Factory', async () => {
        NFT = new web3.eth.Contract(NFTJson.abi, category.address);
        let totalSupply = await NFT.methods.totalSupply().call();
        assert.equal(totalSupply, 10);

        let factoryBalance = await NFT.methods.balanceOf(Factory.address).call();
        assert.equal(factoryBalance, 10);
    });

    describe('Testing the get by address', () => {
        it('Should return the category by address', async () => {
            let categoryByAddress = await factory.getCategoryByAddress(category.address);
            assert.equal(categoryByAddress.nftAddress, category.address, `Expected ${categoryByAddress.address} to be equal to ${category.address}`);
        });
    
        it('Should return an empty category if given wrong address', async () => {
            let categoryByAddress = await factory.getCategoryByAddress(Factory.address);
            assert.equal(categoryByAddress.nftAddress, 0x0);
        });
    });

    describe('Testing multiple categories', () => {

        before(async () => {
            let tempCat = [];

            for (let i = 1; i < 11; i++) {
                tempCat.push(factory.addCategory(CAT_1_NAME + i, CAT_1_SYMBOL + i, CAT_1_SUPPLY, PREDETERMINED_URI));
            }

            await Promise.all(tempCat);
        });

        it('Should have created 10 more categories', async () => {
            categories = await factory.getAllCategories();
            assert.equal(categories.length, 11);
        });

        it('Should have the correct names', async () => {
            for (let i = 1; i < categories.length; i++) {
                assert.equal(categories[i].name, CAT_1_NAME + i);
            }
        });

        it('Should have 10 NFTs in each category', async () => {
            let factoryBalances = await Promise.all(categories.map((cat) => {
                let nft = new web3.eth.Contract(NFTJson.abi, cat.nftAddress);
                return nft.methods.balanceOf(Factory.address).call();
            }));

            for (let i = 1; i < categories.length; i++) {
                assert.equal(factoryBalances[i], 10);
            }
        });
    });
});