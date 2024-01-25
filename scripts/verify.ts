const hre = require('hardhat');
import { ethers } from "hardhat";
import * as addresses from '../addresses.json';

async function main() {
  await hre.run('verify:verify', {
    address: '',
    constructorArguments: [
      '',
      ''
    ],
  })
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});