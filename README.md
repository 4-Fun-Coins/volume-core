# volume-core

# BSCTest Deployement:

### Faucet contract: 
Address: `0xCFf364d0045Df807AB53dDC827d054Ee6807471a`
BSCScan: https://testnet.bscscan.com/address/0xCFf364d0045Df807AB53dDC827d054Ee6807471a#contracts


### Volume BEP20 contract: 
Address: `0x5980A1d3db54c22FEb966449fFD228a9E39c3970`
BSCScan: https://testnet.bscscan.com/address/0x5980A1d3db54c22FEb966449fFD228a9E39c3970#contracts

### Volume Jackpot contract: 
Address: `0xD38a0b1f191D1AFAf788aD7162fC79aB058F3d99`
BSCScan: https://testnet.bscscan.com/address/0xD38a0b1f191D1AFAf788aD7162fC79aB058F3d99#contracts

### Volume Escrow contract: 
Address: `0xA0CcF5047480a270C9ECcA7c7f6453c69443F882`
BSCScan: https://testnet.bscscan.com/address/0xA0CcF5047480a270C9ECcA7c7f6453c69443F882#contracts



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
