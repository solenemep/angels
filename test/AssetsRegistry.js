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

  describe("setAssets", async () => {
    it("set assets background", async () => {
      // set in init.js
      expect((await assetsRegistry.assetInfos(0, 1)).assetIndex).to.equal(1);
      expect((await assetsRegistry.assetInfos(0, 6)).assetIndex).to.equal(6);
    });
    it("set assets halo", async () => {
      // set in init.js
      expect((await assetsRegistry.assetInfos(1, 7)).assetIndex).to.equal(7);
      expect((await assetsRegistry.assetInfos(1, 26)).assetIndex).to.equal(26);
    });
  });
  describe("unique weights", async () => {
    it("uniqueWeightsForType", async () => {
      // set in init.js
      expect((await assetsRegistry.uniqueWeightsForType(0))[0]).to.equal(1000);
      expect((await assetsRegistry.uniqueWeightsForType(4))[1]).to.equal(10);
    });
  });
  describe("getters", async () => {
    it("getAssetInfo", async () => {
      expect((await assetsRegistry.getAssetInfo(0, 1))[0]).to.equal("BGND001");
    });
    it("getAssetsPerType", async () => {
      expect((await assetsRegistry.getAssetsPerType(0))[0][0]).to.equal("BGND001");
    });
    it("getAssetsPerTypePerWeight", async () => {
      expect((await assetsRegistry.getAssetsPerTypePerWeight(0, 250))[0][0]).to.equal("BGND002");
      expect((await assetsRegistry.getAssetsPerTypePerWeight(0, 250))[0][1]).to.equal(250);
    });
    it("getAssetsPerTypePerWeightRange", async () => {
      expect((await assetsRegistry.getAssetsPerTypePerWeightRange(0, 100, 1000))[0][0]).to.equal("BGND001");
      expect((await assetsRegistry.getAssetsPerTypePerWeightRange(3, 0, 800))[0][1]).to.equal(250);
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
