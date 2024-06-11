const hre = require('hardhat');
import { ethers } from "hardhat";
import * as addresses from '../addresses.json';

const PROVIDER = "";
const WETH = "";

async function main() {
  await hre.run('verify:verify', {
    address: '',
    constructorArguments: [
      PROVIDER,
      WETH
    ],
  })
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});