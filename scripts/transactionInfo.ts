// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
import { ethers } from "hardhat";
import hre from "hardhat";

const mainAddress = "0xFB83a67784F110dC658B19515308A7a95c2bA33A";
const bridgeAddress = "0xE7929a6f19B685A6F2C3Fa962054a82B79DC999F";

const kacoBSCAddress = "0xf96429A7aE52dA7d07E60BE95A3ece8B042016fB";
const kacoAddress = "0xb12c13e66ade1f72f71834f2fc5082db8c091358";

const syrupShidenAddress = "0x808764026aDddb9E7dFAAEA846977cCe6425D593";

async function main() {
  // We get the contract to deploy
  const provider = ethers.getDefaultProvider("https://bsc-dataseed.binance.org/");
  await sleep(3000);
  console.log("chain id:", provider.network.chainId);

  console.log("tran 1:", await provider.getTransaction("0x143e848eba91ed5c0884ecb8f61c336cdc564a4508a91ebd95ae0855d7bddfac"));
  console.log("tran 2:", await provider.getTransaction("0xf796e3ed6b537b5acb4164337170f365894687eceba3ef59b4a17391bd47a0c0"));
}

function sleep(ms:number) {
  return new Promise(resolve => setTimeout(resolve, ms));
}


// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
