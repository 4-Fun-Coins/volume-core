const Big = require('big-js');
Big.DP = 40;

const Volume = artifacts.require('TestVolume');

module.exports = function (deployer) {
    // NOTE - Make this address the address for the deployed escrow
    deployer.deploy(Volume, '0xe420279D0bf665073f069cB576c28d6F77633b20'); 
}