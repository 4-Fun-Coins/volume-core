const Big = require('big-js');
const truffleAssert = require('truffle-assertions');

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

        let balanceBefore;
        let balanceAfter;

        let fuelBefore;
        let fuelAfter;

        const { toWei } = web3.utils;
        const { fromWei } = web3.utils;
        const { hexToUtf8 } = web3.utils;

        describe('Basic functionality', () => {
            before(async () => {
                volume = await Volume.deployed();
    
                initialFuel = fromWei(await volume.getFuel.call());
            });
    
            it('Should mint 1 000 000 000 to deployer', async () => {
                let ownerBalance = fromWei(await volume.balanceOf.call(owner));
                assert.equal(ownerBalance, '1000000000');
            });
    
            it('Should deduct 100 from owner', async () => {
                await volume.transfer(receiver, toWei('100'), {from: owner});
                let ownerBalance = fromWei(await volume.balanceOf.call(owner));
                assert.equal(ownerBalance, '999999900');
            });
    
            it('Should add 99.99 to receiver', async () => {
                let receiverBalance = fromWei(await volume.balanceOf.call(receiver));
                assert.equal(receiverBalance, '99.99');
            });
    
            it('Should have reduced the total supply by 0.01', async () => {
                let totalSupply = fromWei(await volume.totalSupply.call());
                assert.equal(totalSupply, '999999999.99');
            });
    
            it('Should increase the fuelPile by 0.018', async () => {
                // Get fuelPile
                let fuelPile = fromWei(await volume.getFuelPile.call());
    
                // One block was mined, so the fuel should be 1 less than initial, i.e. 6307199
                runningFuelPile = runningFuelPile.plus('0.0189215988921597');
    
                assert.equal(fuelPile, '0.0189215988921597');
            });
    
            it('Should increase the fuelPile by 0.04', async () => {
                // Send transaction that will result in 0.09 fuel added
                await volume.transfer(receiver, toWei('150'), {from: owner});
    
                // Get fuelPile
                let fuelPile = fromWei(await volume.getFuelPile.call());
    
                assert.equal(fuelPile, '0.047303993761625706');
            });

            it('Should not deduct fees for Escrow interactions', async () => {
                // TODO - test when escrow is deployed here
                
            });

            it('Should not deduct fees for LP interactions', async () => {
                // TODO - test when escrow is deployed here
            });
        });

        describe('Direct refuel', () => {
            before(async () => {
                balanceBefore = fromWei(await volume.balanceOf.call(owner));
                fuelBefore = fromWei(await volume.getFuel.call());
                await volume.directRefuel(toWei('100'), {from: owner});
            });

            it('Should have burned 100 tokens', async () => {
                balanceAfter = fromWei(await volume.balanceOf.call(owner));
                assert.equal(new Big(balanceBefore).minus(balanceAfter).toString(), '100');
            });

            it('Should have increased the fuelTank by 188', async () => {
                fuelAfter = fromWei(await volume.getFuel.call());
                assert.equal(new Big(fuelAfter).minus(fuelBefore).toString(), '188');
            });
        });

        describe('Bulk run', () => {
            before(async () => {
                await volume.transfer(receiver, toWei('50'), {from: owner});

                let transactions = [];

                for(let i = 0; i < 7; i++) {
                    transactions.push(await volume.transfer(receiver, toWei('1385000.8'), {from: owner}));
                }

                for (let i=0; i < 5; i++) {
                    transactions.push(await volume.transfer(owner, toWei('1385000.8'), {from: receiver}));
                }

                await Promise.all(transactions);

                // We should have ~ 10 "fuel" added to the tank at this point
            });

            it('Diff between initialFuel and currentFuel should be -3323', async () => {
                // Get fuelTank
                let fuelTank = fromWei(await volume.getFuel.call());    

                // Fuel diff
                let fuelDiff = initialFuel - fuelTank;

                assert.equal(fuelDiff, -3323);
            });

            it('Total Fuel added should be 3339 blocks', async () => {
                // Get the fuel added so far
                let totalFuelAdded = fromWei(await volume.getTotalFuelAdded.call());

                assert.equal(totalFuelAdded, 3339);
            });

            it('Owner fuel added should be 2026 blocks', async () => {
                let ownerFuelAdded = fromWei(await volume.getUserFuelAdded.call(owner));

                assert.equal(ownerFuelAdded, 2026);
            });

            it('Reciever fuel added should be 1312 blocks', async () => {
                let receiverFuelAdded = fromWei(await volume.getUserFuelAdded.call(receiver));

                assert.equal(receiverFuelAdded, 1312);
            });
        });

        // Make sure we scale so the whale has the same impact as the normal user.
        describe('Simulate whale', async () => {
            let gasBeforeWhaleMove;
            before(async () => {
                gasBeforeWhaleMove = fromWei(await volume.getTotalFuelAdded.call());
                await volume.transfer(receiver, toWei('76923076.92'), {from: owner});
            });

            it('Gas added should have increased by 15776', async () => {
                let gasAfterWhaleMove = fromWei(await volume.getTotalFuelAdded.call());
                let diffInGas = gasAfterWhaleMove - gasBeforeWhaleMove;

                assert.equal(diffInGas, 15776);
            });
        });

        describe('Crash test', () => {
            before(async () => {
                // Set fuel tank to 1
                await volume.setFuelTank(toWei('0'));
            });

            it('Should revert on transfer', async () => {
                ownerBalanceCrashTestBefore = await volume.balanceOf.call(owner);

                await truffleAssert.reverts(
                    volume.transfer.call(receiver, toWei('100'), {from: owner}),
                    'Crashed - please redeem your tokens'
                );
            });

            it('Should return the same balance as before transfer', async () => {
                ownerBalanceCrashTestAfter = await volume.balanceOf.call(owner);

                assert.equal(fromWei(ownerBalanceCrashTestBefore), fromWei(ownerBalanceCrashTestAfter));
            });

            it('Should return empty fuel tank', async () => {
                let fuelTank = await volume.getFuel.call();

                assert.equal(fromWei(fuelTank), 0);
            });

            it('Should be able to send to escrow', async () => {
                // TODO - test when escrow is deployed here
            });

            it('Should be able to send from LP pool', async () => {
                // TODO - test when escrow is deployed here
            });
        });
    });
});