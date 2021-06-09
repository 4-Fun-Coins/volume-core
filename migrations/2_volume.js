const Big = require('big-js');
Big.DP = 40;

const Volume = artifacts.require('Volume');

module.exports = function (deployer) {
    deployer.deploy(Volume);
}