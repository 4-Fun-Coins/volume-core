const VolumeEscrow = artifacts.require("VolumeEscrow");
const TestVolume = artifacts.require("TestVolume");
const Volume = artifacts.require("Volume");
const VolumeJackpot = artifacts.require("VolumeJackpot");

module.exports = function (deployer, network, accounts) {
    if(network != 'BSCMainNet'){
        deployer.deploy(Volume, VolumeEscrow.address, accounts[0], VolumeJackpot.address)
    } else {
        deployer.deploy(Volume, VolumeEscrow.address, accounts[0], VolumeJackpot.address)
    }
};
