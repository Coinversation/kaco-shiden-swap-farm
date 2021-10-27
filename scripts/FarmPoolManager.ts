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

const masterChefShidenAddress = "0x293A7824582C56B0842535f94F6E3841888168C8";
const syrupShidenAddress = "0x808764026aDddb9E7dFAAEA846977cCe6425D593";

const kac_sdn = "0x456C0082DE0048EE883881fF61341177FA1FEF40";

async function main() {
  // We get the contract to deploy
  const farm = await ethers.getContractAt("MasterChef", masterChefShidenAddress, await ethers.getSigner(mainAddress));
  const pid = "2";
  const lp = await ethers.getContractAt("IERC20", kac_sdn, await ethers.getSigner(mainAddress));

  // console.log("pool length: ", await farm.poolLength());
  // await farm.add(0, "0x8644e9AC84273cA0609F2A2B09b2ED2A5aD2e9DD", true);
  // await sleep(31000);
  // console.log("pool length: ", await farm.poolLength());

// console.log("start block:", await farm.startBlock());

  console.log("total alloc: ", await farm.totalAllocPoint());
  await farm.set(pid, "0", true);
  // await sleep(31000);
  // console.log("total alloc: ", await farm.totalAllocPoint());


  // console.log("poolInfo:", await farm.poolInfo(pid));
  // await lp.approve(masterChefShidenAddress, "1000000000000000000000000");
  // await sleep(31000);
  // farm.deposit(pid, "100000000000000000");
  // await sleep(31000);
  // console.log("poolInfo:", await farm.poolInfo(pid));
  // console.log("pending award:", await farm.pendingCake(pid, mainAddress));

  // await farm.updateKacPerBlock("500000000000000000", true);
  // await sleep(31000);

  // await farm.updateAllocBSC("86000000000", false);
  // await farm.updateAllocShiden("40000000000", false);
  // await sleep(31000);


  // console.log("supply for masterChef: ", (await lp.balanceOf(masterChefShidenAddress)).toString());
  // console.log("totalAlloc", await farm.totalAllocPoint());
  // console.log("kacPerShidenBlock", await farm.kacPerShidenBlock());
  // console.log("userInfo", await farm.userInfo(pid, mainAddress));
  // console.log("pending award:", await farm.pendingCake(pid, mainAddress));

  // console.log("kacPerBlock", await farm.kacPerBlock());
  // console.log("allocBSC", await farm.allocBSC());
  // console.log("allocShiden", await farm.allocShiden());
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
