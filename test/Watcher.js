const { ZERO_ADDRESS } = require("@openzeppelin/test-helpers/src/constants");
const { expect } = require("chai");
const { args } = require("./helpers/arguments");
const { assets } = require("./helpers/assets");
const { Class, classLimits } = require("./helpers/classLimits");
const { init } = require("./helpers/init");
const { toBN, toWei, snapshot, restore, increaseTime, increaseTimeTo, getTime, getCosts } = require("./helpers/utils");

describe("Watcher", async () => {
  let watcher;
  let keter;
  let owner;
  let user1, user2, user3, user4, user5, user6;

  before("setup", async () => {
    const setups = await init(false);
    owner = setups.users[0];
    user1 = setups.users[1];
    user2 = setups.users[2];
    user3 = setups.users[3];
    user4 = setups.users[4];
    user5 = setups.users[5];
    user6 = setups.users[6];

    watcher = setups.watcher;
    soul = setups.soul;

    await soul.mint(user1.address, toWei("100000"));
    await soul.mint(user2.address, toWei("100000"));
    await soul.mint(user3.address, toWei("100000"));
    await soul.mint(user4.address, toWei("100000"));
    await soul.mint(user5.address, toWei("100000"));
    await soul.mint(user6.address, toWei("100000"));

    await snapshot();
  });

  afterEach("revert", async () => {
    await restore();
  });

  describe("triggerBatchSale", async () => {
    it("open sale for batch of 7 watchers", async () => {
      for (let i = 0; i < 7; i++) {
        expect(await watcher.openToSale(i)).to.equal(false);
      }
      expect(await watcher.openToSale(7)).to.equal(false);
      expect(await watcher.openToSale(1000)).to.equal(false);

      await watcher.triggerBatchSale();

      for (let i = 0; i < 7; i++) {
        expect(await watcher.openToSale(i)).to.equal(true);
      }
      expect(await watcher.openToSale(7)).to.equal(false);
      expect(await watcher.openToSale(1000)).to.equal(false);
    });
    it("open sale for batch of 7 watchers after first batch sold", async () => {
      for (let i = 0; i < 7; i++) {
        expect(await watcher.openToSale(i)).to.equal(false);
      }
      expect(await watcher.openToSale(7)).to.equal(false);
      expect(await watcher.openToSale(1000)).to.equal(false);

      await watcher.triggerBatchSale();

      for (let i = 0; i < 7; i++) {
        expect(await watcher.openToSale(i)).to.equal(true);
      }
      expect(await watcher.openToSale(7)).to.equal(false);
      expect(await watcher.openToSale(1000)).to.equal(false);

      const priceInSouls = await watcher.priceInSouls();

      await soul.connect(user1).approve(watcher.address, priceInSouls);
      await watcher.connect(user1).claimWatcher();
      await soul.connect(user1).approve(watcher.address, priceInSouls);
      await watcher.connect(user1).claimWatcher();
      await soul.connect(user2).approve(watcher.address, priceInSouls);
      await watcher.connect(user2).claimWatcher();
      await soul.connect(user2).approve(watcher.address, priceInSouls);
      await watcher.connect(user2).claimWatcher();
      await soul.connect(user3).approve(watcher.address, priceInSouls);
      await watcher.connect(user3).claimWatcher();
      await soul.connect(user3).approve(watcher.address, priceInSouls);
      await watcher.connect(user3).claimWatcher();
      await soul.connect(user4).approve(watcher.address, priceInSouls);
      await watcher.connect(user4).claimWatcher();

      for (let i = 0; i < 14; i++) {
        expect(await watcher.openToSale(i)).to.equal(false);
      }
      expect(await watcher.openToSale(1000)).to.equal(false);

      await watcher.triggerBatchSale();

      for (let i = 0; i < 7; i++) {
        expect(await watcher.openToSale(i)).to.equal(false);
      }
      for (let i = 7; i < 14; i++) {
        expect(await watcher.openToSale(i)).to.equal(true);
      }
      expect(await watcher.openToSale(1000)).to.equal(false);
    });
  });
  describe("claimWatcher", async () => {
    it("does not mint watcher if not open to sale", async () => {
      const reason = "No watcher on sale";

      const priceInSouls = await watcher.priceInSouls();

      await soul.connect(user1).approve(watcher.address, priceInSouls);
      await expect(watcher.connect(user1).claimWatcher()).to.be.revertedWith(reason);
    });
    it("mint watcher succesfully", async () => {
      await watcher.triggerBatchSale();

      const priceInSouls = await watcher.priceInSouls();

      await soul.connect(user1).approve(watcher.address, priceInSouls);
      const tx1 = await watcher.connect(user1).claimWatcher();
      await soul.connect(user1).approve(watcher.address, priceInSouls);
      const tx2 = await watcher.connect(user1).claimWatcher();
      await soul.connect(user2).approve(watcher.address, priceInSouls);
      const tx3 = await watcher.connect(user2).claimWatcher();
      await soul.connect(user2).approve(watcher.address, priceInSouls);
      const tx4 = await watcher.connect(user2).claimWatcher();
      await soul.connect(user3).approve(watcher.address, priceInSouls);
      const tx5 = await watcher.connect(user3).claimWatcher();
      await soul.connect(user3).approve(watcher.address, priceInSouls);
      const tx6 = await watcher.connect(user3).claimWatcher();
      await soul.connect(user4).approve(watcher.address, priceInSouls);
      const tx7 = await watcher.connect(user4).claimWatcher();

      expect(tx1).to.changeTokenBalance(soul, user1, priceInSouls);
      expect(tx1).to.changeTokenBalance(soul, watcher.address, 0);
      expect(tx1).to.changeTokenBalance(watcher, user1, 1);
      expect(await watcher.ownerOf(0)).to.equal(user1.address);

      expect(tx2).to.changeTokenBalance(soul, user1, priceInSouls);
      expect(tx2).to.changeTokenBalance(soul, watcher.address, 0);
      expect(tx2).to.changeTokenBalance(watcher, user1, 1);
      expect(await watcher.ownerOf(1)).to.equal(user1.address);

      expect(tx3).to.changeTokenBalance(soul, user2, priceInSouls);
      expect(tx3).to.changeTokenBalance(soul, watcher.address, 0);
      expect(tx3).to.changeTokenBalance(watcher, user2, 1);
      expect(await watcher.ownerOf(2)).to.equal(user2.address);

      expect(tx4).to.changeTokenBalance(soul, user2, priceInSouls);
      expect(tx4).to.changeTokenBalance(soul, watcher.address, 0);
      expect(tx4).to.changeTokenBalance(watcher, user2, 1);
      expect(await watcher.ownerOf(3)).to.equal(user2.address);

      expect(tx5).to.changeTokenBalance(soul, user3, priceInSouls);
      expect(tx5).to.changeTokenBalance(soul, watcher.address, 0);
      expect(tx5).to.changeTokenBalance(watcher, user3, 1);
      expect(await watcher.ownerOf(4)).to.equal(user3.address);

      expect(tx6).to.changeTokenBalance(soul, user3, priceInSouls);
      expect(tx6).to.changeTokenBalance(soul, watcher.address, 0);
      expect(tx6).to.changeTokenBalance(watcher, user3, 1);
      expect(await watcher.ownerOf(5)).to.equal(user3.address);

      expect(tx7).to.changeTokenBalance(soul, user4, priceInSouls);
      expect(tx7).to.changeTokenBalance(soul, watcher.address, 0);
      expect(tx7).to.changeTokenBalance(watcher, user4, 1);
      expect(await watcher.ownerOf(6)).to.equal(user4.address);
    });
    it("emit WatcherMinted event", async () => {
      await watcher.triggerBatchSale();

      const priceInSouls = await watcher.priceInSouls();

      await soul.connect(user1).approve(watcher.address, priceInSouls);
      await expect(watcher.connect(user1).claimWatcher())
        .to.emit(watcher, "WatcherMinted")
        .withArgs(user1.address, 0, (await getTime()).toString());
    });
  });
});
