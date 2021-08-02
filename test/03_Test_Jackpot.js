const { reverts } = require('truffle-assertions');
const truffleAssertions = require('truffle-assertions');
const truffleAssert = require('truffle-assertions');
const FuelCalculator = require("./helpers/FuelCalculator");
const WinnersCalculator = require("./helpers/WinningCalculator");
const toWeiBN = FuelCalculator.toWeiBN;
const { BN ,toWei,fromWei} =  web3.utils;

const Volume = artifacts.require('TestVolume'); //TODO change to Test in production
const VolumeEscrow = artifacts.require("VolumeEscrow");
const VolumeJackpot = artifacts.require("VolumeJackpot");

const eps = new BN('0'); // margin of error will be less than eps/10**18 (0 means no margin for errors conparisons are strict)
const addressZero = "0x0000000000000000000000000000000000000000";
const idoAllocation = toWeiBN('375000000');
const lpAllocation = toWeiBN('375000000');
const rewardsAllocation = toWeiBN('100000000');
const devAllocation = toWeiBN('100000000');
const marketingAllocation = toWeiBN('50000000');

let escrow;
let volume;
let jackpot;

class Milestone {
    constructor(array){
        this.startBlock = array[0].toString();
        this.endBlock = array[1].toString();
        this.name = array[2];
        this.potAmount = array[3].toString();
        this.totalFuelAdded = array[4]
    }
}

