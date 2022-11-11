const { ZERO_ADDRESS } = require("@openzeppelin/test-helpers/src/constants");
const { expect } = require("chai");
const { args } = require("./helpers/arguments");
const { assets } = require("./helpers/assets");
const { Class, classLimits } = require("./helpers/classLimits");
const { init } = require("./helpers/init");
const { toBN, toWei, snapshot, restore, increaseTime, increaseTimeTo, getTime, getCosts } = require("./helpers/utils");

describe("Archangel", async () => {
  let archangel;
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

    archangel = setups.archangel;
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
    it("open sale for batch of 7 archangels", async () => {
      for (let i = 0; i < 7; i++) {
        expect(await archangel.openToSale(i)).to.equal(false);
      }
      expect(await archangel.openToSale(7)).to.equal(false);
      expect(await archangel.openToSale(1000)).to.equal(false);

      await archangel.triggerBatchSale();

      for (let i = 0; i < 7; i++) {
        expect(await archangel.openToSale(i)).to.equal(true);
      }
      expect(await archangel.openToSale(7)).to.equal(false);
      expect(await archangel.openToSale(1000)).to.equal(false);
    });
    it("open sale for batch of 7 archangels after first batch sold", async () => {
      for (let i = 0; i < 7; i++) {
        expect(await archangel.openToSale(i)).to.equal(false);
      }
      expect(await archangel.openToSale(7)).to.equal(false);
      expect(await archangel.openToSale(1000)).to.equal(false);

      await archangel.triggerBatchSale();

      for (let i = 0; i < 7; i++) {
        expect(await archangel.openToSale(i)).to.equal(true);
      }
      expect(await archangel.openToSale(7)).to.equal(false);
      expect(await archangel.openToSale(1000)).to.equal(false);

      const priceInSouls = await archangel.priceInSouls();

      await soul.connect(user1).approve(archangel.address, priceInSouls);
      await archangel.connect(user1).claimArchangel();
      await soul.connect(user1).approve(archangel.address, priceInSouls);
      await archangel.connect(user1).claimArchangel();
      await soul.connect(user2).approve(archangel.address, priceInSouls);
      await archangel.connect(user2).claimArchangel();
      await soul.connect(user2).approve(archangel.address, priceInSouls);
      await archangel.connect(user2).claimArchangel();
      await soul.connect(user3).approve(archangel.address, priceInSouls);
      await archangel.connect(user3).claimArchangel();
      await soul.connect(user3).approve(archangel.address, priceInSouls);
      await archangel.connect(user3).claimArchangel();
      await soul.connect(user4).approve(archangel.address, priceInSouls);
      await archangel.connect(user4).claimArchangel();

      for (let i = 0; i < 14; i++) {
        expect(await archangel.openToSale(i)).to.equal(false);
      }
      expect(await archangel.openToSale(1000)).to.equal(false);

      await archangel.triggerBatchSale();

      for (let i = 0; i < 7; i++) {
        expect(await archangel.openToSale(i)).to.equal(false);
      }
      for (let i = 7; i < 14; i++) {
        expect(await archangel.openToSale(i)).to.equal(true);
      }
      expect(await archangel.openToSale(1000)).to.equal(false);
    });
  });
  describe("claimArchangel", async () => {
    it("does not mint archangel if not open to sale", async () => {
      const reason = "No archangel on sale";

      const priceInSouls = await archangel.priceInSouls();

      await soul.connect(user1).approve(archangel.address, priceInSouls);
      await expect(archangel.connect(user1).claimArchangel()).to.be.revertedWith(reason);
    });
    it("mint archangel succesfully", async () => {
      await archangel.triggerBatchSale();

      const priceInSouls = await archangel.priceInSouls();

      await soul.connect(user1).approve(archangel.address, priceInSouls);
      const tx1 = await archangel.connect(user1).claimArchangel();
      await soul.connect(user1).approve(archangel.address, priceInSouls);
      const tx2 = await archangel.connect(user1).claimArchangel();
      await soul.connect(user2).approve(archangel.address, priceInSouls);
      const tx3 = await archangel.connect(user2).claimArchangel();
      await soul.connect(user2).approve(archangel.address, priceInSouls);
      const tx4 = await archangel.connect(user2).claimArchangel();
      await soul.connect(user3).approve(archangel.address, priceInSouls);
      const tx5 = await archangel.connect(user3).claimArchangel();
      await soul.connect(user3).approve(archangel.address, priceInSouls);
      const tx6 = await archangel.connect(user3).claimArchangel();
      await soul.connect(user4).approve(archangel.address, priceInSouls);
      const tx7 = await archangel.connect(user4).claimArchangel();

      expect(tx1).to.changeTokenBalance(soul, user1, priceInSouls);
      expect(tx1).to.changeTokenBalance(soul, archangel.address, 0);
      expect(tx1).to.changeTokenBalance(archangel, user1, 1);
      expect(await archangel.ownerOf(0)).to.equal(user1.address);

      expect(tx2).to.changeTokenBalance(soul, user1, priceInSouls);
      expect(tx2).to.changeTokenBalance(soul, archangel.address, 0);
      expect(tx2).to.changeTokenBalance(archangel, user1, 1);
      expect(await archangel.ownerOf(1)).to.equal(user1.address);

      expect(tx3).to.changeTokenBalance(soul, user2, priceInSouls);
      expect(tx3).to.changeTokenBalance(soul, archangel.address, 0);
      expect(tx3).to.changeTokenBalance(archangel, user2, 1);
      expect(await archangel.ownerOf(2)).to.equal(user2.address);

      expect(tx4).to.changeTokenBalance(soul, user2, priceInSouls);
      expect(tx4).to.changeTokenBalance(soul, archangel.address, 0);
      expect(tx4).to.changeTokenBalance(archangel, user2, 1);
      expect(await archangel.ownerOf(3)).to.equal(user2.address);

      expect(tx5).to.changeTokenBalance(soul, user3, priceInSouls);
      expect(tx5).to.changeTokenBalance(soul, archangel.address, 0);
      expect(tx5).to.changeTokenBalance(archangel, user3, 1);
      expect(await archangel.ownerOf(4)).to.equal(user3.address);

      expect(tx6).to.changeTokenBalance(soul, user3, priceInSouls);
      expect(tx6).to.changeTokenBalance(soul, archangel.address, 0);
      expect(tx6).to.changeTokenBalance(archangel, user3, 1);
      expect(await archangel.ownerOf(5)).to.equal(user3.address);

      expect(tx7).to.changeTokenBalance(soul, user4, priceInSouls);
      expect(tx7).to.changeTokenBalance(soul, archangel.address, 0);
      expect(tx7).to.changeTokenBalance(archangel, user4, 1);
      expect(await archangel.ownerOf(6)).to.equal(user4.address);
    });
    it("emit ArchangelMinted event", async () => {
      await archangel.triggerBatchSale();

      const priceInSouls = await archangel.priceInSouls();

      await soul.connect(user1).approve(archangel.address, priceInSouls);
      await expect(archangel.connect(user1).claimArchangel())
        .to.emit(archangel, "ArchangelMinted")
        .withArgs(user1.address, 0, (await getTime()).toString());
    });
  });
});
