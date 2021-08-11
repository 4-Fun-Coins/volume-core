const Marketplace = artifacts.require("VolumeMarketplace");
const Volume = artifacts.require("TestVolume");

module.exports = function (deployer, network , accounts) {

    deployer.deploy(Marketplace, Volume.address);
};