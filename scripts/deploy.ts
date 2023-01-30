import { ethers } from "hardhat";

async function main() {  
  const LENDING_POOL = "";

  console.log(">>>Leverager.sol<<<");
  let Leverager = await ethers.getContractFactory("Leverager");
  let leverager = await Leverager.deploy(LENDING_POOL);
  console.log("  > Leverager.sol deployed at: " +leverager.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});