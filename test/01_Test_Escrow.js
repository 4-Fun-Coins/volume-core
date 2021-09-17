const truffleAssert = require('truffle-assertions');

const Volume = artifacts.require('TestVolume'); //TODO change to Test in production
const VolumeEscrow = artifacts.require("VolumeEscrow");
const VolumeJackpot = artifacts.require("VolumeJackpot");

const {toWei} = web3.utils;

const idoAllocation = toWei('375000000');
const lpAllocation = toWei('375000000');
const rewardsAllocation = toWei('100000000');
const devAllocation = toWei('100000000');
const marketingAllocation = toWei('50000000');

let escrow;
let volume;
let jackpot;

contract('VolumeEscrow', async (accounts) => {
    const multisig = accounts[0];
    const account1 = accounts[1];
    const account2 = accounts[2];

    before(async () => {
        escrow = await VolumeEscrow.deployed();
        volume = await Volume.deployed();
        jackpot = await VolumeJackpot.deployed();
    });

    describe('VolumeEscrow deploy and basic functionality', () => {
        it("Should Have the right Owner ", async function () {
            const currentOwner = await escrow.owner.call();
            assert.equal(currentOwner, multisig, `Owner does not match expected ${multisig} but got ${currentOwner} instead`)
        });

        it('Should have all the volume supply', async function () {
            const balance = await volume.balanceOf.call(escrow.address);
            const totalSupply = await volume.totalSupply.call();
            assert.equal(balance.toString(), totalSupply.toString(), `The escrow should have all the volume supply`);
        });

        it('Multisig should be an lpCreator', async function () {
            const result = await escrow.isLPCreator.call(multisig);
            assert(result, `Multisig is not a creator`);
        });

        it('Should have volumeJackpot linked correctly ', async function () {
            const currentJackpotAddress = await escrow.getJackpotAddress.call();
            assert.equal(jackpot.address, currentJackpotAddress, `jackpot address is not valid expected ${jackpot.address} but got ${currentJackpotAddress} instead`);
        });

        it('Should add lpCreator', async function () {
            await escrow.addLPCreator(account1);
            const isLPCreator = await escrow.isLPCreator.call(account1);
            assert(isLPCreator, `expected ${account1} to be an LP creator but it was not`);
        });

        it('Should remove LP creator', async function () {
            await escrow.removeLPCreator(account1);
            const isLPCreator = await escrow.isLPCreator.call(account1);
            assert(!isLPCreator, `expected ${account1} to not be an LP creator but it was`);
        });

        it('Should fail when trying to set LPAddress before init or called from non owner', async function () {
            await truffleAssert.reverts(
                escrow.setLPAddress(account2, {from: account1}),
                `Ownable: caller is not the owner`
            );
            await truffleAssert.reverts(
                escrow.setLPAddress(account2),
                `VolumeEscrow: needs to be initialized first`
            );
        });
    });

    describe('VolumeEscrow initialization', () => {

        it('Should fail miserably when non owner try to init', async function () {
            await truffleAssert.reverts(
                escrow.initialize(
                    [
                        toWei('375000000'),
                        toWei('375000000'),
                        toWei('100000000'),
                        toWei('100000000'),
                        toWei('50000000')
                    ],
                    volume.address.toString(),
                    {from: account1}
                ),
                `Ownable: caller is not the owner`
            );
        });

        it("Should init normally and set the right allocations", async function () {
            await escrow.initialize(
                [
                    toWei('375000000'),
                    toWei('375000000'),
                    toWei('100000000'),
                    toWei('100000000'),
                    toWei('50000000')
                ],
                volume.address.toString(),
                {from: multisig}
            );

            const ido = await escrow.getAllocation(0);
            const lp = await escrow.getAllocation(1);
            const rewards = await escrow.getAllocation(2);
            const dev = await escrow.getAllocation(3);
            const marketing = await escrow.getAllocation(4);

            assert.equal(ido, idoAllocation, `ido allocation not right`);
            assert.equal(lp, lpAllocation, `lp allocation not right`);
            assert.equal(rewards, rewardsAllocation, `rewards allocation not right`);
            assert.equal(dev, devAllocation, `dev allocation not right`);
            assert.equal(marketing, marketingAllocation, `marketing allocation not right`);

            const volAddress = await escrow.getVolumeAddress.call();
            assert.equal(volAddress, volume.address, `volume address should set to ${volume.address} but we got ${volAddress} instead`);
        });

    });

    describe("VolumeEscrow: After init functions checks", () => {
        it('Should fail to call transferToken before setting LP address', async function () {
            await truffleAssert.reverts(
                escrow.transferToken(account1, toWei("10"), account2),
                `VolumeEscrow: Need to initialize and set LPAddress first`
            )
        });

        it('Should set LP address normally', async function () {
            await escrow.setLPAddress(account2);
            const lpAddress = await escrow.getLPAddress();
            assert.equal(lpAddress, account2, `lpAddress expected ${account2} but got ${lpAddress} instead`);
        });

        it('Should fail to change LPAddress after being set', async function () {
            await truffleAssert.reverts(
                escrow.setLPAddress(account2),
                `VolumeEscrow: LP was already set`
            );
        });

        it('Should fail to change Jackpot after being set', async function () {
            await truffleAssert.reverts(
                escrow.setVolumeJackpot(jackpot.address),
                `VolumeEscrow: volumeJackpot was already set`
            );
        });
    });

    describe('VolumeEscrow Transfers', () => {
        it('Should transfer the IDO allocation and subtract it from allocation', async function () {
            await escrow.sendVolForPurpose(0, idoAllocation, account1);
            const balance = await volume.balanceOf(account1);
            assert.equal(balance, idoAllocation, `expected balance of ${account1} to be ${idoAllocation} but it was ${balance}`);
            const left = await escrow.getAllocation(0);
            assert.equal(left, toWei('0'), `expected idoAllocation of ${account1} ${toWei('0')} but got ${left} instead`);
        });

        it('Should fail when trying to transfer the LP allocation', async function () {
            await truffleAssert.reverts(
                escrow.sendVolForPurpose(1, lpAllocation, account1),
                `The liquidity allocation can only be used by the LP creation function`
            )
        });

        it('Should fail when sending amount bigger than allocation', async function () {
            await truffleAssert.reverts(
                escrow.sendVolForPurpose(2, lpAllocation, account1), // should fail because allocation of rewards is only 100mils
                `VolumeEscrow: amount is bigger than allocation`
            )
        });

        it('Should fail when calling sendForPurpose from non owner', async function () {
            await truffleAssert.reverts(
                escrow.sendVolForPurpose(2, rewardsAllocation, account1, {from: account2}),
                `Ownable: caller is not the owner`
            )
        });

        it('Should fail when trying to send volume through the bep20 transfer method', async function () {
            await truffleAssert.reverts(
                escrow.transferToken(volume.address, toWei("10"), account2),
                "VolumeEscrow: can't transfer those from here"
            );
            const balance = await volume.balanceOf(account2);
            assert.equal(balance, toWei('0'), `account ${account2} should have balance of zero but had ${balance} instead`);
        });
    });

});