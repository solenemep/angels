const { ZERO_ADDRESS } = require("@openzeppelin/test-helpers/src/constants");
const { expect } = require("chai");
const { args } = require("./helpers/arguments");
const { assets } = require("./helpers/assets");
const { Class, classLimits } = require("./helpers/classLimits");
const { init } = require("./helpers/init");
const { toBN, toWei, snapshot, restore, increaseTime, increaseTimeTo, getTime, getCosts } = require("./helpers/utils");

describe("AssetsRegistry", async () => {
  let assetsRegistry;
  let owner;
  let user1;

  before("setup", async () => {
    const setups = await init(false);
    owner = setups.users[0];
    user1 = setups.users[1];

    assetsRegistry = setups.assetsRegistry;

    await snapshot();
  });

  afterEach("revert", async () => {
    await restore();
  });

  describe("getters", async () => {
    it("getAssetInfo", async () => {
      // console.log(await assetsRegistry.getAssetInfo(0, 1));
    });
    it("getAssetsPerType", async () => {
      // console.log(await assetsRegistry.getAssetsPerType(0));
    });
    it("getAssetsPerTypePerWeight", async () => {
      // console.log(await assetsRegistry.getAssetsPerTypePerWeight(0, 250));
    });
    it("getAssetsPerTypePerWeightRange", async () => {
      // console.log(await assetsRegistry.getAssetsPerTypePerWeightRange(0, 100, 1000));
      // console.log(await assetsRegistry.getAssetsPerTypePerWeightRange(0, 251, 1000));
      // console.log(await assetsRegistry.getAssetsPerTypePerWeightRange(3, 0, 800));
    });
  });
  describe.skip("get fees", async () => {
    it("setAssets", async () => {
      for (const asset of assets) {
        const tx = await assetsRegistry.setAssets(asset.assetId, asset.assets, asset.weigths, asset.names);
        await getCosts(tx);
      }
    });
  });
});
