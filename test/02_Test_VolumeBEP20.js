const truffleAssert = require('truffle-assertions');
const FuelCalculator = require("./helpers/FuelCalculator");
const toWeiBN = FuelCalculator.toWeiBN;
const { BN ,toWei} =  web3.utils;

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
        this.potAmount = array[3].toString();
    }
}

contract('VolumeBEP20', async (accounts) => {
    const multisig = accounts[0];
    const mockLPAddress = accounts[1];
    const freeloader = accounts[2];
    const creditor = accounts[3];
    const user1 = accounts[4];
    const user2 = accounts[5];
    const user3 = accounts[6];
    const directBurner = accounts[7];

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
    });

    describe('Volume BEP20: deployement and basic functions', async function(){

        it('should transfer allocations from escrow to multisig', async function(){
            await escrow.sendVolForPorpuse(0, idoAllocation , multisig);
            await escrow.sendVolForPorpuse(2, rewardsAllocation , multisig);
            await escrow.sendVolForPorpuse(3, devAllocation , multisig);
            await escrow.sendVolForPorpuse(4, marketingAllocation.sub(toWeiBN('1000')) , multisig);
    
            const balance = await volume.balanceOf(multisig);
            const expectedBalance = idoAllocation
                .add(rewardsAllocation)
                .add(devAllocation)
                .add(marketingAllocation.sub(toWeiBN('1000')));
    
            assert.equal(balance.toString() , expectedBalance.toString(),
                            `exprected balance of multisig to be ${expectedBalance} but got ${balance} instead`
                        );
        });

        it('multisig escrow and jackpot should be freeloaders', async () => {
            assert(await volume.isFreeloader(escrow.address), 'Expected escrow to be a freeloader but it was not');
            assert(await volume.isFreeloader(multisig), 'Expected multisig to be a freeloader but it was not');
            assert(await volume.isFreeloader(jackpot.address), 'Expected jackpot to be a freeloader but it was not');
            assert(await volume.isFreeloader(volume.address), 'Expected volume to be a freeloader but it was not');
        });

        it('escrow and jackpot should be direct burners', async () => {
            assert(await volume.isDirectBurner(escrow.address), 'Expected escrow to be a directburner but it was not');
            assert(await volume.isDirectBurner(jackpot.address), 'Expected multisig to be a directburner but it was not');
        });

        it('should failt when trying to remove escrow , jackpot or multisig fron freeloaders' , async () => {
            await truffleAssert.reverts(
                volume.removeFreeloader(escrow.address),
                `Volume: escrow, jackpot and multisig will always be a freeloader`
            );

            await truffleAssert.reverts(
                volume.removeFreeloader(jackpot.address),
                `Volume: escrow, jackpot and multisig will always be a freeloader`
            );

            await truffleAssert.reverts(
                volume.removeFreeloader(multisig),
                `Volume: escrow, jackpot and multisig will always be a freeloader`
            );
        });

        it('Should fail to remove jackpot nd escrow from direct burners',async () => {
            await truffleAssert.reverts(
                volume.removeDirectBurner(escrow.address),
                `Volume: escrow and jackpot will always be a direct burner`
            );

            await truffleAssert.reverts(
                volume.removeDirectBurner(jackpot.address),
                `Volume: escrow and jackpot will always be a direct burner`
            );
        });

        it('Should add and remove custom freeloaders', async () => {
            await truffleAssert.reverts(
                volume.addFreeloader(freeloader,{from: user1}),
                `Volume: caller is not allowed`
            );

            await volume.addFreeloader(freeloader, {from: multisig});
            assert(await volume.isFreeloader(freeloader), 'should be a freeloader but was not');

            await truffleAssert.reverts(
                volume.addfuelCreditor(freeloader),
                'Volume: freeloaders can not be creditors at the same time remove it first'
            );

            await truffleAssert.reverts(
                volume.removeFreeloader(freeloader,{from: user1}),
                `Volume: caller is not allowed`
            );

            await volume.removeFreeloader(freeloader, {from: multisig});
            assert(!await volume.isFreeloader(freeloader), 'should not be a freeloader but was not');

            // put him back as freeloader we need it in next tests
            await volume.addFreeloader(freeloader, {from: multisig});
        });

        it('Should add and remove custom fuelCreditors and prevent creditors to be freeloaders', async () => {
            await truffleAssert.reverts(
                volume.addfuelCreditor(creditor,{from: user1}),
                `Volume: caller is not allowed`
            );

            await volume.addfuelCreditor(creditor, {from: multisig});
            assert(await volume.isFuelCreditor(creditor), 'should be a creditor but was not');
            
            await truffleAssert.reverts(
                volume.addFreeloader(creditor),
                'Volume: creditors can not be freeloaders at the same time remove it first'
            );

            await truffleAssert.reverts(
                volume.removefuelCreditor(creditor,{from: user1}),
                `Volume: caller is not allowed`
            );

            await volume.removefuelCreditor(creditor, {from: multisig});
            assert(!await volume.isFuelCreditor(creditor), 'should not be a creditor but was not');

            // put him back as freeloader we need it in next tests
            await volume.addfuelCreditor(creditor, {from: multisig});
        });

        it('Should add and remove custom durect burners', async () => {
            await truffleAssert.reverts(
                volume.addDirectBurner(directBurner,{from: user1}),
                `Volume: caller is not allowed`
            );

            await volume.addDirectBurner(directBurner, {from: multisig});
            assert(await volume.isDirectBurner(directBurner), 'Should be a directBurner but was not');

            await truffleAssert.reverts(
                volume.removeDirectBurner(directBurner,{from: user1}),
                `Volume: caller is not allowed`
            );

            await volume.removeDirectBurner(directBurner, {from: multisig});
            assert(!await volume.isDirectBurner(directBurner), 'Should not be a directBurner but was not');

            // put him back as freeloader we need it in next tests
            await volume.addDirectBurner(directBurner, {from: multisig});
        });

        it('Direct burner should be able to burn and non direct burners should fail', async () => {
            const totalSupply = await volume.totalSupply();
            const transfer = await volume.transfer(directBurner , toWei('100'));
            assert(transfer, 'should have returned true but did not');
            await volume.directBurn(toWei('60'), {from: directBurner});
            const balance = await volume.balanceOf(directBurner);
            const exprectedBalance = toWeiBN('40');
            assert.equal(balance.toString(),exprectedBalance.toString(), 'left balance is not right');

            const currentTotalSupply = await volume.totalSupply()
            const expectedTotalSupply = totalSupply.sub(toWeiBN('60'));
            assert.equal(currentTotalSupply.toString(), expectedTotalSupply.toString(), "total supply left is not right");

            await truffleAssert.reverts(
                volume.directBurn(toWei('1'), {from: user1}),
                `Volume: only direct burners`
            );
        });

        it('Should add LPAddress to creditor on setup and prevent it from being removed', async () => {
            await escrow.setLPAddress(mockLPAddress,{from : multisig});
            
            const isCreditor = await volume.isFuelCreditor(mockLPAddress);
            assert(isCreditor , 'should be creditor but was not');

            await truffleAssert.reverts(
                volume.addFreeloader(mockLPAddress),
                'Volume: creditors can not be freeloaders at the same time remove it first'
            );

            await truffleAssert.reverts(
                volume.removefuelCreditor(mockLPAddress),
                'Volume: LP pair shall always be a creditor'
            );
        });
    });

    describe('Volume BEP20: Before takeoff checks', async function(){

        it('should transfer without paying fuel', async () => {
            const beforeBalance = await volume.balanceOf(multisig);
            const beforeFuel = await volume.getFuel();
            let transfer = await volume.transfer(user1 , toWei('1000000') , {from: multisig});
            assert(transfer , "transfer should returned true but it did not");
            
            const user1Balance = await volume.balanceOf(user1);

            assert.equal(user1Balance.toString() , toWeiBN('1000000').toString(), `expected balance to be ${toWei('1000000')} but got ${user1Balance} instead` );

            transfer = await volume.transfer(user2, toWei('100'), {from: user1});
            assert(transfer , 'transfer should returned true but it did not');

            const user1Expectebalance = user1Balance.sub(toWeiBN('100'));

            const user1CurrentBalance = await volume.balanceOf(user1);

            const user2ExpectedBalance = toWeiBN('100');
            const user2Balance = await volume.balanceOf(user2);

            assert.equal(user1Expectebalance.toString() , user1CurrentBalance.toString(), 'expected user1 balance is not right');
            assert.equal(user2ExpectedBalance.toString() , user2Balance.toString(), 'expected user2 balance is not right');

            let currentFuel = await volume.getFuel();
            assert.equal(currentFuel.toString() , beforeFuel.toString() , "fuel should not have changed at all since we did not take off yet");

            const approved = await volume.approve(user2, toWei('100'), {from: user1});
            assert(approved, "should return true but it did not");
            const allowance = await volume.allowance(user1, user2);
            assert.equal(allowance.toString(), toWei('100').toString(), "expected allowance is not right");

            transfer = await volume.transferFrom(user1, user3, toWei('49'), {from: user2});
            assert(transfer, 'should have returned true but did not');

            const user3Balance = await volume.balanceOf(user3);
            assert.equal(user3Balance.toString() , toWei('49').toString(), `expected user3 balance to be ${toWei('49')} but got ${user3Balance}`);
            
            const restOfAllowance = await volume.allowance(user1, user2);
            const exprectedAllowance = toWeiBN('100').sub(toWeiBN('49'));
            assert.equal(restOfAllowance.toString(),exprectedAllowance.toString(), `expected rest of allowance to be ${exprectedAllowance} but got ${restOfAllowance}`);

            currentFuel = await volume.getFuel();
            assert.equal(currentFuel.toString() , beforeFuel.toString() , "fuel should not have changed at all since we did not take off yet");
        });

        it('should fail when calling direct fuel', async () => {
            await truffleAssert.reverts(
                volume.directRefuel(toWei('100'),{from: user1}),
                `Volume: You can't fuel before take off`
            );

            await truffleAssert.reverts(
                volume.directRefuelFor(toWei('100'), user2,{from: user1}),
                `Volume: You can't fuel before take off`
            );
        });

        it('should fail to claim a nickname', async () => {
            await truffleAssert.reverts(
                volume.claimNickname('nickname'),
                "Volume: we are not flying yet"
            )
        });

        it('length of getAllUsersLength should be 0',async ()=>{
            const length = await volume.getAllUsersLength();
            assert.equal(length.toString() , '1' , "expected length to be 0"); // because index 0 is occupied by address(0)
        });
    });

    let takeoffBlock;
    let nicknamePrice;
    describe("Volume BEP20: takeoff ", async () =>{

        it('should set start block', async () => {
            const currentBlock = await volume.getBlockNumber();
            takeoffBlock = currentBlock.add(new BN('2'));
            await volume.methods['setTakeOffBlock(uint256,uint256,string)'](takeoffBlock.toString(), '2592000', 'Journey to Mars: The red planet');

            const milestone = await jackpot.getMilestoneForId(takeoffBlock.toString());
            
            assert.equal(takeoffBlock.toString(), new Milestone(milestone).startBlock, 'expected a new milestone to be created');
        });
        
        it('should fail on empty nicknames', async () => {
            nicknamePrice = await volume.getNicknamePrice();
            await volume.transfer(user2, nicknamePrice);
            await truffleAssert.reverts(
                volume.claimNickname('',{from: user2}),
                "Volume: user name can't be empty string"
            );
        });
 
        it('should be able to claim a nickname', async () => {
            const pastBalance = await volume.balanceOf(user1);
            const currentTotalSupply = await volume.totalSupply();
            await volume.fly();
            const currentFuelTank = await volume.getFuel();

            await volume.claimNickname('nickname',{from: user1});

            const currentNickname = await volume.getNicknameForAddress(user1);
            const nicknameOwner = await volume.getAddressForNickname('nickname');

            assert.equal(currentNickname ,'nickname', "expected nuckname do not match" );
            assert.equal(nicknameOwner ,user1, "expected owner of nickname is not right" );

            const {fuelExpected , jackpotExpected} = FuelCalculator.calculateFuel(nicknamePrice,currentTotalSupply,currentFuelTank.sub(toWeiBN('1')));

            const suppliedFuel = await volume.getUserFuelAdded(user1);
            const jackpotContribution = await jackpot.getParticipationAmountInMilestone(takeoffBlock.toString(), user1);
            
            assert(FuelCalculator.equalWithRoomForError(fuelExpected, suppliedFuel, eps), 'fuel is not right');
            assert.equal(jackpotExpected.toString(), jackpotContribution.toString(), 'jackpot deposit not right');

            const currentBalance = await volume.balanceOf(user1);
            assert.equal(currentBalance.toString() ,pastBalance.sub(nicknamePrice).toString() , 'After balance is not right' )
        });

        it('Changing a nickname unbind the old one', async () => {
            const oldNickname = await volume.getNicknameForAddress(user1);
            await volume.transfer(user1, nicknamePrice,{from: multisig});
            await volume.claimNickname('nickname1',{from: user1});
            
            const newNickname = await volume.getNicknameForAddress(user1);
            const newNicknameOwner =  await volume.getAddressForNickname('nickname1');
            
            const oldNicknameOwner = await  volume.getAddressForNickname(oldNickname);

            assert.equal(newNickname , 'nickname1',"newnickname do not match");
            assert.equal(newNicknameOwner, user1, 'owner of new nickname is not right');
            assert.equal(oldNicknameOwner, addressZero, 'owner of old nickname should return to address zero');
        });

        it('should deduct fuel normally and sets the right amounts of fuel and jackpot amounts', async () => {
            const pastBalance = await  volume.balanceOf(user1);
            const currentTotalSupply = await volume.totalSupply();
            const currentFuelTank = await volume.getFuel();
            const pastFuelSupplied = await volume.getUserFuelAdded(user1);
            const pastPotSupplied = await jackpot.getParticipationAmountInMilestone(takeoffBlock.toString(), user1);
            
            const refuelAmount = toWeiBN('1000');

            await volume.directRefuel(toWei('1000'),{from: user1});
            
            const suppliedFuel = (await volume.getUserFuelAdded(user1)).sub(pastFuelSupplied);
            const jackpotContribution = (await jackpot.getParticipationAmountInMilestone(takeoffBlock.toString(), user1)).sub(pastPotSupplied);
            
            const {fuelExpected , jackpotExpected} = FuelCalculator.calculateFuel(refuelAmount,currentTotalSupply,currentFuelTank.sub(toWeiBN('1')));

            assert(FuelCalculator.equalWithRoomForError(fuelExpected, suppliedFuel, eps), 'fuel is not right');
            assert.equal(jackpotExpected.toString(), jackpotContribution.toString(), 'jackpot deposit not right');

            const currentBalance = await volume.balanceOf(user1);
            assert.equal(currentBalance.toString() ,pastBalance.sub(refuelAmount).toString() , 'After balance is not right' );
        });

        it('should deduct fuel for a thirdparty normally and sets the right amounts of fuel and jackpot amounts', async () => {
            const pastBalance = await  volume.balanceOf(multisig);
            const currentTotalSupply = await volume.totalSupply();
            const currentFuelTank = await volume.getFuel();
            const pastFuelSupplied = await volume.getUserFuelAdded(user1);
            const pastPotSupplied = await jackpot.getParticipationAmountInMilestone(takeoffBlock.toString(), user1);
            
            const refuelAmount = toWeiBN('1000');

            await volume.directRefuelFor(toWei('1000'),user1);
            
            const suppliedFuel = (await volume.getUserFuelAdded(user1)).sub(pastFuelSupplied);
            const jackpotContribution = (await jackpot.getParticipationAmountInMilestone(takeoffBlock.toString(), user1)).sub(pastPotSupplied);
            
            const {fuelExpected , jackpotExpected} = FuelCalculator.calculateFuel(
                refuelAmount, currentTotalSupply, currentFuelTank.sub(toWeiBN('1') ) // We traveled one block and it will be removed from the tank
                );

            assert(FuelCalculator.equalWithRoomForError(fuelExpected, suppliedFuel, eps), 'fuel is not right');
            assert.equal(jackpotExpected.toString(), jackpotContribution.toString(), 'jackpot deposit not right');

            const currentBalance = await volume.balanceOf(multisig);
            assert.equal(currentBalance.toString() ,pastBalance.sub(refuelAmount).toString() , 'After balance is not right' );
        });

        it('freeloader should not pay fuel', async () => {
            let balanceBefore = await volume.balanceOf(freeloader);

            let transfer = await volume.transfer(freeloader, toWei('1000'));
            assert(transfer , "should have returned true but it did not");

            let balanceAfter = await volume.balanceOf(freeloader);
            let expectedBalance = balanceBefore.add(toWeiBN('1000'));
            assert.equal(balanceAfter.toString() , expectedBalance.toString() , 'balance before and after not right');

            const fuelSuppliedByMultisig = await volume.getUserFuelAdded(multisig);
            assert.equal(fuelSuppliedByMultisig.toString(), toWeiBN('0').toString(), 'Multisig should not have supplied any fuel');

            balanceBefore = await volume.balanceOf(user1);
            transfer = await volume.transfer(user1, toWei('1000'),{from: freeloader});
            assert(transfer, "should have returned true but it did not");
            
            balanceAfter = await volume.balanceOf(user1);
            expectedBalance = balanceBefore.add(toWeiBN('1000')); // should receive the full an=mount becaue no fuel is paid

            assert.equal(expectedBalance.toString() , balanceAfter.toString(), "balance after is not right"); 
            let fuelSupplied = await volume.getUserFuelAdded(freeloader);
            assert.equal(fuelSupplied.toString(), toWeiBN('0').toString(), 'freeloader should not have supplied any fuel');

            await volume.transfer(freeloader , toWeiBN('1000'));
            await volume.approve(user1 , toWeiBN('1000'),{from : freeloader});

            await volume.transferFrom(freeloader , user1 , toWeiBN('1000'),{from : user1});
            fuelSupplied = await volume.getUserFuelAdded(freeloader);
            assert.equal(fuelSupplied.toString(), toWeiBN('0').toString(), 'freeloader should not have supplied any fuel');
        });

        it('fuelCreditor should credit fuel to receiver', async () => {
            let fuelBefore = await volume.getUserFuelAdded(user2);
            let potContributionBefore = await jackpot.getParticipationAmountInMilestone(takeoffBlock, user2);
            let currentTotalSupply = await volume.totalSupply();

            await volume.fly();

            await volume.transfer(creditor , toWeiBN('2000'),{from: multisig});

            let currentFuelTank = await volume.getFuel();
            await volume.transfer(user2, toWeiBN('1000'),{from: creditor});
            await volume.approve(user1, toWeiBN('1000'),{from:creditor});

            const refuelAmount = toWeiBN('1000').div(new BN('1000')); // 0.1 will go to refuel

            let creditorFuel = await volume.getUserFuelAdded(creditor);
            assert.equal(creditorFuel.toString(), toWeiBN('0').toString(), "creditor should have 0 fuelAdded");

            let fuelAfter = await volume.getUserFuelAdded(user2);
            let potContributionAfter = await jackpot.getParticipationAmountInMilestone(takeoffBlock, user2);

            let {fuelExpected , jackpotExpected} = FuelCalculator.calculateFuel(
                refuelAmount, currentTotalSupply, currentFuelTank.sub(toWeiBN('1') )// We traveled two blocks (approve does not call _fly()) and it will be removed from the tank
                );

            assert.equal(fuelExpected.toString() , fuelAfter.sub(fuelBefore).toString() , 'expected fuel not right');
            assert.equal(jackpotExpected.toString(), potContributionAfter.sub(potContributionBefore).toString(), 'expected pot contribution not right');

            currentTotalSupply = await volume.totalSupply();
            fuelBefore = await volume.getUserFuelAdded(user2);
            potContributionBefore = await jackpot.getParticipationAmountInMilestone(takeoffBlock, user2);
            
            await volume.fly(); // consume all fuel to the latest block
            currentFuelTank = await volume.getFuel();

            await volume.transferFrom(creditor , user2, toWeiBN('1000'),{from: user1}); // using the transferFrom
            
            fuelAfter = await volume.getUserFuelAdded(user2);
            potContributionAfter = await jackpot.getParticipationAmountInMilestone(takeoffBlock, user2);

            let exprected = FuelCalculator.calculateFuel(
                refuelAmount, currentTotalSupply, currentFuelTank.sub(toWeiBN('1') )// We traveled two blocks (approve does not call _fly()) and it will be removed from the tank
                );

            assert.equal(exprected.fuelExpected.toString() , fuelAfter.sub(fuelBefore).toString() , 'expected fuel not right');
            assert.equal(exprected.jackpotExpected.toString(), potContributionAfter.sub(potContributionBefore).toString(), 'expected pot contribution not right');
        });

        it('Normal users should pay fuel on transactions and supply the right amounts', async () => {
                     
            let fuelBefore = await volume.getUserFuelAdded(user3);
            let potContributionBefore = await jackpot.getParticipationAmountInMilestone(takeoffBlock, user3);
            let currentTotalSupply = await volume.totalSupply();

            await volume.fly();

            await volume.transfer(user3 , toWeiBN('2000'),{from: multisig});

            let currentFuelTank = await volume.getFuel();
            await volume.transfer(user2, toWeiBN('1000'),{from: user3});
            await volume.approve(user1, toWeiBN('1000'),{from:user3});

            const refuelAmount = toWeiBN('1000').div(new BN('1000')); // 0.1 will go to refuel

            let fuelAfter = await volume.getUserFuelAdded(user3);
            let potContributionAfter = await jackpot.getParticipationAmountInMilestone(takeoffBlock, user3);

            let {fuelExpected , jackpotExpected} = FuelCalculator.calculateFuel(
                refuelAmount, currentTotalSupply, currentFuelTank.sub(toWeiBN('1'))
                );

            assert.equal(fuelExpected.toString() , fuelAfter.sub(fuelBefore).toString() , 'expected fuel not right');
            assert.equal(jackpotExpected.toString(), potContributionAfter.sub(potContributionBefore).toString(), 'expected pot contribution not right');

            currentTotalSupply = await volume.totalSupply();
            fuelBefore = await volume.getUserFuelAdded(user3);
            potContributionBefore = await jackpot.getParticipationAmountInMilestone(takeoffBlock, user3);
            
            await volume.fly(); // consume all fuel to the latest block
            currentFuelTank = await volume.getFuel();

            await volume.transferFrom(user3 , user2, toWeiBN('1000'),{from: user1}); // using the transferFrom
            
            fuelAfter = await volume.getUserFuelAdded(user3);
            potContributionAfter = await jackpot.getParticipationAmountInMilestone(takeoffBlock, user3);

            let exprected = FuelCalculator.calculateFuel(
                refuelAmount, currentTotalSupply, currentFuelTank.sub(toWeiBN('1'))
                );

            assert.equal(exprected.fuelExpected.toString() , fuelAfter.sub(fuelBefore).toString() , 'expected fuel not right');
            assert.equal(exprected.jackpotExpected.toString(), potContributionAfter.sub(potContributionBefore).toString(), 'expected pot contribution not right');
        });
        
        it('can crash', async () => {

            await volume.transfer(mockLPAddress, toWei('10'),{from: multisig}); // we use this balance in the next test
            await volume.transfer(freeloader, toWei('10'),{from: multisig}); // we use this balance in the next test
            await volume.transfer(creditor, toWei('10'),{from: multisig}); // we use this balance in the next test
            await volume.transfer(directBurner, toWei('10'),{from: multisig}); // we use this balance in the next test


            await volume.transfer(user1, toWei('10000'),{from: multisig});
            await volume.setFuelTank(toWei('3')); // should crash in 3 blocks 
            await volume.transfer(user2, toWei('1'),{from: user1}); // 1 blocks left because setFuel moved a block without using fuel
            await volume.transfer(user2, toWei('1'),{from: user1}); // 0 blocks left
            
            await truffleAssert.reverts(
                volume.transfer(user2, toWei('1'),{from: user1}),
                'Crashed - please redeem your tokens on escrow'
            );

            await volume.fly();

            assert.equal((await volume.getFuel()).toString(), '0' , "FuelTank should be zero");
        });

        it('escrow can only receive and LP can only send after crash',async ( ) => {
            await truffleAssert.reverts(
                volume.transfer(user1 , toWeiBN('100')),
                'Crashed - please redeem your tokens on escrow'
            );

            let transfered = await volume.transfer(escrow.address , toWeiBN('1'),{from : user1});
            assert(transfered, "should transfer"); // escrow receives
            
            await truffleAssert.reverts(
                escrow.sendVolForPorpuse(4, toWeiBN('100'),user1),
                'Crashed - please redeem your tokens on escrow'
            );
               
            await truffleAssert.reverts(
                volume.transfer(mockLPAddress, toWeiBN('1'), {from: user1}),
                'Crashed - please redeem your tokens on escrow'
            );

            transfered = await volume.transfer(user1, toWeiBN('1'),{from: mockLPAddress});
            assert(transfered, "should transfer"); // escrow sends

            await truffleAssert.reverts(
                volume.transfer(mockLPAddress, toWeiBN('1'), {from: user1}),
                'Crashed - please redeem your tokens on escrow'
            );

            await truffleAssert.reverts(
                volume.transfer(mockLPAddress, toWeiBN('1'), {from: creditor}),
                'Crashed - please redeem your tokens on escrow'
            );

            await truffleAssert.reverts(
                volume.transfer(mockLPAddress, toWeiBN('1'), {from: freeloader}),
                'Crashed - please redeem your tokens on escrow'
            );

            await truffleAssert.reverts(
                volume.transfer(mockLPAddress, toWeiBN('1'), {from: directBurner}),
                'Crashed - please redeem your tokens on escrow'
            );
        })
    }); 
});