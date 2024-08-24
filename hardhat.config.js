require("@nomicfoundation/hardhat-toolbox");
require('hardhat-gas-reporter');
require('dotenv').config();
/** @type import('hardhat/config').HardhatUserConfig */

function mnemonic() {
  return [process.env.PRIVATE_KEY, process.env.PRIVATE_KEY1, process.env.PRIVATE_KEY2];
}

module.exports = {
  solidity: "0.8.24",

  networks: {
    localhost: {
      url: 'http://localhost:8545',
    },
    mainnet: {
      url: 'https://eth-mainnet.g.alchemy.com/v2/' + process.env.ALCHEMY_ID,
      accounts: mnemonic(),
    },
    sepolia: {
      url: 'https://eth-sepolia.g.alchemy.com/v2/' + process.env.ALCHEMY_ID,
      accounts: mnemonic(),
    },
  },

  gasReporter: {
    currency: 'USD',
    coinmarketcap: process.env.COINMARKETCAP,
    gasPrice: 200,
  },

  mocha: {
    timeout: 20000,
  },
};
