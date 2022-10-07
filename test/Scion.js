const { expect } = require("chai");
const { args } = require("./helpers/arguments");
const { assets } = require("./helpers/assets");
const { classLimits } = require("./helpers/classLimits");
const { init } = require("./helpers/init");
const {
  toBN,
  toWei,
  snapshot,
  restore,
  getTime,
  getCosts,
} = require("./helpers/utils");

describe("Scion", async () => {
  let assetRegistry;
  let keter;
  let mintPasses;
  let scion;
  let owner;
  let user1, user2, user3, user4, user5, user6;

  const AUCTION_DURATION = 3 * 24 * 60; // 3 days (in minutes)

  const BidClass = {
    NONE: 0,
    BRONZE: 1,
    SILVER: 2,
    GOLD: 3,
    PLATINUM: 4,
    RUBY: 5,
    ONYX: 6,
  };

  const ListOption = {
    ALL: 0,
    OWNED: 1,
  };

  const bidValues = [
    toBN(args.MINT_PASS_MINIMUM_BID_AMOUNT).times(2).toString(),
    toBN(args.MINT_PASS_MINIMUM_BID_AMOUNT).times(10).toString(),
    toBN(args.MINT_PASS_MINIMUM_BID_AMOUNT).times(20).toString(),
    toBN(args.MINT_PASS_MINIMUM_BID_AMOUNT).times(30).toString(),
    toBN(args.MINT_PASS_MINIMUM_BID_AMOUNT).times(40).toString(),
    toBN(args.MINT_PASS_MINIMUM_BID_AMOUNT).times(50).toString(),
  ];

  before("setup", async () => {
    const setups = await init(false);
    owner = setups.users[0];
    user1 = setups.users[1];
    user2 = setups.users[2];
    user3 = setups.users[3];
    user4 = setups.users[4];
    user5 = setups.users[5];
    user6 = setups.users[6];

    assetRegistry = setups.assetRegistry;
    keter = setups.keter;
    mintPasses = setups.mintPasses;
    scion = setups.scion;

    // obtention of 6 mintPass of each class for each user

    const start = await getTime();
    await mintPasses.connect(owner).startAuction(AUCTION_DURATION, start);

    await mintPasses.connect(user1).bid(1, bidValues[0], {
      value: bidValues[0],
    });
    await mintPasses.connect(user2).bid(1, bidValues[1], {
      value: bidValues[1],
    });
    await mintPasses.connect(user3).bid(1, bidValues[2], {
      value: bidValues[2],
    });
    await mintPasses.connect(user4).bid(1, bidValues[3], {
      value: bidValues[3],
    });
    await mintPasses.connect(user5).bid(1, bidValues[4], {
      value: bidValues[4],
    });
    await mintPasses.connect(user6).bid(1, bidValues[5], {
      value: bidValues[5],
    });

    await mintPasses.connect(owner).finishAuction();

    const time = await getTime();
    await mintPasses
      .connect(owner)
      .setClasses(
        [
          BidClass.BRONZE,
          BidClass.SILVER,
          BidClass.GOLD,
          BidClass.PLATINUM,
          BidClass.RUBY,
          BidClass.ONYX,
        ],
        [
          classLimits[0].bottom,
          classLimits[1].bottom,
          classLimits[2].bottom,
          classLimits[3].bottom,
          classLimits[4].bottom,
          classLimits[5].bottom,
        ],
        [
          classLimits[0].top,
          classLimits[1].top,
          classLimits[2].top,
          classLimits[3].top,
          classLimits[4].top,
          classLimits[5].top,
        ],
        [time, time, time, time, time, time]
      );

    expect(await mintPasses.countAllBids()).to.equal(6);

    await mintPasses.connect(user1).claimPass([1]);
    await mintPasses.connect(user2).claimPass([2]);
    await mintPasses.connect(user3).claimPass([3]);
    await mintPasses.connect(user4).claimPass([4]);
    await mintPasses.connect(user5).claimPass([5]);
    await mintPasses.connect(user6).claimPass([6]);

    expect(await mintPasses.balanceOf(user1.address)).to.equal(1);
    expect(await mintPasses.balanceOf(user2.address)).to.equal(1);
    expect(await mintPasses.balanceOf(user3.address)).to.equal(1);
    expect(await mintPasses.balanceOf(user4.address)).to.equal(1);
    expect(await mintPasses.balanceOf(user5.address)).to.equal(1);
    expect(await mintPasses.balanceOf(user6.address)).to.equal(1);

    await snapshot();
  });

  afterEach("revert", async () => {
    await restore();
  });

  describe("claimScion", async () => {
    it("reverts if inexistant mintPass", async () => {
      const reason = "ERC721: owner query for nonexistent token";

      await expect(scion.connect(user1).claimScion(6)).to.be.revertedWith(
        reason
      );
    });
    it("reverts if not owner of mintPass", async () => {
      const reason = "Scion: invalid owner";

      await expect(scion.connect(user2).claimScion(0)).to.be.revertedWith(
        reason
      );
    });
    it("claim scion successfully", async () => {
      const tx1 = await scion.connect(user1).claimScion(0);
      const tx2 = await scion.connect(user3).claimScion(2);
      const tx3 = await scion.connect(user4).claimScion(3);
      const tx4 = await scion.connect(user5).claimScion(4);
      const tx5 = await scion.connect(user6).claimScion(5);

      expect(tx1).to.changeTokenBalance(mintPasses, user1, -1);
      expect(tx1).to.changeTokenBalance(scion, user1, 1);
      expect(await scion.ownerOf(0)).to.equal(user1.address);

      expect(tx2).to.changeTokenBalance(mintPasses, user3, -1);
      expect(tx2).to.changeTokenBalance(scion, user3, 1);
      expect(await scion.ownerOf(1)).to.equal(user3.address);

      expect(tx3).to.changeTokenBalance(mintPasses, user4, -1);
      expect(tx3).to.changeTokenBalance(scion, user4, 1);
      expect(await scion.ownerOf(2)).to.equal(user4.address);

      expect(tx4).to.changeTokenBalance(mintPasses, user5, -1);
      expect(tx4).to.changeTokenBalance(scion, user5, 1);
      expect(await scion.ownerOf(3)).to.equal(user5.address);

      expect(tx5).to.changeTokenBalance(mintPasses, user5, -1);
      expect(tx5).to.changeTokenBalance(scion, user6, 1);
      expect(await scion.ownerOf(4)).to.equal(user6.address);

      const tx6 = await scion.connect(user2).claimScion(1);

      expect(tx6).to.changeTokenBalance(mintPasses, user2, -1);
      expect(tx6).to.changeTokenBalance(scion, user2, 1);
      expect(await scion.ownerOf(5)).to.equal(user2.address);
    });
    it("test rarity", async () => {
      // TODO
    });
    it("emits ScionClaimed", async () => {
      await expect(scion.connect(user1).claimScion(0))
        .to.emit(scion, "ScionClaimed")
        .withArgs(user1.address, 0, 0, [], (await getTime()).toString());
      await expect(scion.connect(user4).claimScion(3))
        .to.emit(scion, "ScionClaimed")
        .withArgs(user4.address, 1, 3, [], (await getTime()).toString());
      await expect(scion.connect(user6).claimScion(5))
        .to.emit(scion, "ScionClaimed")
        .withArgs(user6.address, 2, 5, [], (await getTime()).toString());
    });
  });

  describe("rerollAsset", async () => {
    beforeEach("setup", async () => {
      await scion.connect(user1).claimScion(0);
      await scion.connect(user2).claimScion(1);
      await scion.connect(user3).claimScion(2);
      await scion.connect(user4).claimScion(3);
      await scion.connect(user5).claimScion(4);
      await scion.connect(user6).claimScion(5);

      await keter.transfer(user1.address, toWei("100000"));
      await keter.transfer(user2.address, toWei("100000"));
      await keter.transfer(user3.address, toWei("100000"));
      await keter.transfer(user4.address, toWei("100000"));
      await keter.transfer(user5.address, toWei("100000"));
      await keter.transfer(user6.address, toWei("100000"));
    });

    it("reverts if inexistant scion", async () => {
      const reason = "ERC721: owner query for nonexistent token";

      await expect(scion.connect(user1).rerollAsset(6, 2)).to.be.revertedWith(
        reason
      );
    });
    it("reverts if not owner of scion", async () => {
      const reason = "Scion: invalid owner";

      await expect(scion.connect(user2).rerollAsset(0, 2)).to.be.revertedWith(
        reason
      );
    });
    it("reverts if inexistant asset", async () => {
      const reason = "";

      await expect(scion.connect(user1).rerollAsset(0, 0)).to.be.revertedWith(
        reason
      );
      await expect(scion.connect(user1).rerollAsset(0, 7)).to.be.revertedWith(
        reason
      );
    });
    it("reroll asset successfully", async () => {
      const price1 = toWei((await scion.rerollPrice(0, 1)).toString());
      await keter.connect(user1).approve(scion.address, price1);
      const tx1 = await scion.connect(user1).rerollAsset(0, 1);

      const price2 = toWei((await scion.rerollPrice(1, 2)).toString());
      await keter.connect(user2).approve(scion.address, price2);
      const tx2 = await scion.connect(user2).rerollAsset(1, 2);

      const price3 = toWei((await scion.rerollPrice(2, 3)).toString());
      await keter.connect(user3).approve(scion.address, price3);
      const tx3 = await scion.connect(user3).rerollAsset(2, 3);

      const price4 = toWei((await scion.rerollPrice(3, 4)).toString());
      await keter.connect(user4).approve(scion.address, price4);
      const tx4 = await scion.connect(user4).rerollAsset(3, 4);

      const price5 = toWei((await scion.rerollPrice(4, 5)).toString());
      await keter.connect(user5).approve(scion.address, price5);
      const tx5 = await scion.connect(user5).rerollAsset(4, 5);

      const price6 = toWei((await scion.rerollPrice(5, 6)).toString());
      await keter.connect(user6).approve(scion.address, price6);
      const tx6 = await scion.connect(user6).rerollAsset(5, 6);

      expect(tx1).to.changeTokenBalance(keter, user1, -price1);
      expect(tx1).to.changeTokenBalance(keter, scion, price1);
      expect(await scion.ownerOf(0)).to.equal(user1.address);

      expect(tx2).to.changeTokenBalance(keter, user2, -price2);
      expect(tx2).to.changeTokenBalance(keter, scion, price2);
      expect(await scion.ownerOf(1)).to.equal(user2.address);

      expect(tx3).to.changeTokenBalance(keter, user3, -price3);
      expect(tx3).to.changeTokenBalance(keter, scion, price3);
      expect(await scion.ownerOf(2)).to.equal(user3.address);

      expect(tx4).to.changeTokenBalance(keter, user4, -price4);
      expect(tx4).to.changeTokenBalance(keter, scion, price4);
      expect(await scion.ownerOf(3)).to.equal(user4.address);

      expect(tx5).to.changeTokenBalance(keter, user5, -price5);
      expect(tx5).to.changeTokenBalance(keter, scion, price5);
      expect(await scion.ownerOf(4)).to.equal(user5.address);

      expect(tx6).to.changeTokenBalance(keter, user6, -price6);
      expect(tx6).to.changeTokenBalance(keter, scion, price6);
      expect(await scion.ownerOf(5)).to.equal(user6.address);
    });
    it("test rarity", async () => {
      // TODO
    });
    it("emits Reroll", async () => {
      // TODO
    });
  });

  describe("burnForSoul", async () => {});

  describe("use case", async () => {});

  describe.skip("get fees", async () => {
    it("setAssets", async () => {
      for (const asset of assets) {
        const tx = await assetRegistry.setAssets(
          asset.assetId,
          asset.assets,
          asset.weigthSum,
          asset.weigths,
          asset.names
        );
        await getCosts(tx);
      }
    });
    it("claimScion", async () => {
      const tx = await scion.connect(user1).claimScion(0);
      await getCosts(tx);
    });
    it("rerollAsset", async () => {
      await scion.connect(user1).claimScion(0);
      await keter.transfer(user1.address, toWei("100000"));

      const price = toWei((await scion.rerollPrice(1, 0)).toString());
      await keter.connect(user1).approve(scion.address, price);
      const tx = await scion.connect(user1).rerollAsset(0, 1);
      await getCosts(tx);
    });
  });
});
