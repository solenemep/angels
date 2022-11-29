const { expect } = require("chai");
const { args } = require("../helpers/arguments");
const { Class, classLimits } = require("../helpers/classLimits");
const { init } = require("../helpers/initTest");
const { toBN, snapshot, restore, increaseTime, getTime, getCurrentBlock, advanceBlockTo } = require("../helpers/utils");

describe("Staking", async () => {
  let staking;
  let mintPasses;
  let keter;
  let scion;
  let owner;
  let user1, user2, user3;
  let bn;

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
    bn = await getCurrentBlock();
    const setups = await init(false);
    owner = setups.users[0];
    user1 = setups.users[1];
    user2 = setups.users[2];
    user3 = setups.users[3];

    staking = setups.staking;
    mintPasses = setups.mintPasses;
    scion = setups.scion;
    keter = setups.keter;

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

      await scion.connect(user1).approve(staking.address, 1);
      const tx2 = await staking.connect(user1).stakeNFT(1);

      await scion.connect(user2).approve(staking.address, 2);
      const tx3 = await staking.connect(user2).stakeNFT(2);

      await scion.connect(user2).approve(staking.address, 3);
      const tx4 = await staking.connect(user2).stakeNFT(3);

      await scion.connect(user3).approve(staking.address, 4);
      const tx5 = await staking.connect(user3).stakeNFT(4);

      await scion.connect(user3).approve(staking.address, 5);
      const tx6 = await staking.connect(user3).stakeNFT(5);

      expect(tx1).to.changeTokenBalance(scion, user1, -1);
      expect(await scion.ownerOf(0)).to.equal(staking.address);

      expect(tx2).to.changeTokenBalance(scion, user1, -1);
      expect(await scion.ownerOf(1)).to.equal(staking.address);

      expect(tx3).to.changeTokenBalance(scion, user2, -1);
      expect(await scion.ownerOf(2)).to.equal(staking.address);

      expect(tx4).to.changeTokenBalance(scion, user2, -1);
      expect(await scion.ownerOf(3)).to.equal(staking.address);

      expect(tx5).to.changeTokenBalance(scion, user3, -1);
      expect(await scion.ownerOf(4)).to.equal(staking.address);

      expect(tx6).to.changeTokenBalance(scion, user3, -1);
      expect(await scion.ownerOf(5)).to.equal(staking.address);
    });
    it("emits StakeNFT", async () => {
      await scion.connect(user1).approve(staking.address, 0);
      await expect(staking.connect(user1).stakeNFT(0))
        .to.emit(staking, "StakeNFT")
        .withArgs(
          user1.address,
          0,
          toBN(await getCurrentBlock())
            .plus(1)
            .toString()
        );
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

      await scion.connect(user2).approve(staking.address, 2);
      await scion.connect(user2).approve(staking.address, 3);
      const tx2 = await staking.connect(user2).stakeNFTs([2, 3]);

      await scion.connect(user3).approve(staking.address, 4);
      await scion.connect(user3).approve(staking.address, 5);
      const tx3 = await staking.connect(user3).stakeNFTs([4, 5]);

      expect(tx1).to.changeTokenBalance(scion, user1, -2);
      expect(await scion.ownerOf(0)).to.equal(staking.address);
      expect(await scion.ownerOf(1)).to.equal(staking.address);

      expect(tx2).to.changeTokenBalance(scion, user2, -2);
      expect(await scion.ownerOf(2)).to.equal(staking.address);
      expect(await scion.ownerOf(3)).to.equal(staking.address);

      expect(tx3).to.changeTokenBalance(scion, user3, -2);
      expect(await scion.ownerOf(4)).to.equal(staking.address);
      expect(await scion.ownerOf(5)).to.equal(staking.address);
    });
  });
  describe("unStakeNFT", async () => {
    beforeEach("setup", async () => {
      await scion.connect(user1).approve(staking.address, 0);
      await staking.connect(user1).stakeNFT(0);

      await scion.connect(user1).approve(staking.address, 1);
      await staking.connect(user1).stakeNFT(1);

      await scion.connect(user2).approve(staking.address, 2);
      await staking.connect(user2).stakeNFT(2);

      await scion.connect(user2).approve(staking.address, 3);
      await staking.connect(user2).stakeNFT(3);

      await scion.connect(user3).approve(staking.address, 4);
      await staking.connect(user3).stakeNFT(4);

      await scion.connect(user3).approve(staking.address, 5);
      await staking.connect(user3).stakeNFT(5);

      await increaseTime(24 * 60 * 60);
    });
    it("reverts if not owner of stake", async () => {
      const reason = "Staking: No stake with this token id";

      await expect(staking.connect(user3).unStakeNFT(0)).to.be.revertedWith(reason);
    });
    it("reverts if already unstaked", async () => {
      const reason = "Staking: No stake with this token id";

      await staking.connect(user1).unStakeNFT(0);

      await expect(staking.connect(user1).unStakeNFT(0)).to.be.revertedWith(reason);
    });
    it("unstake token successfully", async () => {
      const tx1 = await staking.connect(user1).unStakeNFT(0);
      const tx2 = await staking.connect(user1).unStakeNFT(1);
      const tx3 = await staking.connect(user2).unStakeNFT(2);
      const tx4 = await staking.connect(user2).unStakeNFT(3);
      const tx5 = await staking.connect(user3).unStakeNFT(4);
      const tx6 = await staking.connect(user3).unStakeNFT(5);

      expect(tx1).to.changeTokenBalance(scion, user1, 1);
      expect(await scion.ownerOf(0)).to.equal(user1.address);

      expect(tx2).to.changeTokenBalance(scion, user1, 1);
      expect(await scion.ownerOf(1)).to.equal(user1.address);

      expect(tx3).to.changeTokenBalance(scion, user2, 1);
      expect(await scion.ownerOf(2)).to.equal(user2.address);

      expect(tx4).to.changeTokenBalance(scion, user2, 1);
      expect(await scion.ownerOf(3)).to.equal(user2.address);

      expect(tx5).to.changeTokenBalance(scion, user3, 1);
      expect(await scion.ownerOf(4)).to.equal(user3.address);

      expect(tx6).to.changeTokenBalance(scion, user3, 1);
      expect(await scion.ownerOf(5)).to.equal(user3.address);
    });
    it("emits UnStakeNFT", async () => {
      await expect(staking.connect(user1).unStakeNFT(0))
        .to.emit(staking, "UnStakeNFT")
        .withArgs(
          user1.address,
          0,
          toBN(await getCurrentBlock())
            .plus(1)
            .toString()
        );
    });
  });
  describe("unStakeNFTs", async () => {
    beforeEach("setup", async () => {
      await scion.connect(user1).approve(staking.address, 0);
      await staking.connect(user1).stakeNFT(0);

      await scion.connect(user1).approve(staking.address, 1);
      await staking.connect(user1).stakeNFT(1);

      await scion.connect(user2).approve(staking.address, 2);
      await staking.connect(user2).stakeNFT(2);

      await scion.connect(user2).approve(staking.address, 3);
      await staking.connect(user2).stakeNFT(3);

      await scion.connect(user3).approve(staking.address, 4);
      await staking.connect(user3).stakeNFT(4);

      await scion.connect(user3).approve(staking.address, 5);
      await staking.connect(user3).stakeNFT(5);

      await advanceBlockTo(2000);
    });
    it("reverts if too many token to unstake", async () => {
      const reason = "Staking: Maximum amount of token ids exceeded";

      const indexes = Array(101).fill(0);

      await expect(staking.connect(user1).unStakeNFTs(indexes)).to.be.revertedWith(reason);
    });
    it("reverts if not owner of stake", async () => {
      const reason = "Staking: No stake with this token id";

      await expect(staking.connect(user3).unStakeNFTs([0])).to.be.revertedWith(reason);
    });
    it("reverts if already unstaked", async () => {
      const reason = "Staking: No stake with this token id";

      await staking.connect(user1).unStakeNFTs([0]);

      await expect(staking.connect(user1).unStakeNFTs([0])).to.be.revertedWith(reason);
    });
    it("unstake NFT batch sucessfully", async () => {
      const tx1 = await staking.connect(user1).unStakeNFTs([0, 1]);
      const tx2 = await staking.connect(user2).unStakeNFTs([2, 3]);
      const tx3 = await staking.connect(user3).unStakeNFTs([4, 5]);

      expect(tx1).to.changeTokenBalance(scion, user1, 2);
      expect(await scion.ownerOf(0)).to.equal(user1.address);
      expect(await scion.ownerOf(1)).to.equal(user1.address);

      expect(tx2).to.changeTokenBalance(scion, user2, 2);
      expect(await scion.ownerOf(2)).to.equal(user2.address);
      expect(await scion.ownerOf(3)).to.equal(user2.address);

      expect(tx3).to.changeTokenBalance(scion, user3, 2);
      expect(await scion.ownerOf(4)).to.equal(user3.address);
      expect(await scion.ownerOf(5)).to.equal(user3.address);
    });
  });
  describe("rewardPerToken()", () => {
    it("should return 0 if no stake", async () => {
      expect(await staking.rewardPerToken()).to.equal(0);
    });
    it("should be > 0 if stake", async () => {
      await scion.connect(user1).approve(staking.address, 0);
      await staking.connect(user1).stakeNFT(0);

      await scion.connect(user1).approve(staking.address, 1);
      await staking.connect(user1).stakeNFT(1);

      await scion.connect(user2).approve(staking.address, 2);
      await staking.connect(user2).stakeNFT(2);

      expect(Number(await staking.rewardPerToken())).to.be.greaterThan(0);
    });
  });
  describe("earned()", () => {
    it("should be 0 if no stake", async () => {
      expect(await staking.earned(user1.address)).to.equal(0);
    });
    it("should be > 0 if stake", async () => {
      await scion.connect(user1).approve(staking.address, 0);
      await staking.connect(user1).stakeNFT(0);

      await scion.connect(user1).approve(staking.address, 1);
      await staking.connect(user1).stakeNFT(1);

      await scion.connect(user2).approve(staking.address, 2);
      await staking.connect(user2).stakeNFT(2);

      expect(Number(await staking.earned(user1.address))).to.be.greaterThan(0);
    });
  });
  describe("getReward", async () => {
    beforeEach("setup", async () => {
      await scion.connect(user1).approve(staking.address, 0);
      await staking.connect(user1).stakeNFT(0);

      await scion.connect(user1).approve(staking.address, 1);
      await staking.connect(user1).stakeNFT(1);

      await scion.connect(user2).approve(staking.address, 2);
      await staking.connect(user2).stakeNFT(2);

      await scion.connect(user2).approve(staking.address, 3);
      await staking.connect(user2).stakeNFT(3);

      await scion.connect(user3).approve(staking.address, 4);
      await staking.connect(user3).stakeNFT(4);

      await scion.connect(user3).approve(staking.address, 5);
      await staking.connect(user3).stakeNFT(5);

      await advanceBlockTo(2000);
    });
    it("getReward successfully", async () => {
      const balanceU1Before = await keter.balanceOf(user1.address);
      await staking.connect(user1).getReward();
      expect(await staking.rewards(user1.address)).to.equal(0);
      expect(Number(await staking.rewards(user2.address))).to.be.greaterThan(0);
      expect(Number(await staking.rewards(user3.address))).to.be.greaterThan(0);
      const balanceU1After = await keter.balanceOf(user1.address);

      const balanceU2Before = await keter.balanceOf(user2.address);
      await staking.connect(user2).getReward();
      expect(await staking.rewards(user2.address)).to.equal(0);
      expect(Number(await staking.rewards(user3.address))).to.be.greaterThan(0);
      const balanceU2After = await keter.balanceOf(user2.address);

      const balanceU3Before = await keter.balanceOf(user3.address);
      await staking.connect(user3).getReward();
      expect(await staking.rewards(user3.address)).to.equal(0);
      const balanceU3After = await keter.balanceOf(user3.address);

      expect(Number(balanceU1After)).to.be.greaterThan(Number(balanceU1Before));
      expect(Number(balanceU2After)).to.be.greaterThan(Number(balanceU2Before));
      expect(Number(balanceU3After)).to.be.greaterThan(Number(balanceU3Before));
    });
    it("getReward twice", async () => {
      let tx = await staking.connect(user1).getReward();
      expect(await staking.rewards(user1.address)).to.equal(0);

      const balanceBefore = await keter.balanceOf(user1.address);

      await advanceBlockTo(2000);

      tx = await staking.connect(user1).getReward();
      expect(await staking.rewards(user1.address)).to.equal(0);
      const balanceAfter = await keter.balanceOf(user1.address);

      expect(Number(balanceAfter)).to.be.greaterThan(Number(balanceBefore));
    });
  });
});
