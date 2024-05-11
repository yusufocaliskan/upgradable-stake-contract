require('@nomicfoundation/hardhat-toolbox');
require('@openzeppelin/hardhat-upgrades');
const { mnemonic, bscscanApiKey } = require('./secret.json');

module.exports = {
  defaultNetwork: 'hardhat',
  networks: {
    hardhat: {},
    sepolia: {
      url: 'SEPOLIA_RCP_TARGET',

      accounts: [], //private keys
    },
    bscMainnet: {
      url: 'https://bsc-dataseed.binance.org/',
      chainId: 56,
      gasPrice: 20000000000,
      accounts: { mnemonic: mnemonic },
    },
    bscTestnet: {
      url: 'https://data-seed-prebsc-1-s1.bnbchain.org:8545',
      chainId: 97,

      accounts: [], //private keys
      // gasPrice: 20000000000,
    },
  },
  etherscan: {
    apiKey: bscscanApiKey,
  },
  gasReporter: {
    enabled: true,
    currency: 'BNB',
    coinmarketcap: 'COIN_MAKETCAP_API_KEY',
    gasPrice: 20,
  },
  solidity: {
    version: '0.8.24',
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },

  paths: {
    sources: './contracts',
    tests: './test',
    cache: './cache',
    artifacts: './artifacts',
  },
  mocha: {
    timeout: 40000,
  },
};
