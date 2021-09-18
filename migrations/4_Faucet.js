const TestVolume = artifacts.require("TestVolume");
const VolumeFaucet = artifacts.require("VolumeFaucet");

module.exports = function (deployer, network, accounts) {
    if (network == "kovan" || network == "BSCTest")
        deployer.deploy(VolumeFaucet, accounts[0], TestVolume.address)
};
