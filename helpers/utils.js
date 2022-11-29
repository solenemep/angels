const BigNumber = require("bignumber.js");
const { time } = require("@openzeppelin/test-helpers");
const { takeSnapshot } = require("@nomicfoundation/hardhat-network-helpers");
const { toWei } = web3.utils;

function toBN(number) {
  return new BigNumber(number);
}

let _snapshot;

async function snapshot() {
  _snapshot = await takeSnapshot();
}

async function restore() {
  await _snapshot.restore();
}

async function increaseTime(duration) {
  await time.increase(duration);
}

async function increaseTimeTo(target) {
  await time.increaseTo(target);
}

async function getTime() {
  return toBN(await time.latest())
    .plus(1)
    .toString();
}

async function getCurrentBlock() {
  const block = await web3.eth.getBlock("latest");
  return block.number;
}

async function advanceBlockTo(blockAmount) {
  const lastBlock = await time.latestBlock();

  await time.advanceBlockTo(toBN(lastBlock).plus(blockAmount).toString());
}

async function getCosts(tx) {
  const receipt = await web3.eth.getTransactionReceipt(tx.hash);
  const gasUsed = receipt.gasUsed;
  const gasPrice = Number(tx.gasPrice);
  const gasCost = toBN(gasUsed).times(gasPrice);
  console.log("gas used : " + gasUsed);
  console.log("gas price : " + gasPrice);
  console.log(
    "tx cost : " +
      toBN(gasCost)
        .div(10 ** 18)
        .toString() +
      " ETH"
  );
}

async function wait(ms) {
  new Promise((resolve) => setTimeout(resolve, ms));
}

module.exports = {
  toBN,
  toWei,
  snapshot,
  restore,
  increaseTime,
  increaseTimeTo,
  getTime,
  getCurrentBlock,
  advanceBlockTo,
  getCosts,
  wait,
};
