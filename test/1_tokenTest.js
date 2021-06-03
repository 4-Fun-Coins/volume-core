const Big = require('big-js');

const {calcRelativeDiff} = require("../libraries/math");
const Volume = artifacts.require('TestVolume');

const errorDelta = 10 ** -8;

contract('TestVolume', async (accounts) => {

    describe('Token', () => {
        let volume;
        let owner = accounts[0];
        let receiver = accounts[1];
        let initialFuel;
        let runningFuelPile = new Big(0);

        let ownerBalanceCrashTestBefore;
        let ownerBalanceCrashTestAfter;

        const { toWei } = web3.utils;
        const { fromWei } = web3.utils;
        const { hexToUtf8 } = web3.utils;

        describe('Basic functionality', () => {
            before(async () => {
                volume = await Volume.deployed();
    
                initialFuel = await volume.getFuel.call();
            });
    
            it('Should mint 1 000 000 to deployer', async () => {
                let ownerBalance = await volume.balanceOf.call(owner);
                assert.equal(fromWei(ownerBalance), '1000000');
            });
    
            it('Should deduct 100 from owner', async () => {
                await volume.transfer(receiver, toWei('100'), {from: owner});
                let ownerBalance = await volume.balanceOf.call(owner);
                assert.equal(fromWei(ownerBalance), '999900');
            });
    
            it('Should add 99.99 to receiver', async () => {
                let receiverBalance = await volume.balanceOf.call(receiver);
                assert.equal(fromWei(receiverBalance), '99.99');
            });
    
            it('Should have reduced the total supply by 0.01', async () => {
                let totalSupply = await volume.totalSupply.call();
                assert.equal(fromWei(totalSupply), '999999.99');
            });
    
            it('Should increase the fuelPile by 0.06', async () => {
                // Get fuelPile
                let fuelPile = fromWei(await volume.getFuelPile.call());
    
                // One block was mined, so the fuel should be 1 less than initial, i.e. 6307199
                let predictedFuelAdded = new Big(6307199).times(0.01/1000000);
                runningFuelPile = runningFuelPile.plus(predictedFuelAdded);
    
                assert.equal(fuelPile, predictedFuelAdded.toString());
            });
    
            it('Should increase the fuelPile by 0.09', async () => {
                // Send transaction that will result in 0.09 fuel added
                await volume.transfer(receiver, toWei('150'), {from: owner});
    
                // Get fuelPile
                let fuelPile = fromWei(await volume.getFuelPile.call());
    
                // One block was mined, so the fuel should be 1 less than initial, i.e. 6307199
                let predictedFuelAdded = new Big(6307198).times(0.015/999999.99);
                runningFuelPile = runningFuelPile.plus(predictedFuelAdded);
    
                let relDiff = calcRelativeDiff(predictedFuelAdded.toString(), fuelPile.toString());
    
                assert.isAtMost(relDiff.toNumber(), 1); // Addition could be off by 1% at most
            });
        });

        describe('Bulk run', () => {
            before(async () => {
                await volume.transfer(receiver, toWei('50'), {from: owner});

                let transactions = [];

                for(let i = 0; i < 7; i++) {
                    transactions.push(await volume.transfer(receiver, toWei('1385.8'), {from: owner}));
                }

                for (let i=0; i < 5; i++) {
                    transactions.push(await volume.transfer(owner, toWei('1385.8'), {from: receiver}));
                }

                await Promise.all(transactions);

                // We should have ~ 10 "fuel" added to the tank at this point
            });

            it('Diff between initialFuel and currentFuel should be -4', async () => {
                // Get fuelTank
                let fuelTank = fromWei(await volume.getFuel.call());    

                // Fuel diff
                let fuelDiff = fromWei(initialFuel) - fuelTank;

                assert.equal(fuelDiff, 5);
            });

            it('Total Fuel added should be 10 blocks', async () => {
                // Get the fuel added so far
                let totalFuelAdded = fromWei(await volume.getTotalFuelAdded.call());

                assert.equal(totalFuelAdded, 10);
            });

            it('Owner fuel added should be 6 blocks', async () => {
                let ownerFuelAdded = fromWei(await volume.getPersonalFuelAdded.call(owner));

                assert.equal(ownerFuelAdded, 6);
            });

            it('Reciever fuel added should be 4 blocks', async () => {
                let receiverFuelAdded = fromWei(await volume.getPersonalFuelAdded.call(receiver));

                assert.equal(receiverFuelAdded, 4);
            });
        });

        // For this test - please set the initial fuel in the constructor
        // to 1, or a low value, so you can empty it faster.
        describe('Crash test', () => {
            before(async () => {
                // Set fuel tank to 1
                await volume.setFuelTank(toWei('0'));
            });

            it('Should return false on transfer', async () => {
                ownerBalanceCrashTestBefore = await volume.balanceOf.call(owner);

                let transfer = await volume.transfer.call(receiver, toWei('100'), {from: owner});

                assert.equal(transfer, false);
            });

            it('Should return the same balance as before transfer', async () => {
                ownerBalanceCrashTestAfter = await volume.balanceOf.call(owner);

                assert.equal(fromWei(ownerBalanceCrashTestBefore), fromWei(ownerBalanceCrashTestAfter));
            });

            it('Should return empty fuel tank', async () => {
                let fuelTank = await volume.getFuel.call();

                assert.equal(fromWei(fuelTank), 0);
            });
        });
    });
});