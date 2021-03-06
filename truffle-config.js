/**
 * Use this file to configure your truffle project. It's seeded with some
 * common settings for different networks and features like migrations,
 * compilation and testing. Uncomment the ones you need or modify
 * them to suit your project as necessary.
 *
 * More information about configuration can be found at:
 *
 * trufflesuite.com/docs/advanced/configuration
 *
 * To deploy via Infura you'll need a wallet provider (like @truffle/hdwallet-provider)
 * to sign your transactions before they're sent to a remote public node. Infura accounts
 * are available for free at: infura.io/register.
 *
 * You'll also need a mnemonic - the twelve word phrase the wallet uses to generate
 * public/private key pairs. If you're publishing your code to GitHub make sure you load this
 * phrase from a file you've .gitignored so it doesn't accidentally become public.
 *
 */

const HDWalletProvider = require('@truffle/hdwallet-provider');
const NonceTrackerSubprovider = require("web3-provider-engine/subproviders/nonce-tracker")

//
const fs = require('fs');
const infuraKey = fs.readFileSync(".infuraKey").toString().trim();

const bscRPC = fs.readFileSync(".bscRPC").toString().trim();

const mnemonic = fs.readFileSync(".secret").toString().trim();
const mnemonicLocal = fs.readFileSync(".secret.local").toString().trim();
const etherscanKey = fs.readFileSync(".etherscanKey").toString().trim();
const bscscanKey = fs.readFileSync(".bscscanKey").toString().trim();

module.exports = {
    /**
     * Networks define how you connect to your ethereum client and let you set the
     * defaults web3 uses to send transactions. If you don't specify one truffle
     * will spin up a development blockchain for you on port 9545 when you
     * run `develop` or `test`. You can ask a truffle command to use a specific
     * network from the command line, e.g
     *
     * $ truffle test --network <network-name>
     */

    networks: {
        BSCTest: {
            provider: function () {
                var wallet = new HDWalletProvider(mnemonic, bscRPC)
                var nonceTracker = new NonceTrackerSubprovider()
                wallet.engine._providers.unshift(nonceTracker)
                nonceTracker.setEngine(wallet.engine)
                return wallet
            },
            network_id: 97,       // BSC test net's id
            gas: 5500000,
            confirmations: 0,    // # of confirmations to wait between deployments. (default: 0)
            timeoutBlocks: 50,  // # of blocks before a deployment times out  (minimum/default: 50)
            skipDryRun: true     // Skip dry run before migrations? (default: false for public nets )
        },
        kovan: {
            provider: function () {
                var wallet = new HDWalletProvider(mnemonic, infuraKey)
                var nonceTracker = new NonceTrackerSubprovider()
                wallet.engine._providers.unshift(nonceTracker)
                nonceTracker.setEngine(wallet.engine)
                return wallet
            },
            network_id: 42,       // Kovan's id
            gas: 5500000,        // Kovan has a lower block limit than mainnet
            confirmations: 0,    // # of confirmations to wait between deployments. (default: 0)
            timeoutBlocks: 50,  // # of blocks before a deployment times out  (minimum/default: 50)
            skipDryRun: true     // Skip dry run before migrations? (default: false for public nets )
        },

        local: {
            host: `127.0.0.1`,
            port: `8545`,
            network_id: "*",
            gas: 6721975,
            confirmations: 0,
            timeoutBlocks: 50,
            skipDryRun: true
        },

        localWithProvider: {
            provider: function () {
                var wallet = new HDWalletProvider(mnemonicLocal, `HTTP://127.0.0.1:8545`)
                var nonceTracker = new NonceTrackerSubprovider()
                wallet.engine._providers.unshift(nonceTracker)
                nonceTracker.setEngine(wallet.engine)
                return wallet
            },
            network_id: '*',
            gas: 6721975,
            confirmations: 0,
            timeoutBlocks: 50,
            skipDryRun: true
        },
    },


    // Set default mocha options here, use special reporters etc.
    mocha: {
        // timeout: 100000
        enableTimeouts: false,
        before_timeout: 120000
    },

    // Configure your compilers
    compilers: {
        solc: {
            version: '0.8.4',
            // version: "0.5.1",    // Fetch exact version from solc-bin (default: truffle's version)
            // docker: true,        // Use "0.5.1" you've installed locally with docker (default: false)
            settings: {          // See the solidity docs for advice about optimization and evmVersion
                optimizer: {
                    enabled: false,
                    runs: 90000
                },
                //  evmVersion: "byzantium"
            }
        }
    },

    // Truffle DB is currently disabled by default; to enable it, change enabled: false to enabled: true
    //
    // Note: if you migrated your contracts prior to enabling this field in your Truffle project and want
    // those previously migrated contracts available in the .db directory, you will need to run the following:
    // $ truffle migrate --reset --compile-all

    db: {
        enabled: false
    },
    plugins: [
        'truffle-plugin-verify'
    ],
    api_keys: {
        etherscan: etherscanKey,
        bscscan: bscscanKey,
    }
};
