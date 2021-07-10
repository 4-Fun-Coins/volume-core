const VolumeEscrow = artifacts.require("VolumeEscrow");
const Volume = artifacts.require("TestVolume"); // TODO change this in production
const VolumeJackpot = artifacts.require("VolumeJackpot");

module.exports = function (deployer, network , accounts) {

  deployer.deploy(Volume, VolumeEscrow.address, accounts[0],VolumeJackpot.address)
};
