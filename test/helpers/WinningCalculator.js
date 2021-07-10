const truffleAssertions = require("truffle-assertions");
const { toWeiBN } = require("./FuelCalculator");
const { BN ,toWei,fromWei} =  web3.utils;

module.exports = {
    /**
     * requires winners count to be greater than 3 to succseed
     */
    getWinnersAndAmounts : (participants , totalAmout , winnersCount) => {
        const firstPlaceRatio = new BN('25');
        const secondPlace = new BN('15');
        const thirdPlace = new BN('10');
        const restCount = winnersCount.sub(new BN('3'));

        amounts = [];
        amounts[0] = totalAmout.mul(firstPlaceRatio).div(new BN('100')); // first place
        amounts[1] = totalAmout.mul(secondPlace).div(new BN('100')); // second place
        amounts[2] = totalAmout.mul(thirdPlace).div(new BN('100')); // third place
        amounts[3] = totalAmout.sub(amounts[0]).sub(amounts[1]).sub(amounts[2]).div(restCount); // rest

        const restToTotal = totalAmout.sub(amounts[3].mul(restCount).add(amounts[0]).add(amounts[1]).add(amounts[2]));
        if(restToTotal < 0){
            assert(false, "the calculation is wrong distributed winnings are bigger than the pot");
        }
        
        if(restToTotal > 0){
            amounts[0] = amounts[0] + restToTotal; // in case there is some amount left not distributed should be very very small
        }

        const sorted = participants.sort((participantA , participantB) => {
            return participantB.amount - participantA.amount;
        });

        const winners = [];
        const winnersAmounts = [];


        sorted.forEach((element , index) => {
            if(index <= 2){
                winners.push(element.address);
                winnersAmounts.push(amounts[index]);
            } else if(index < winnersCount){
                winners.push(element.address);
                winnersAmounts.push(amounts[3]);
            }
        })

        return {
            winners,
            amounts: winnersAmounts
        }
    }
}