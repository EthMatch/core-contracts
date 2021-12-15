import { expect } from "chai";

import { ethers } from "hardhat";

describe("Greeter", () => {
  it("get balance", async  ()=> {
  console.log("hello");

  const deployed = await ethers.getContractAt("Game","0x0DCd1Bf9A1b36cE34237eEaFef220932846BCD82");
  let balance  =  await deployed.connect("0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266").getBalance()
  console.log(balance)
  });
});