contract('VolumeJackpot', async (accounts) => {
    const multisig = accounts[0];
    const user1 = accounts[1];
    const user2 = accounts[2];
    const user3 = accounts[3];
    const user4 = accounts[4];
    const user5 = accounts[5];
    const user6 = accounts[6];
    const user7 = accounts[7];

    const users = [user1,user2,user3,user4,user5,user6,user7];

    let milestone1;
    let milestone2;

    const baseParticipation = toWeiBN('10000000');

    before(async () => {
        escrow = await VolumeEscrow.deployed();
        volume = await Volume.deployed();
        jackpot = await VolumeJackpot.deployed();

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
        
        await escrow.sendVolForPurpose(0, idoAllocation , multisig);
        await escrow.sendVolForPurpose(2, rewardsAllocation , multisig);
        await escrow.sendVolForPurpose(3, devAllocation , multisig);
        await escrow.sendVolForPurpose(4, marketingAllocation , multisig);

        const currentBlock = await volume.getBlockNumber();
        milestone1 = currentBlock.add(new BN('2'));
        milestone2 = milestone1.add(new BN('8'));

        await  volume.methods['setTakeOffBlock(uint256,uint256,string)'](milestone1.toString(),'2592000' , 'Journey To Mars: The red Planet');
        await jackpot.createMilestone(milestone2 , 'Journey To Jupiter');
    });

    const batchParticipation = async (baseParticipation) => {
        await Promise.all(users.map(async (user , index) => {
            const multiplier = index+1;
            await volume.directRefuelFor(baseParticipation.mul(new BN(multiplier+'')),user , {from : multisig});
        }));
    }

    it('Should supply the right amount to jackpot', async () => {      
        await batchParticipation(baseParticipation);

        await Promise.all(
            users.map(async (user,index) =>{
                const multiplier = index+1;
                const expectedParticipation = baseParticipation.mul(new BN(''+multiplier)).sub( baseParticipation.mul(new BN(''+multiplier)).div(new BN('2')));
                const participation = await jackpot.getParticipationAmountInMilestone(milestone1 , user);
                assert.equal(expectedParticipation.toString() , participation.toString() , "expected participation is not right at index="+index)
            })
        );
        await volume.fly(); // will push the next block ending the first milestone 
    });
 
    const  testSettingWinners = async (milestone , nextMilestone ) => {
        const milestoneIndex = await jackpot.getMilestoneIndex.call(milestone);

        const totalAmount = new BN(new Milestone(await jackpot.getMilestoneForId(milestone)).potAmount);
        assert.equal(totalAmount.toString(),'140000000000000000000000000' ,"total amount do not match");

        const participants = await jackpot.getAllParticipantsInMilestone(milestone);
        const participantsAndAmounts = await Promise.all(
            participants.map(async element => {
                return {
                    address : element,
                    amount : await jackpot.getParticipationAmountInMilestone(milestone ,element)
                }
            })
        );
        const {winners , amounts} = WinnersCalculator.getWinnersAndAmounts(
            participantsAndAmounts,
            totalAmount,
            participants.length >=  1000 ? new BN('1000') : new BN(participants.length+'')
            );
        
        const exprectedOrder = [user7,user6,user5,user4,user3,user2,user1];

        const expectedAmounts = [
            new BN('35000000000000000000000000').mul(milestoneIndex),
            new BN('21000000000000000000000000').mul(milestoneIndex),
            new BN('14000000000000000000000000').mul(milestoneIndex),
            new BN('17500000000000000000000000').mul(milestoneIndex),
            new BN('17500000000000000000000000').mul(milestoneIndex),
            new BN('17500000000000000000000000').mul(milestoneIndex),
            new BN('17500000000000000000000000').mul(milestoneIndex)
        ];

        const randomized = [user1,user3,user6,user5,user7,user4,user2];

        await truffleAssertions.reverts(
            jackpot.setWinnersForMilestone(milestone , randomized , amounts),
            'VolumeJackpot: not sorted properly'
        )
        
        if(milestoneIndex == 1){
            await truffleAssert.reverts(
                jackpot.claim(user2),
                `VolumeJackpot: nothing to claim`
            );
        }

        await jackpot.setWinnersForMilestone(milestone , winners , amounts);

        truffleAssert.reverts(
            jackpot.setWinnersForMilestone(nextMilestone , winners , amounts),
        )

        for (let index = 0 ; index < exprectedOrder.length ; index++) {
            const claimableAmount = await jackpot.getClaimableAmount(exprectedOrder[index]);
            assert.equal(exprectedOrder[index] , winners[index]);
            assert.equal(amounts[index].toString() , expectedAmounts[index].div(milestoneIndex).toString());
            assert.equal(claimableAmount.toString() , expectedAmounts[index].toString());
        } 
    }

    let milestone3;
    it('should set the winners correctly', async () => {
    
        await testSettingWinners(milestone1 , milestone2);

        await batchParticipation(baseParticipation);

        const currentBlock = await volume.getBlockNumber.call();


        milestone3 = currentBlock.add(new BN('3'));

        await jackpot.createMilestone(milestone3 , 'Journey To Saturn');

        await volume.fly();
        await testSettingWinners(milestone2 , milestone3);

    });

    it('Should claim normally only after nickname is claimed', async () => {
        let balanceBefore = await volume.balanceOf(user1);

        await truffleAssert.reverts(
            jackpot.claim(user1),
            `VolumeJackpot: you have to claim a nickname first`
        );

        await volume.transfer(user1, await volume.getNicknamePrice(), {from : multisig});

        await volume.claimNickname('nickname', {from : user1});

        await jackpot.claim(user1);

        let balanceAfter = await volume.balanceOf(user1);
        let expectedBalance = balanceBefore.add(new BN('17500000000000000000000000').mul(new BN('2'))); // because we ran both milestones so this user participated twice

        assert.equal(balanceAfter.toString(),expectedBalance.toString(),'balance after is not as expected' );

        await truffleAssert.reverts(
            jackpot.claim(user1),
            `VolumeJackpot: nothing to claim`
        )
    });

    it('fuel is being tracked correctly', async () => {
        const checkUsersFuels = async (user) => {
            const totalFuelByUser = await volume.getUserFuelAdded.call(user);
            const totalFuelByUserTracked1 = await jackpot.getFuelAddedInMilestone.call(milestone1 , user);
            const totalFuelByUserTracked2 = await jackpot.getFuelAddedInMilestone.call(milestone2 , user);
            const totalFuelByUserTracked3 = await jackpot.getFuelAddedInMilestone.call(milestone3 , user);
            const totalFuelTrackedUser = totalFuelByUserTracked1.add(totalFuelByUserTracked2).add(totalFuelByUserTracked3);
            assert.equal(totalFuelByUser.toString(),totalFuelTrackedUser.toString() , 'fuel added not tracked correctly');
        }

        const totalFuel = await volume.getTotalFuelAdded.call();
        const totalFuelInMilestone1 = new Milestone(await jackpot.getMilestoneForId(milestone1)).totalFuelAdded;
        const totalFuelInMilestone2 = new Milestone(await jackpot.getMilestoneForId(milestone2)).totalFuelAdded;
        const totalFuelInMilestone3 = new Milestone(await jackpot.getMilestoneForId(milestone3)).totalFuelAdded;
        const totalFuelTracked = new BN(totalFuelInMilestone1).add(new BN(totalFuelInMilestone2)).add(new BN(totalFuelInMilestone3))
        assert.equal(totalFuel.toString(),totalFuelTracked , 'fuel added not tracked correctly');

        await Promise.all(
            users.map(user => checkUsersFuels(user))
        )
    });
});