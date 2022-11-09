const { ZERO_ADDRESS } = require("@openzeppelin/test-helpers/src/constants");
const { expect } = require("chai");
const { args } = require("./helpers/arguments");
const { assets } = require("./helpers/assets");
const { Class, classLimits } = require("./helpers/classLimits");
const { init } = require("./helpers/init");
const { toBN, toWei, snapshot, restore, increaseTime, increaseTimeTo, getTime, getCosts } = require("./helpers/utils");

describe("Archangel", async () => {
  let archangel;
  let owner;
  let user1;

  before("setup", async () => {
    const setups = await init(false);
    owner = setups.users[0];
    user1 = setups.users[1];

    archangel = setups.archangel;

    await snapshot();
  });

  afterEach("revert", async () => {
    await restore();
  });

  describe("toggleNesting", async () => {});
  describe("toggleNesting", async () => {});
});
