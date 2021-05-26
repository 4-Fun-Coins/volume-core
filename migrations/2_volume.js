const Big = require('big-js');
Big.DP = 40;

const Volume = artifacts.require('TestVolume');

module.exports = function (deployer) {
    deployer.deploy(Volume);
}