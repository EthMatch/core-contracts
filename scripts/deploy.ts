import { ethers } from "hardhat";

async function main() {
  const Game = await ethers.getContractFactory("Game");
  const GameFactory = await Game.deploy(
    "0x0000000000000000000000000000000000000000",
  );
  console.log("deploying contract Game");
  await GameFactory.deployed();
  console.log("Game Factory deployed to:", GameFactory.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
