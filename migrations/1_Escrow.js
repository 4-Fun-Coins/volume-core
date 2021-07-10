const VolumeEscrow = artifacts.require("VolumeEscrow");
//const Volume = artifacts.require("Volume");
let wbnb = "0x000000000000000000000000000000000000dead";
let bakryRouter = "0x000000000000000000000000000000000000dead";
module.exports = function (deployer , network , accounts) {
  if(network == "kovan"){
    wbnb = "0xd0A1E359811322d97991E03f863a0C30C2cF029C" // WTH9 on kovan
    bakryRouter = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D"; // Uni on Kovan (same contratc as bakry)
  }
  // TODO replace with multi sig 
  deployer.deploy(VolumeEscrow, accounts[0], wbnb , bakryRouter);
};
