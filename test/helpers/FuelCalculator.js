const { BN , toWei } =  web3.utils;
const BASE = new BN(10**18 + '');
module.exports = {
    calculateFuel : (fuelAmount , totalSupply , currentFuel) => {
        const toBeBurned = fuelAmount.div(new BN('2'));
        const toBeSentToJackpot = fuelAmount.sub(toBeBurned);

        const fuel = toBeBurned.mul(BASE).mul(BASE).div(totalSupply.sub(toBeBurned)).div(BASE).mul(new BN('240'));
        const fuelToBEAdded = currentFuel.mul(fuel).div(BASE);

        return {
            jackpotExpected: toBeSentToJackpot,
            fuelExpected : fuelToBEAdded
        }
    },
    equalWithRoomForError : (number1 , number2 ,eps) => {
        return number1.sub(number2).abs().lte(eps);
    },
    toWeiBN : (num) => {
        return new BN(toWei(num));
    }
}