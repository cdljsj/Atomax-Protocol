import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomiclabs/hardhat-ethers";
import 'hardhat-deploy';
import { node_url, accounts } from './utils/network'

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.17",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  namedAccounts: {
    deployer: {
      default: 1
    }
  },
  // defaultNetwork: "hardhat",
  defaultNetwork: "fevmdev",
  networks: {
    hardhat: {
      gas: 'auto',
    },
    fevmdev: {
      gas: 'auto',
      url: node_url('fevmdev'),
      accounts: accounts()
    },
  }
};

export default config;
