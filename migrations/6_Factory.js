const Factory = artifacts.require("VolumeNFTFactory");

module.exports = function (deployer, network , accounts) {

  deployer.deploy(Factory);
};