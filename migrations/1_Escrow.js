const VolumeEscrow = artifacts.require("VolumeEscrow");
//const Volume = artifacts.require("Volume");
let wbnb = "0x000000000000000000000000000000000000dead";
let uniLikeRouter = "0x000000000000000000000000000000000000dead";
module.exports = function (deployer, network, accounts) {
    if (network == "kovan") {
        wbnb = "0xd0A1E359811322d97991E03f863a0C30C2cF029C"; // WTH9 on kovan
        uniLikeRouter = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D"; // Uni on Kovan
    } else if (network == "BSCTest") {
        wbnb = "0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd"; // WTH9 on bscTest
        uniLikeRouter = "0xD99D1c33F9fC3444f8101754aBC46c52416550D1"; // panecake on BscTest (same contratc as uniV2)
    }
    // TODO replace with multi sig
    deployer.deploy(VolumeEscrow, accounts[0], wbnb, uniLikeRouter);
};
