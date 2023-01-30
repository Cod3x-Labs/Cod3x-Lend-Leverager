import { HardhatUserConfig } from "hardhat/config";
import "@nomiclabs/hardhat-etherscan";
import "@nomiclabs/hardhat-waffle";
import "@typechain/hardhat";
import "solidity-coverage";
import * as env from './env.json';

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: "0.6.12",
        settings: {
          optimizer: { enabled: true, runs: 200 },
        },
      },
      {
        version: "0.7.5",
        settings: {
          optimizer: { enabled: true, runs: 200 },
        },
      },
      {
        version: "0.6.6",
        settings: {
          optimizer: { enabled: true, runs: 200 },
        },
      },
    ],
  },
  networks: {
    fantom: {
      url: `https://rpc.ankr.com/fantom`,
      accounts: [`0x${env.PK1}`],
    },
    optimism: {
      url: `https://rpc.ankr.com/optimism`,
      accounts: [`0x${env.PK1}`],
    },
    avalanche: {
      url: `https://rpc.ankr.com/avalanche`,
      accounts: [`0x${env.PK1}`],
    },
    ethereum: {
      url: `https://rpc.ankr.com/eth`,
      accounts: [`0x${env.PK1}`],
    },
    metis: {
      url: `https://andromeda.metis.io/?owner=1088/`,
      accounts: [`0x${env.PK1}`],
    },
    arbitrum: {
      url: `https://rpc.ankr.com/arbitrum`,
      accounts: [`0x${env.PK1}`],
    },
    binance: {
      url: `https://rpc.ankr.com/bsc`,
      accounts: [`0x${env.PK1}`],
    }
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts",
  },
};

export default config;
