const VolumeEscrow = artifacts.require("VolumeEscrow");
const VolumeJackpot = artifacts.require("VolumeJackpot");

module.exports = function (deployer, network, accounts) {
    // TODO replace with multi sig
    deployer.deploy(VolumeJackpot, accounts[0], VolumeEscrow.address);
};
