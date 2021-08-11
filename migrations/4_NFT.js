const NFT = artifacts.require("EnumerableNFT");

module.exports = function (deployer, network , accounts) {

  deployer.deploy(NFT, 'AstroPunks', 'AP', 'https://images.unsplash.com/photo-1626327547387-b2663804dd50?ixlib=rb-1.2.1&ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8&auto=format&fit=crop&w=1489&q=');
};