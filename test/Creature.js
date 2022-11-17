const { ZERO_ADDRESS } = require("@openzeppelin/test-helpers/src/constants");
const { expect } = require("chai");
const { args } = require("./helpers/arguments");
const { assets } = require("./helpers/assets");
const { Class, classLimits } = require("./helpers/classLimits");
const { init } = require("./helpers/init");
const { toBN, toWei, snapshot, restore, increaseTime, increaseTimeTo, getTime, getCosts } = require("./helpers/utils");

describe("Creature", async () => {
  let archangel;
  let watcher;
  let user1, user2, user3, user4, user5, user6;
  let priceInSouls;

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

  async function main(setup) {
    let creature;

    beforeEach("setup", async () => {
      if (setup == "archangel") {
        creature = archangel;
      } else if (setup == "watcher") {
        creature = watcher;
      }

      priceInSouls = toWei("444");
    });

    describe("triggerBatchSale", async () => {
      it("does not mint creature if not open to sale", async () => {
        const reason = "Price should be higher than 0";

        priceInSouls = 0;

        await expect(creature.triggerBatchSale(priceInSouls)).to.be.revertedWith(reason);
      });
      it(`open sale for batch of 7 ${setup} x1`, async () => {
        for (let i = 0; i < 7; i++) {
          expect(await creature.isOnSale(i)).to.equal(false);
        }
        expect(await creature.isOnSale(7)).to.equal(false);
        expect(await creature.isOnSale(1000)).to.equal(false);

        expect(await creature.currentBatchMinted()).to.equal(0);
        expect(await creature.currentBacthLeft()).to.equal(0);
        expect(await creature.currentBacthIndex()).to.equal(0);

        await creature.triggerBatchSale(priceInSouls);
        expect(await creature.currentBacthIndex()).to.equal(1);

        for (let i = 0; i < 7; i++) {
          expect(await creature.isOnSale(i)).to.equal(true);
        }
        expect(await creature.isOnSale(7)).to.equal(false);
        expect(await creature.isOnSale(1000)).to.equal(false);

        expect(await creature.currentBatchMinted()).to.equal(0);
        expect(await creature.currentBacthLeft()).to.equal(7);
        expect(await creature.currentBacthIndex()).to.equal(1);

        await soul.connect(user1).approve(creature.address, priceInSouls);
        await creature.connect(user1).claimCreature();
        await soul.connect(user1).approve(creature.address, priceInSouls);
        await creature.connect(user1).claimCreature();
        await soul.connect(user2).approve(creature.address, priceInSouls);
        await creature.connect(user2).claimCreature();

        expect(await creature.currentBatchMinted()).to.equal(3);
        expect(await creature.currentBacthLeft()).to.equal(4);
        expect(await creature.currentBacthIndex()).to.equal(1);

        await soul.connect(user2).approve(creature.address, priceInSouls);
        await creature.connect(user2).claimCreature();
        await soul.connect(user3).approve(creature.address, priceInSouls);
        await creature.connect(user3).claimCreature();
        await soul.connect(user3).approve(creature.address, priceInSouls);
        await creature.connect(user3).claimCreature();
        await soul.connect(user4).approve(creature.address, priceInSouls);
        await creature.connect(user4).claimCreature();

        for (let i = 0; i < 7; i++) {
          expect(await creature.isOnSale(i)).to.equal(false);
        }
        expect(await creature.isOnSale(1000)).to.equal(false);

        expect(await creature.currentBatchMinted()).to.equal(7);
        expect(await creature.currentBacthLeft()).to.equal(0);
        expect(await creature.currentBacthIndex()).to.equal(1);
      });
      it(`open sale for batch of 7 ${setup} x2`, async () => {
        // 1
        await creature.triggerBatchSale(priceInSouls);
        expect(await creature.currentBacthIndex()).to.equal(1);

        await soul.connect(user1).approve(creature.address, priceInSouls);
        await creature.connect(user1).claimCreature();
        await soul.connect(user1).approve(creature.address, priceInSouls);
        await creature.connect(user1).claimCreature();
        await soul.connect(user2).approve(creature.address, priceInSouls);
        await creature.connect(user2).claimCreature();
        await soul.connect(user2).approve(creature.address, priceInSouls);
        await creature.connect(user2).claimCreature();
        await soul.connect(user3).approve(creature.address, priceInSouls);
        await creature.connect(user3).claimCreature();
        await soul.connect(user3).approve(creature.address, priceInSouls);
        await creature.connect(user3).claimCreature();
        await soul.connect(user4).approve(creature.address, priceInSouls);
        await creature.connect(user4).claimCreature();

        for (let i = 0; i < 14; i++) {
          expect(await creature.isOnSale(i)).to.equal(false);
        }
        expect(await creature.isOnSale(1000)).to.equal(false);

        expect(await creature.currentBatchMinted()).to.equal(7);
        expect(await creature.currentBacthLeft()).to.equal(0);
        expect(await creature.currentBacthIndex()).to.equal(1);

        // 2
        await creature.triggerBatchSale(priceInSouls);
        expect(await creature.currentBacthIndex()).to.equal(2);

        for (let i = 0; i < 7; i++) {
          expect(await creature.isOnSale(i)).to.equal(false);
        }
        for (let i = 7; i < 14; i++) {
          expect(await creature.isOnSale(i)).to.equal(true);
        }
        expect(await creature.isOnSale(1000)).to.equal(false);

        expect(await creature.currentBatchMinted()).to.equal(0);
        expect(await creature.currentBacthLeft()).to.equal(7);
        expect(await creature.currentBacthIndex()).to.equal(2);

        await soul.connect(user1).approve(creature.address, priceInSouls);
        await creature.connect(user1).claimCreature();
        await soul.connect(user1).approve(creature.address, priceInSouls);
        await creature.connect(user1).claimCreature();
        await soul.connect(user2).approve(creature.address, priceInSouls);
        await creature.connect(user2).claimCreature();

        expect(await creature.currentBatchMinted()).to.equal(3);
        expect(await creature.currentBacthLeft()).to.equal(4);
        expect(await creature.currentBacthIndex()).to.equal(2);

        await soul.connect(user2).approve(creature.address, priceInSouls);
        await creature.connect(user2).claimCreature();
        await soul.connect(user3).approve(creature.address, priceInSouls);
        await creature.connect(user3).claimCreature();
        await soul.connect(user3).approve(creature.address, priceInSouls);
        await creature.connect(user3).claimCreature();
        await soul.connect(user4).approve(creature.address, priceInSouls);
        await creature.connect(user4).claimCreature();

        for (let i = 0; i < 14; i++) {
          expect(await creature.isOnSale(i)).to.equal(false);
        }
        expect(await creature.isOnSale(1000)).to.equal(false);

        expect(await creature.currentBatchMinted()).to.equal(7);
        expect(await creature.currentBacthLeft()).to.equal(0);
        expect(await creature.currentBacthIndex()).to.equal(2);
      });
      it(`open sale for batch of 7 ${setup} x3`, async () => {
        // 1
        await creature.triggerBatchSale(priceInSouls);
        expect(await creature.currentBacthIndex()).to.equal(1);

        await soul.connect(user1).approve(creature.address, priceInSouls);
        await creature.connect(user1).claimCreature();
        await soul.connect(user1).approve(creature.address, priceInSouls);
        await creature.connect(user1).claimCreature();
        await soul.connect(user2).approve(creature.address, priceInSouls);
        await creature.connect(user2).claimCreature();
        await soul.connect(user2).approve(creature.address, priceInSouls);
        await creature.connect(user2).claimCreature();
        await soul.connect(user3).approve(creature.address, priceInSouls);
        await creature.connect(user3).claimCreature();
        await soul.connect(user3).approve(creature.address, priceInSouls);
        await creature.connect(user3).claimCreature();
        await soul.connect(user4).approve(creature.address, priceInSouls);
        await creature.connect(user4).claimCreature();

        // 2
        await creature.triggerBatchSale(priceInSouls);
        expect(await creature.currentBacthIndex()).to.equal(2);

        await soul.connect(user1).approve(creature.address, priceInSouls);
        await creature.connect(user1).claimCreature();
        await soul.connect(user1).approve(creature.address, priceInSouls);
        await creature.connect(user1).claimCreature();
        await soul.connect(user2).approve(creature.address, priceInSouls);
        await creature.connect(user2).claimCreature();
        await soul.connect(user2).approve(creature.address, priceInSouls);
        await creature.connect(user2).claimCreature();
        await soul.connect(user3).approve(creature.address, priceInSouls);
        await creature.connect(user3).claimCreature();
        await soul.connect(user3).approve(creature.address, priceInSouls);
        await creature.connect(user3).claimCreature();
        await soul.connect(user4).approve(creature.address, priceInSouls);
        await creature.connect(user4).claimCreature();

        for (let i = 0; i < 21; i++) {
          expect(await creature.isOnSale(i)).to.equal(false);
        }
        expect(await creature.isOnSale(1000)).to.equal(false);

        expect(await creature.currentBatchMinted()).to.equal(7);
        expect(await creature.currentBacthLeft()).to.equal(0);
        expect(await creature.currentBacthIndex()).to.equal(2);

        // 3
        await creature.triggerBatchSale(priceInSouls);
        expect(await creature.currentBacthIndex()).to.equal(3);

        for (let i = 0; i < 14; i++) {
          expect(await creature.isOnSale(i)).to.equal(false);
        }
        for (let i = 14; i < 21; i++) {
          expect(await creature.isOnSale(i)).to.equal(true);
        }
        expect(await creature.isOnSale(1000)).to.equal(false);

        expect(await creature.currentBatchMinted()).to.equal(0);
        expect(await creature.currentBacthLeft()).to.equal(7);
        expect(await creature.currentBacthIndex()).to.equal(3);

        await soul.connect(user1).approve(creature.address, priceInSouls);
        await creature.connect(user1).claimCreature();
        await soul.connect(user1).approve(creature.address, priceInSouls);
        await creature.connect(user1).claimCreature();
        await soul.connect(user2).approve(creature.address, priceInSouls);
        await creature.connect(user2).claimCreature();

        expect(await creature.currentBatchMinted()).to.equal(3);
        expect(await creature.currentBacthLeft()).to.equal(4);
        expect(await creature.currentBacthIndex()).to.equal(3);

        await soul.connect(user2).approve(creature.address, priceInSouls);
        await creature.connect(user2).claimCreature();
        await soul.connect(user3).approve(creature.address, priceInSouls);
        await creature.connect(user3).claimCreature();
        await soul.connect(user3).approve(creature.address, priceInSouls);
        await creature.connect(user3).claimCreature();
        await soul.connect(user4).approve(creature.address, priceInSouls);
        await creature.connect(user4).claimCreature();

        for (let i = 0; i < 21; i++) {
          expect(await creature.isOnSale(i)).to.equal(false);
        }
        expect(await creature.isOnSale(1000)).to.equal(false);

        expect(await creature.currentBatchMinted()).to.equal(7);
        expect(await creature.currentBacthLeft()).to.equal(0);
        expect(await creature.currentBacthIndex()).to.equal(3);
      });
    });
    describe("claimCreature", async () => {
      it("does not mint creature if not open to sale", async () => {
        const reason = "No creature on sale";

        await soul.connect(user1).approve(creature.address, priceInSouls);
        await expect(creature.connect(user1).claimCreature()).to.be.revertedWith(reason);
      });
      it("mint creature succesfully", async () => {
        await creature.triggerBatchSale(priceInSouls);

        expect(await creature.currentBatchMinted()).to.equal(0);
        expect(await creature.currentBacthLeft()).to.equal(7);

        await soul.connect(user1).approve(creature.address, priceInSouls);
        const tx1 = await creature.connect(user1).claimCreature();
        expect(await creature.currentBatchMinted()).to.equal(1);
        expect(await creature.currentBacthLeft()).to.equal(6);

        await soul.connect(user1).approve(creature.address, priceInSouls);
        const tx2 = await creature.connect(user1).claimCreature();
        expect(await creature.currentBatchMinted()).to.equal(2);
        expect(await creature.currentBacthLeft()).to.equal(5);

        await soul.connect(user2).approve(creature.address, priceInSouls);
        const tx3 = await creature.connect(user2).claimCreature();
        expect(await creature.currentBatchMinted()).to.equal(3);
        expect(await creature.currentBacthLeft()).to.equal(4);

        await soul.connect(user2).approve(creature.address, priceInSouls);
        const tx4 = await creature.connect(user2).claimCreature();
        expect(await creature.currentBatchMinted()).to.equal(4);
        expect(await creature.currentBacthLeft()).to.equal(3);

        await soul.connect(user3).approve(creature.address, priceInSouls);
        const tx5 = await creature.connect(user3).claimCreature();
        expect(await creature.currentBatchMinted()).to.equal(5);
        expect(await creature.currentBacthLeft()).to.equal(2);

        await soul.connect(user3).approve(creature.address, priceInSouls);
        const tx6 = await creature.connect(user3).claimCreature();
        expect(await creature.currentBatchMinted()).to.equal(6);
        expect(await creature.currentBacthLeft()).to.equal(1);

        await soul.connect(user4).approve(creature.address, priceInSouls);
        const tx7 = await creature.connect(user4).claimCreature();
        expect(await creature.currentBatchMinted()).to.equal(7);
        expect(await creature.currentBacthLeft()).to.equal(0);

        expect(tx1).to.changeTokenBalance(soul, user1, priceInSouls);
        expect(tx1).to.changeTokenBalance(soul, creature.address, 0);
        expect(tx1).to.changeTokenBalance(creature, user1, 1);
        expect(await creature.ownerOf(0)).to.equal(user1.address);

        expect(tx2).to.changeTokenBalance(soul, user1, priceInSouls);
        expect(tx2).to.changeTokenBalance(soul, creature.address, 0);
        expect(tx2).to.changeTokenBalance(creature, user1, 1);
        expect(await creature.ownerOf(1)).to.equal(user1.address);

        expect(tx3).to.changeTokenBalance(soul, user2, priceInSouls);
        expect(tx3).to.changeTokenBalance(soul, creature.address, 0);
        expect(tx3).to.changeTokenBalance(creature, user2, 1);
        expect(await creature.ownerOf(2)).to.equal(user2.address);

        expect(tx4).to.changeTokenBalance(soul, user2, priceInSouls);
        expect(tx4).to.changeTokenBalance(soul, creature.address, 0);
        expect(tx4).to.changeTokenBalance(creature, user2, 1);
        expect(await creature.ownerOf(3)).to.equal(user2.address);

        expect(tx5).to.changeTokenBalance(soul, user3, priceInSouls);
        expect(tx5).to.changeTokenBalance(soul, creature.address, 0);
        expect(tx5).to.changeTokenBalance(creature, user3, 1);
        expect(await creature.ownerOf(4)).to.equal(user3.address);

        expect(tx6).to.changeTokenBalance(soul, user3, priceInSouls);
        expect(tx6).to.changeTokenBalance(soul, creature.address, 0);
        expect(tx6).to.changeTokenBalance(creature, user3, 1);
        expect(await creature.ownerOf(5)).to.equal(user3.address);

        expect(tx7).to.changeTokenBalance(soul, user4, priceInSouls);
        expect(tx7).to.changeTokenBalance(soul, creature.address, 0);
        expect(tx7).to.changeTokenBalance(creature, user4, 1);
        expect(await creature.ownerOf(6)).to.equal(user4.address);
      });
      it("emit CreatureMinted event", async () => {
        await creature.triggerBatchSale(priceInSouls);

        await soul.connect(user1).approve(creature.address, priceInSouls);

        await expect(creature.connect(user1).claimCreature())
          .to.emit(creature, "CreatureMinted")
          .withArgs(user1.address, 0, (await getTime()).toString());
      });
    });
  }
  main("archangel");
  main("watcher");
});
