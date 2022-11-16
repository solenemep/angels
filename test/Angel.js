const { ZERO_ADDRESS } = require("@openzeppelin/test-helpers/src/constants");
const { expect } = require("chai");
const { args } = require("./helpers/arguments");
const { assets } = require("./helpers/assets");
const { Class, classLimits } = require("./helpers/classLimits");
const { init } = require("./helpers/init");
const { toBN, toWei, snapshot, restore, increaseTime, increaseTimeTo, getTime, getCosts } = require("./helpers/utils");

describe("Angel", async () => {
  let archangel;
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
    let angel;

    beforeEach("setup", async () => {
      if (setup == "archangel") {
        angel = archangel;
      } else if (setup == "watcher") {
        angel = watcher;
      }
    });

    describe("triggerBatchSale", async () => {
      it(`open sale for batch of 7 ${setup} x1`, async () => {
        const priceInSouls = await angel.priceInSouls();

        for (let i = 0; i < 7; i++) {
          expect(await angel.openToSale(i)).to.equal(false);
        }
        expect(await angel.openToSale(7)).to.equal(false);
        expect(await angel.openToSale(1000)).to.equal(false);

        expect(await angel.angelsLeft()).to.equal(0);
        expect(await angel.getBatchIndex()).to.equal(0);

        await angel.triggerBatchSale(priceInSouls);
        expect(await angel.getBatchIndex()).to.equal(1);

        for (let i = 0; i < 7; i++) {
          expect(await angel.openToSale(i)).to.equal(true);
        }
        expect(await angel.openToSale(7)).to.equal(false);
        expect(await angel.openToSale(1000)).to.equal(false);

        expect(await angel.angelsLeft()).to.equal(7);
        expect(await angel.getBatchIndex()).to.equal(1);

        await soul.connect(user1).approve(angel.address, priceInSouls);
        await angel.connect(user1).claimAngel();
        await soul.connect(user1).approve(angel.address, priceInSouls);
        await angel.connect(user1).claimAngel();
        await soul.connect(user2).approve(angel.address, priceInSouls);
        await angel.connect(user2).claimAngel();

        expect(await angel.angelsLeft()).to.equal(4);
        expect(await angel.getBatchIndex()).to.equal(1);

        await soul.connect(user2).approve(angel.address, priceInSouls);
        await angel.connect(user2).claimAngel();
        await soul.connect(user3).approve(angel.address, priceInSouls);
        await angel.connect(user3).claimAngel();
        await soul.connect(user3).approve(angel.address, priceInSouls);
        await angel.connect(user3).claimAngel();
        await soul.connect(user4).approve(angel.address, priceInSouls);
        await angel.connect(user4).claimAngel();

        for (let i = 0; i < 7; i++) {
          expect(await angel.openToSale(i)).to.equal(false);
        }
        expect(await angel.openToSale(1000)).to.equal(false);

        expect(await angel.angelsLeft()).to.equal(0);
        expect(await angel.getBatchIndex()).to.equal(1);
      });
      it(`open sale for batch of 7 ${setup} x2`, async () => {
        const priceInSouls = await angel.priceInSouls();

        // 1
        await angel.triggerBatchSale(priceInSouls);
        expect(await angel.getBatchIndex()).to.equal(1);

        await soul.connect(user1).approve(angel.address, priceInSouls);
        await angel.connect(user1).claimAngel();
        await soul.connect(user1).approve(angel.address, priceInSouls);
        await angel.connect(user1).claimAngel();
        await soul.connect(user2).approve(angel.address, priceInSouls);
        await angel.connect(user2).claimAngel();
        await soul.connect(user2).approve(angel.address, priceInSouls);
        await angel.connect(user2).claimAngel();
        await soul.connect(user3).approve(angel.address, priceInSouls);
        await angel.connect(user3).claimAngel();
        await soul.connect(user3).approve(angel.address, priceInSouls);
        await angel.connect(user3).claimAngel();
        await soul.connect(user4).approve(angel.address, priceInSouls);
        await angel.connect(user4).claimAngel();

        for (let i = 0; i < 14; i++) {
          expect(await angel.openToSale(i)).to.equal(false);
        }
        expect(await angel.openToSale(1000)).to.equal(false);

        expect(await angel.angelsLeft()).to.equal(0);
        expect(await angel.getBatchIndex()).to.equal(1);

        // 2
        await angel.triggerBatchSale(priceInSouls);
        expect(await angel.getBatchIndex()).to.equal(2);

        for (let i = 0; i < 7; i++) {
          expect(await angel.openToSale(i)).to.equal(false);
        }
        for (let i = 7; i < 14; i++) {
          expect(await angel.openToSale(i)).to.equal(true);
        }
        expect(await angel.openToSale(1000)).to.equal(false);

        expect(await angel.angelsLeft()).to.equal(7);
        expect(await angel.getBatchIndex()).to.equal(2);

        await soul.connect(user1).approve(angel.address, priceInSouls);
        await angel.connect(user1).claimAngel();
        await soul.connect(user1).approve(angel.address, priceInSouls);
        await angel.connect(user1).claimAngel();
        await soul.connect(user2).approve(angel.address, priceInSouls);
        await angel.connect(user2).claimAngel();

        expect(await angel.angelsLeft()).to.equal(4);
        expect(await angel.getBatchIndex()).to.equal(2);

        await soul.connect(user2).approve(angel.address, priceInSouls);
        await angel.connect(user2).claimAngel();
        await soul.connect(user3).approve(angel.address, priceInSouls);
        await angel.connect(user3).claimAngel();
        await soul.connect(user3).approve(angel.address, priceInSouls);
        await angel.connect(user3).claimAngel();
        await soul.connect(user4).approve(angel.address, priceInSouls);
        await angel.connect(user4).claimAngel();

        for (let i = 0; i < 14; i++) {
          expect(await angel.openToSale(i)).to.equal(false);
        }
        expect(await angel.openToSale(1000)).to.equal(false);

        expect(await angel.angelsLeft()).to.equal(0);
        expect(await angel.getBatchIndex()).to.equal(2);
      });
      it(`open sale for batch of 7 ${setup} x3`, async () => {
        const priceInSouls = await angel.priceInSouls();

        // 1
        await angel.triggerBatchSale(priceInSouls);
        expect(await angel.getBatchIndex()).to.equal(1);

        await soul.connect(user1).approve(angel.address, priceInSouls);
        await angel.connect(user1).claimAngel();
        await soul.connect(user1).approve(angel.address, priceInSouls);
        await angel.connect(user1).claimAngel();
        await soul.connect(user2).approve(angel.address, priceInSouls);
        await angel.connect(user2).claimAngel();
        await soul.connect(user2).approve(angel.address, priceInSouls);
        await angel.connect(user2).claimAngel();
        await soul.connect(user3).approve(angel.address, priceInSouls);
        await angel.connect(user3).claimAngel();
        await soul.connect(user3).approve(angel.address, priceInSouls);
        await angel.connect(user3).claimAngel();
        await soul.connect(user4).approve(angel.address, priceInSouls);
        await angel.connect(user4).claimAngel();

        // 2
        await angel.triggerBatchSale(priceInSouls);
        expect(await angel.getBatchIndex()).to.equal(2);

        await soul.connect(user1).approve(angel.address, priceInSouls);
        await angel.connect(user1).claimAngel();
        await soul.connect(user1).approve(angel.address, priceInSouls);
        await angel.connect(user1).claimAngel();
        await soul.connect(user2).approve(angel.address, priceInSouls);
        await angel.connect(user2).claimAngel();
        await soul.connect(user2).approve(angel.address, priceInSouls);
        await angel.connect(user2).claimAngel();
        await soul.connect(user3).approve(angel.address, priceInSouls);
        await angel.connect(user3).claimAngel();
        await soul.connect(user3).approve(angel.address, priceInSouls);
        await angel.connect(user3).claimAngel();
        await soul.connect(user4).approve(angel.address, priceInSouls);
        await angel.connect(user4).claimAngel();

        for (let i = 0; i < 21; i++) {
          expect(await angel.openToSale(i)).to.equal(false);
        }
        expect(await angel.openToSale(1000)).to.equal(false);

        expect(await angel.angelsLeft()).to.equal(0);
        expect(await angel.getBatchIndex()).to.equal(2);

        // 3
        await angel.triggerBatchSale(priceInSouls);
        expect(await angel.getBatchIndex()).to.equal(3);

        for (let i = 0; i < 14; i++) {
          expect(await angel.openToSale(i)).to.equal(false);
        }
        for (let i = 14; i < 21; i++) {
          expect(await angel.openToSale(i)).to.equal(true);
        }
        expect(await angel.openToSale(1000)).to.equal(false);

        expect(await angel.angelsLeft()).to.equal(7);
        expect(await angel.getBatchIndex()).to.equal(3);

        await soul.connect(user1).approve(angel.address, priceInSouls);
        await angel.connect(user1).claimAngel();
        await soul.connect(user1).approve(angel.address, priceInSouls);
        await angel.connect(user1).claimAngel();
        await soul.connect(user2).approve(angel.address, priceInSouls);
        await angel.connect(user2).claimAngel();

        expect(await angel.angelsLeft()).to.equal(4);
        expect(await angel.getBatchIndex()).to.equal(3);

        await soul.connect(user2).approve(angel.address, priceInSouls);
        await angel.connect(user2).claimAngel();
        await soul.connect(user3).approve(angel.address, priceInSouls);
        await angel.connect(user3).claimAngel();
        await soul.connect(user3).approve(angel.address, priceInSouls);
        await angel.connect(user3).claimAngel();
        await soul.connect(user4).approve(angel.address, priceInSouls);
        await angel.connect(user4).claimAngel();

        for (let i = 0; i < 21; i++) {
          expect(await angel.openToSale(i)).to.equal(false);
        }
        expect(await angel.openToSale(1000)).to.equal(false);

        expect(await angel.angelsLeft()).to.equal(0);
        expect(await angel.getBatchIndex()).to.equal(3);
      });
    });
    describe("claimAngel", async () => {
      it(`does not mint ${setup} if not open to sale`, async () => {
        const reason = `No ${setup} on sale`;

        const priceInSouls = await angel.priceInSouls();

        await soul.connect(user1).approve(angel.address, priceInSouls);
        await expect(angel.connect(user1).claimAngel()).to.be.revertedWith(reason);
      });
      it(`mint ${setup} succesfully`, async () => {
        const priceInSouls = await angel.priceInSouls();

        await angel.triggerBatchSale(priceInSouls);

        expect(await angel.angelsLeft()).to.equal(7);

        await soul.connect(user1).approve(angel.address, priceInSouls);
        const tx1 = await angel.connect(user1).claimAngel();
        expect(await angel.angelsLeft()).to.equal(6);

        await soul.connect(user1).approve(angel.address, priceInSouls);
        const tx2 = await angel.connect(user1).claimAngel();
        expect(await angel.angelsLeft()).to.equal(5);

        await soul.connect(user2).approve(angel.address, priceInSouls);
        const tx3 = await angel.connect(user2).claimAngel();
        expect(await angel.angelsLeft()).to.equal(4);

        await soul.connect(user2).approve(angel.address, priceInSouls);
        const tx4 = await angel.connect(user2).claimAngel();
        expect(await angel.angelsLeft()).to.equal(3);

        await soul.connect(user3).approve(angel.address, priceInSouls);
        const tx5 = await angel.connect(user3).claimAngel();
        expect(await angel.angelsLeft()).to.equal(2);

        await soul.connect(user3).approve(angel.address, priceInSouls);
        const tx6 = await angel.connect(user3).claimAngel();
        expect(await angel.angelsLeft()).to.equal(1);

        await soul.connect(user4).approve(angel.address, priceInSouls);
        const tx7 = await angel.connect(user4).claimAngel();
        expect(await angel.angelsLeft()).to.equal(0);

        expect(tx1).to.changeTokenBalance(soul, user1, priceInSouls);
        expect(tx1).to.changeTokenBalance(soul, angel.address, 0);
        expect(tx1).to.changeTokenBalance(angel, user1, 1);
        expect(await angel.ownerOf(0)).to.equal(user1.address);

        expect(tx2).to.changeTokenBalance(soul, user1, priceInSouls);
        expect(tx2).to.changeTokenBalance(soul, angel.address, 0);
        expect(tx2).to.changeTokenBalance(angel, user1, 1);
        expect(await angel.ownerOf(1)).to.equal(user1.address);

        expect(tx3).to.changeTokenBalance(soul, user2, priceInSouls);
        expect(tx3).to.changeTokenBalance(soul, angel.address, 0);
        expect(tx3).to.changeTokenBalance(angel, user2, 1);
        expect(await angel.ownerOf(2)).to.equal(user2.address);

        expect(tx4).to.changeTokenBalance(soul, user2, priceInSouls);
        expect(tx4).to.changeTokenBalance(soul, angel.address, 0);
        expect(tx4).to.changeTokenBalance(angel, user2, 1);
        expect(await angel.ownerOf(3)).to.equal(user2.address);

        expect(tx5).to.changeTokenBalance(soul, user3, priceInSouls);
        expect(tx5).to.changeTokenBalance(soul, angel.address, 0);
        expect(tx5).to.changeTokenBalance(angel, user3, 1);
        expect(await angel.ownerOf(4)).to.equal(user3.address);

        expect(tx6).to.changeTokenBalance(soul, user3, priceInSouls);
        expect(tx6).to.changeTokenBalance(soul, angel.address, 0);
        expect(tx6).to.changeTokenBalance(angel, user3, 1);
        expect(await angel.ownerOf(5)).to.equal(user3.address);

        expect(tx7).to.changeTokenBalance(soul, user4, priceInSouls);
        expect(tx7).to.changeTokenBalance(soul, angel.address, 0);
        expect(tx7).to.changeTokenBalance(angel, user4, 1);
        expect(await angel.ownerOf(6)).to.equal(user4.address);
      });
      it("emit proper event", async () => {
        const priceInSouls = await angel.priceInSouls();

        await angel.triggerBatchSale(priceInSouls);

        await soul.connect(user1).approve(angel.address, priceInSouls);

        if (setup == "archangel") {
          await expect(angel.connect(user1).claimAngel())
            .to.emit(angel, "ArchangelMinted")
            .withArgs(user1.address, 0, (await getTime()).toString());
        } else if (setup == "watcher") {
          await expect(angel.connect(user1).claimAngel())
            .to.emit(angel, "WatcherMinted")
            .withArgs(user1.address, 0, (await getTime()).toString());
        }
      });
    });
  }
  main("archangel");
  main("watcher");
});
