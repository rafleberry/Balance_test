const { ethers } = require("hardhat");
const { expect } = require("chai");
const colors = require("colors");
const { utils } = require("ethers");

const zeroAddress = "0x0000000000000000000000000000000000000000";

let vault,
  asset,
  totalAsset = 0;

function toEth(num) {
  return utils.formatEther(num);
}

function fromEth(num) {
  return utils.parseEther(num.toString());
}

describe("CMDEV Vault test", async () => {
  before(async () => {
    [deployer, alice, bob, carol, david, evan, fiona] =
      await ethers.getSigners();

    // Deploy Contracts
    console.log("Deploying Contracts".green);

    const Asset = await ethers.getContractFactory("TestAsset");
    asset = await Asset.deploy();
    console.log("Asset Deployed: ", asset.address);

    const Vault = await ethers.getContractFactory("Vault");
    vault = await Vault.deploy(asset.address);
    console.log("Vault Deployed: ", vault.address);

    await asset.transfer(alice.address, fromEth(1000));
    await asset.connect(alice).approve(vault.address, fromEth(1000));
    await asset.transfer(bob.address, fromEth(1000));
    await asset.connect(bob).approve(vault.address, fromEth(1000));
    await asset.transfer(carol.address, fromEth(1000));
    await asset.connect(carol).approve(vault.address, fromEth(1000));
    await asset.transfer(david.address, fromEth(1000));
    await asset.connect(david).approve(vault.address, fromEth(1000));
    await asset.transfer(evan.address, fromEth(1000));
    await asset.connect(evan).approve(vault.address, fromEth(1000));
    await asset.transfer(fiona.address, fromEth(1000));
    await asset.connect(fiona).approve(vault.address, fromEth(1000));
  });

  it("Vault Deployed", async () => {
    const name = await vault.name();
    const symbol = await vault.symbol();
    const asset = await vault.asset();
    console.log("\tVault info: ", name, symbol, asset);
  });

  it("Alice Deposit 10 Asset", async () => {
    totalAsset += 10;
    await vault.connect(alice).deposit(fromEth(10), alice.address);
    const total = await vault.totalAssets();
    console.log("\tVault total asset: ", toEth(total));

    expect(total).to.be.equal(fromEth(totalAsset));
  });

  it("Get Top Depositors, first one should be Alice and second one is Zero", async () => {
    const tops = await vault.getTopTwo();
    console.log("\tTops: ", tops);

    expect(tops[0]).to.be.equal(alice.address);
    expect(tops[1]).to.be.equal(zeroAddress);
  });

  it("Bob deposit 100 Asset", async () => {
    totalAsset += 100;
    await vault.connect(bob).deposit(fromEth(100), bob.address);
    const total = await vault.totalAssets();
    console.log("\tVault total asset: ", toEth(total));

    expect(total).to.be.equal(fromEth(totalAsset));
  });

  it("Get Top Depositors, first one should be Bob and second one is Alice", async () => {
    const tops = await vault.getTopTwo();
    console.log("\tTops: ", tops);

    expect(tops[0]).to.be.equal(bob.address);
    expect(tops[1]).to.be.equal(alice.address);
  });

  it("Carol deposit 200 Asset", async () => {
    totalAsset += 200;
    await vault.connect(carol).deposit(fromEth(200), carol.address);
    const total = await vault.totalAssets();
    console.log("\tVault total asset: ", toEth(total));

    expect(total).to.be.equal(fromEth(totalAsset));
  });

  it("Get Top Depositors, first one should be Carol and second one is Bob", async () => {
    const tops = await vault.getTopTwo();
    console.log("\tTops: ", tops);

    expect(tops[0]).to.be.equal(carol.address);
    expect(tops[1]).to.be.equal(bob.address);
  });

  it("Carol Withdraw 200", async () => {
    totalAsset -= 200;
    await vault.connect(carol).withdraw(fromEth(200), carol.address);
    const total = await vault.totalAssets();
    console.log("\tVault total asset: ", toEth(total));

    expect(total).to.be.equal(fromEth(totalAsset));
  });

  it("Depositors Length should be 2", async () => {
    expect(await vault.totalDepositors()).to.be.equal(2);
  });

  it("Get Top Depositors, first one should be Bob and second one is Alice", async () => {
    const tops = await vault.getTopTwo();
    console.log("\tTops: ", tops);

    expect(tops[0]).to.be.equal(bob.address);
    expect(tops[1]).to.be.equal(alice.address);
  });
});
