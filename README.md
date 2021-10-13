# volume-core

# Current Deployement (Open Beta)

# Kovan

### VolumeEscrow
https://kovan.etherscan.io/address/0xDC03c48C629649FCd10Ab9f081C7374a5407BB85#contracts
### VolumeJackpot
https://kovan.etherscan.io/address/0xa3D29f0473422210b9f3fF5D6889CDE0b81937A4#contracts
### Volume
https://kovan.etherscan.io/address/0xbD13E0F8D014AaB39AE144BbDf539E3dD91c6FA6#contracts
### VolumeFaucet
https://kovan.etherscan.io/address/0x144aAA746504E1627168e41f1bE8e4806102Ec1A#contracts
### Farm
https://kovan.etherscan.io/address/0x3DD5021FEb27cfc8fAbBe461cba9e913E0833571#contracts


# BSC beta 0.2.0
### VolumeEscrow
https://testnet.bscscan.com/address/0xC16c2369FEd0A07ee011aA9ee76199650647e583#contracts
### VolumeJackpot
https://testnet.bscscan.com/address/0x3d659Ac8eB86200808E45337979f80e3c0F958Ed#contracts
### Volume
https://testnet.bscscan.com/address/0x94CC4969d5e33B5ED2671bf291c22540b388E956#contracts
### VolumeFaucet
https://testnet.bscscan.com/address/0xBc138819eA25eDf1AD51579C2936DF37C251214b#contracts
### Farm
https://testnet.bscscan.com/address/0xE2494A8545C9430C912Cca106838B00DBd6a4Ac1#contracts


## Guide to Deploy and test locally:

## Requirements
- ganache
- truffle
- npm

## Get started
### npm installation
To get started with a local deployment, please run the following first:

```
npm install
```

### Ganache
To deploy a local blockchain, please run the following command:

```
ganache-cli
```

### Tests

For the sake of testing, we will be using TestVolume to run the tests on.

You can now run 

```
truffle test
```

This should run all the tests and they should all pass. If they don't, please check to see that your local blockchain is configured correctly. The default config has been used
in development of Volume.
