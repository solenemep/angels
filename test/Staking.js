const { ZERO_ADDRESS } = require("@openzeppelin/test-helpers/src/constants");
const { expect } = require("chai");
const { args } = require("./helpers/arguments");
const { Class, classLimits } = require("./helpers/classLimits");
const { init } = require("./helpers/init");
const {
  toBN,
  toWei,
  snapshot,
  restore,
  increaseTime,
  increaseTimeTo,
  getTime,
  getCosts,
  getCurrentBlock,
} = require("./helpers/utils");

describe("Staking", async () => {
  let staking;
  let mintPasses;
  let scion;
  let owner;
  let user1, user2, user3;

  const bidValues = [
    toBN(args.MINT_PASS_MINIMUM_BID_AMOUNT).times(2).toString(),
    toBN(args.MINT_PASS_MINIMUM_BID_AMOUNT).times(10).toString(),
    toBN(args.MINT_PASS_MINIMUM_BID_AMOUNT).times(20).toString(),
    toBN(args.MINT_PASS_MINIMUM_BID_AMOUNT).times(30).toString(),
    toBN(args.MINT_PASS_MINIMUM_BID_AMOUNT).times(40).toString(),
    toBN(args.MINT_PASS_MINIMUM_BID_AMOUNT).times(50).toString(),
  ];

  const AUCTION_DURATION = 3 * 24 * 60; // 3 days (in minutes)

  before("setup", async () => {
    const setups = await init(false);
    owner = setups.users[0];
    user1 = setups.users[1];
    user2 = setups.users[2];
    user3 = setups.users[3];

    staking = setups.staking;
    mintPasses = setups.mintPasses;
    scion = setups.scion;

    // obtention of mintPass

    const start = await getTime();
    await mintPasses.connect(owner).startAuction(AUCTION_DURATION, start);

    await mintPasses.connect(user1).bid(1, bidValues[0], {
      value: bidValues[0],
    });
    await mintPasses.connect(user1).bid(1, bidValues[1], {
      value: bidValues[1],
    });
    await mintPasses.connect(user2).bid(1, bidValues[2], {
      value: bidValues[2],
    });
    await mintPasses.connect(user2).bid(1, bidValues[3], {
      value: bidValues[3],
    });
    await mintPasses.connect(user3).bid(1, bidValues[4], {
      value: bidValues[4],
    });
    await mintPasses.connect(user3).bid(1, bidValues[5], {
      value: bidValues[5],
    });

    await mintPasses.connect(owner).finishAuction();

    const time = await getTime();
    await mintPasses
      .connect(owner)
      .setClassesBidValueLimits(
        [Class.BRONZE, Class.SILVER, Class.GOLD, Class.PLATINUM, Class.RUBY, Class.ONYX],
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
    await mintPasses.connect(user1).claimPass([2]);
    await mintPasses.connect(user2).claimPass([3]);
    await mintPasses.connect(user2).claimPass([4]);
    await mintPasses.connect(user3).claimPass([5]);
    await mintPasses.connect(user3).claimPass([6]);

    expect(await mintPasses.balanceOf(user1.address)).to.equal(2);
    expect((await mintPasses.mintPassInfos(0)).class).to.equal(Class.BRONZE);
    expect((await mintPasses.mintPassInfos(1)).class).to.equal(Class.SILVER);

    expect(await mintPasses.balanceOf(user2.address)).to.equal(2);
    expect((await mintPasses.mintPassInfos(2)).class).to.equal(Class.GOLD);
    expect((await mintPasses.mintPassInfos(3)).class).to.equal(Class.PLATINUM);

    expect(await mintPasses.balanceOf(user3.address)).to.equal(2);
    expect((await mintPasses.mintPassInfos(4)).class).to.equal(Class.RUBY);
    expect((await mintPasses.mintPassInfos(5)).class).to.equal(Class.ONYX);

    // obtention of scion

    await scion.connect(user1).claimScion(0);
    await scion.connect(user1).claimScion(1);
    await scion.connect(user2).claimScion(2);
    await scion.connect(user2).claimScion(3);
    await scion.connect(user3).claimScion(4);
    await scion.connect(user3).claimScion(5);

    await snapshot();
  });

  afterEach("revert", async () => {
    await restore();
  });

  describe("stakeNFT", async () => {
    it("reverts if not owner of token", async () => {
      const reason = "you dont own this token";

      await expect(staking.connect(user3).stakeNFT(0)).to.be.revertedWith(reason);
    });
    it("reverts if already staked", async () => {
      const reason = "you dont own this token";

      await scion.connect(user1).approve(staking.address, 0);
      await staking.connect(user1).stakeNFT(0);

      await expect(staking.connect(user3).stakeNFT(0)).to.be.revertedWith(reason);
    });
    it("stake NFT sucessfully", async () => {
      await scion.connect(user1).approve(staking.address, 0);
      const tx1 = await staking.connect(user1).stakeNFT(0);
      const bn1 = await getCurrentBlock();

      await scion.connect(user1).approve(staking.address, 1);
      const tx2 = await staking.connect(user1).stakeNFT(1);
      const bn2 = await getCurrentBlock();

      await scion.connect(user2).approve(staking.address, 2);
      const tx3 = await staking.connect(user2).stakeNFT(2);
      const bn3 = await getCurrentBlock();

      await scion.connect(user2).approve(staking.address, 3);
      const tx4 = await staking.connect(user2).stakeNFT(3);
      const bn4 = await getCurrentBlock();

      await scion.connect(user3).approve(staking.address, 4);
      const tx5 = await staking.connect(user3).stakeNFT(4);
      const bn5 = await getCurrentBlock();

      await scion.connect(user3).approve(staking.address, 5);
      const tx6 = await staking.connect(user3).stakeNFT(5);
      const bn6 = await getCurrentBlock();

      expect(tx1).to.changeTokenBalance(scion, user1, -1);
      expect(await scion.ownerOf(0)).to.equal(staking.address);
      expect((await staking.stakes(user1.address, 0))[0]).to.equal(true);
      expect((await staking.stakes(user1.address, 0))[1]).to.equal(bn1.toString());
      expect((await staking.stakes(user1.address, 0))[2]).to.equal(0);

      expect(tx2).to.changeTokenBalance(scion, user1, -1);
      expect(await scion.ownerOf(1)).to.equal(staking.address);
      expect((await staking.stakes(user1.address, 1))[0]).to.equal(true);
      expect((await staking.stakes(user1.address, 1))[1]).to.equal(bn2.toString());
      expect((await staking.stakes(user1.address, 1))[2]).to.equal(0);

      expect(tx3).to.changeTokenBalance(scion, user2, -1);
      expect(await scion.ownerOf(2)).to.equal(staking.address);
      expect((await staking.stakes(user2.address, 2))[0]).to.equal(true);
      expect((await staking.stakes(user2.address, 2))[1]).to.equal(bn3.toString());
      expect((await staking.stakes(user2.address, 2))[2]).to.equal(0);

      expect(tx4).to.changeTokenBalance(scion, user2, -1);
      expect(await scion.ownerOf(3)).to.equal(staking.address);
      expect((await staking.stakes(user2.address, 3))[0]).to.equal(true);
      expect((await staking.stakes(user2.address, 3))[1]).to.equal(bn4.toString());
      expect((await staking.stakes(user2.address, 3))[2]).to.equal(0);

      expect(tx5).to.changeTokenBalance(scion, user3, -1);
      expect(await scion.ownerOf(4)).to.equal(staking.address);
      expect((await staking.stakes(user3.address, 4))[0]).to.equal(true);
      expect((await staking.stakes(user3.address, 4))[1]).to.equal(bn5.toString());
      expect((await staking.stakes(user3.address, 4))[2]).to.equal(0);

      expect(tx6).to.changeTokenBalance(scion, user3, -1);
      expect(await scion.ownerOf(5)).to.equal(staking.address);
      expect((await staking.stakes(user3.address, 5))[0]).to.equal(true);
      expect((await staking.stakes(user3.address, 5))[1]).to.equal(bn6.toString());
      expect((await staking.stakes(user3.address, 5))[2]).to.equal(0);
    });
    it("emits Stake", async () => {
      await scion.connect(user1).approve(staking.address, 0);
      await expect(staking.connect(user1).stakeNFT(0))
        .to.emit(staking, "Stake")
        .withArgs(user1.address, 0, (await getCurrentBlock()).toString());
    });
  });
  describe("stakeNFTs", async () => {
    it("reverts if too many token to stake", async () => {
      const reason = "Staking: Maximum amount of token ids exceeded";

      const indexes = Array(101).fill(0);

      await expect(staking.connect(user1).stakeNFTs(indexes)).to.be.revertedWith(reason);
    });
    it("reverts if not owner of token", async () => {
      const reason = "you dont own this token";

      await scion.connect(user1).approve(staking.address, 0);
      await scion.connect(user1).approve(staking.address, 1);

      await expect(staking.connect(user1).stakeNFTs([0, 1, 2])).to.be.revertedWith(reason);
    });
    it("stake NFT batch sucessfully", async () => {
      await scion.connect(user1).approve(staking.address, 0);
      await scion.connect(user1).approve(staking.address, 1);
      const tx1 = await staking.connect(user1).stakeNFTs([0, 1]);
      const bn1 = await getCurrentBlock();

      await scion.connect(user2).approve(staking.address, 2);
      await scion.connect(user2).approve(staking.address, 3);
      const tx2 = await staking.connect(user2).stakeNFTs([2, 3]);
      const bn2 = await getCurrentBlock();

      await scion.connect(user3).approve(staking.address, 4);
      await scion.connect(user3).approve(staking.address, 5);
      const tx3 = await staking.connect(user3).stakeNFTs([4, 5]);
      const bn3 = await getCurrentBlock();

      expect(tx1).to.changeTokenBalance(scion, user1, -2);
      expect(await scion.ownerOf(0)).to.equal(staking.address);
      expect(await scion.ownerOf(1)).to.equal(staking.address);

      expect((await staking.stakes(user1.address, 0))[0]).to.equal(true);
      expect((await staking.stakes(user1.address, 0))[1]).to.equal(bn1.toString());
      expect((await staking.stakes(user1.address, 0))[2]).to.equal(0);

      expect((await staking.stakes(user1.address, 1))[0]).to.equal(true);
      expect((await staking.stakes(user1.address, 1))[1]).to.equal(bn1.toString());
      expect((await staking.stakes(user1.address, 1))[2]).to.equal(0);

      expect(tx2).to.changeTokenBalance(scion, user2, -2);
      expect(await scion.ownerOf(2)).to.equal(staking.address);
      expect(await scion.ownerOf(3)).to.equal(staking.address);

      expect((await staking.stakes(user2.address, 2))[0]).to.equal(true);
      expect((await staking.stakes(user2.address, 2))[1]).to.equal(bn2.toString());
      expect((await staking.stakes(user2.address, 2))[2]).to.equal(0);

      expect((await staking.stakes(user2.address, 3))[0]).to.equal(true);
      expect((await staking.stakes(user2.address, 3))[1]).to.equal(bn2.toString());
      expect((await staking.stakes(user2.address, 3))[2]).to.equal(0);

      expect(tx3).to.changeTokenBalance(scion, user3, -2);
      expect(await scion.ownerOf(4)).to.equal(staking.address);
      expect(await scion.ownerOf(5)).to.equal(staking.address);

      expect((await staking.stakes(user3.address, 4))[0]).to.equal(true);
      expect((await staking.stakes(user3.address, 4))[1]).to.equal(bn3.toString());
      expect((await staking.stakes(user3.address, 4))[2]).to.equal(0);

      expect((await staking.stakes(user3.address, 5))[0]).to.equal(true);
      expect((await staking.stakes(user3.address, 5))[1]).to.equal(bn3.toString());
      expect((await staking.stakes(user3.address, 5))[2]).to.equal(0);
    });
  });
  describe("unStakeNFT", async () => {});
  describe("unStakeNFTs", async () => {});
  describe("harvest", async () => {});
  describe("harvestBatch", async () => {});
});
