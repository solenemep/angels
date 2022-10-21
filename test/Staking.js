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
  advanceBlockTo,
} = require("./helpers/utils");

describe("Staking", async () => {
  let staking;
  let mintPasses;
  let keter;
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
      expect(tx1).to.changeTokenBalance(keter, user1, (await staking.calculateRewards(user1.address, 0)).toString());
      expect(await scion.ownerOf(0)).to.equal(user1.address);
      expect((await staking.stakes(user1.address, 0))[0]).to.equal(false);

      expect(tx2).to.changeTokenBalance(scion, user1, 1);
      expect(tx1).to.changeTokenBalance(keter, user1, (await staking.calculateRewards(user1.address, 1)).toString());
      expect(await scion.ownerOf(1)).to.equal(user1.address);
      expect((await staking.stakes(user1.address, 1))[0]).to.equal(false);

      expect(tx3).to.changeTokenBalance(scion, user2, 1);
      expect(tx1).to.changeTokenBalance(keter, user2, (await staking.calculateRewards(user2.address, 2)).toString());
      expect(await scion.ownerOf(2)).to.equal(user2.address);
      expect((await staking.stakes(user2.address, 2))[0]).to.equal(false);

      expect(tx4).to.changeTokenBalance(scion, user2, 1);
      expect(tx1).to.changeTokenBalance(keter, user2, (await staking.calculateRewards(user2.address, 3)).toString());
      expect(await scion.ownerOf(3)).to.equal(user2.address);
      expect((await staking.stakes(user2.address, 3))[0]).to.equal(false);

      expect(tx5).to.changeTokenBalance(scion, user3, 1);
      expect(tx1).to.changeTokenBalance(keter, user3, (await staking.calculateRewards(user3.address, 4)).toString());
      expect(await scion.ownerOf(4)).to.equal(user3.address);
      expect((await staking.stakes(user3.address, 4))[0]).to.equal(false);

      expect(tx6).to.changeTokenBalance(scion, user3, 1);
      expect(tx1).to.changeTokenBalance(keter, user3, (await staking.calculateRewards(user3.address, 5)).toString());
      expect(await scion.ownerOf(5)).to.equal(user3.address);
      expect((await staking.stakes(user3.address, 5))[0]).to.equal(false);
    });
    it("emits UnStake", async () => {
      const reward = Number(await staking.calculateRewards(user1.address, 0)) + 1; // margin for time passed
      await expect(staking.connect(user1).unStakeNFT(0))
        .to.emit(staking, "UnStake")
        .withArgs(
          user1.address,
          0,
          toBN(await getCurrentBlock())
            .plus(1)
            .toString(),
          reward.toString()
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
      expect(tx1).to.changeTokenBalance(
        keter,
        user1,
        toBN(await staking.calculateRewards(user1.address, 0))
          .plus(await staking.calculateRewards(user1.address, 1))
          .toString()
      );
      expect(await scion.ownerOf(0)).to.equal(user1.address);
      expect(await scion.ownerOf(1)).to.equal(user1.address);
      expect((await staking.stakes(user1.address, 0))[0]).to.equal(false);
      expect((await staking.stakes(user1.address, 1))[0]).to.equal(false);

      expect(tx2).to.changeTokenBalance(scion, user2, 2);
      expect(tx2).to.changeTokenBalance(
        keter,
        user2,
        toBN(await staking.calculateRewards(user2.address, 2))
          .plus(await staking.calculateRewards(user2.address, 3))
          .toString()
      );
      expect(await scion.ownerOf(2)).to.equal(user2.address);
      expect(await scion.ownerOf(3)).to.equal(user2.address);
      expect((await staking.stakes(user2.address, 2))[0]).to.equal(false);
      expect((await staking.stakes(user2.address, 3))[0]).to.equal(false);

      expect(tx3).to.changeTokenBalance(scion, user3, 2);
      expect(tx3).to.changeTokenBalance(
        keter,
        user3,
        toBN(await staking.calculateRewards(user3.address, 4))
          .plus(await staking.calculateRewards(user3.address, 5))
          .toString()
      );
      expect(await scion.ownerOf(4)).to.equal(user3.address);
      expect(await scion.ownerOf(5)).to.equal(user3.address);
      expect((await staking.stakes(user3.address, 4))[0]).to.equal(false);
      expect((await staking.stakes(user3.address, 5))[0]).to.equal(false);
    });
  });
  describe("harvest", async () => {
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
    it("reverts if not staked", async () => {
      const reason = "Staking: No stake with this token id";

      await expect(staking.connect(user3).harvest(0)).to.be.revertedWith(reason);
    });
    it("harvest successfully", async () => {
      const reward1 = await staking.calculateRewards(user1.address, 0);
      const tx1 = await staking.connect(user1).harvest(0);

      const reward2 = await staking.calculateRewards(user1.address, 1);
      const tx2 = await staking.connect(user1).harvest(1);

      const reward3 = await staking.calculateRewards(user2.address, 2);
      const tx3 = await staking.connect(user2).harvest(2);

      const reward4 = await staking.calculateRewards(user2.address, 3);
      const tx4 = await staking.connect(user2).harvest(3);

      const reward5 = await staking.calculateRewards(user3.address, 4);
      const tx5 = await staking.connect(user3).harvest(4);

      const reward6 = await staking.calculateRewards(user3.address, 5);
      const tx6 = await staking.connect(user3).harvest(5);

      expect(tx1).to.changeTokenBalance(keter, user1, reward1.toString());
      expect((await staking.stakes(user1.address, 0))[2]).to.be.closeTo(reward1.toString(), 1);

      expect(tx2).to.changeTokenBalance(keter, user1, reward2.toString());
      expect((await staking.stakes(user1.address, 1))[2]).to.be.closeTo(reward2.toString(), 1);

      expect(tx3).to.changeTokenBalance(keter, user2, reward3.toString());
      expect((await staking.stakes(user2.address, 2))[2]).to.be.closeTo(reward3.toString(), 1);

      expect(tx4).to.changeTokenBalance(keter, user2, reward4.toString());
      expect((await staking.stakes(user2.address, 3))[2]).to.be.closeTo(reward4.toString(), 1);

      expect(tx5).to.changeTokenBalance(keter, user3, reward5.toString());
      expect((await staking.stakes(user3.address, 4))[2]).to.be.closeTo(reward5.toString(), 1);

      expect(tx6).to.changeTokenBalance(keter, user3, reward6.toString());
      expect((await staking.stakes(user3.address, 5))[2]).to.be.closeTo(reward6.toString(), 1);
    });
    it("harvest twice", async () => {
      const reward1 = await staking.calculateRewards(user1.address, 0);
      let tx = await staking.connect(user1).harvest(0);

      expect(tx).to.changeTokenBalance(keter, user1, reward1.toString());
      expect((await staking.stakes(user1.address, 0))[2]).to.be.closeTo(reward1.toString(), 1);

      await advanceBlockTo(2000);

      const reward2 = await staking.calculateRewards(user1.address, 0);
      tx = await staking.connect(user1).harvest(0);

      const totalHarvested = Number(reward1) + Number(reward2);

      expect(tx).to.changeTokenBalance(keter, user1, reward2.toString());
      expect((await staking.stakes(user1.address, 0))[2].toNumber()).to.be.closeTo(totalHarvested, 1);
    });
  });
  describe("harvestBatch", async () => {
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

      await expect(staking.connect(user1).harvestBatch(indexes)).to.be.revertedWith(reason);
    });
    it("reverts if not staked", async () => {
      const reason = "Staking: No stake with this token id";

      await expect(staking.connect(user3).harvestBatch([0])).to.be.revertedWith(reason);
    });
    it("harvest batch successfully", async () => {
      const reward1 = await staking.calculateRewards(user1.address, 0);
      const reward2 = await staking.calculateRewards(user1.address, 1);
      const tx1 = await staking.connect(user1).harvestBatch([0, 1]);

      const reward3 = await staking.calculateRewards(user2.address, 2);
      const reward4 = await staking.calculateRewards(user2.address, 3);
      const tx2 = await staking.connect(user2).harvestBatch([2, 3]);

      const reward5 = await staking.calculateRewards(user3.address, 4);
      const reward6 = await staking.calculateRewards(user3.address, 5);
      const tx3 = await staking.connect(user3).harvestBatch([4, 5]);

      expect(tx1).to.changeTokenBalance(keter, user1, toBN(reward1).plus(reward2).toString());
      expect((await staking.stakes(user1.address, 0))[2]).to.be.closeTo(reward1.toString(), 1);
      expect((await staking.stakes(user1.address, 1))[2]).to.be.closeTo(reward2.toString(), 1);

      expect(tx2).to.changeTokenBalance(keter, user2, toBN(reward3).plus(reward4).toString());
      expect((await staking.stakes(user2.address, 2))[2]).to.be.closeTo(reward3.toString(), 1);
      expect((await staking.stakes(user2.address, 3))[2]).to.be.closeTo(reward4.toString(), 1);

      expect(tx3).to.changeTokenBalance(keter, user3, toBN(reward5).plus(reward6).toString());
      expect((await staking.stakes(user3.address, 4))[2]).to.be.closeTo(reward5.toString(), 1);
      expect((await staking.stakes(user3.address, 5))[2]).to.be.closeTo(reward6.toString(), 1);
    });
    it("harvest batch twice", async () => {
      const reward1 = await staking.calculateRewards(user1.address, 0);
      let tx = await staking.connect(user1).harvestBatch([0]);

      expect(tx).to.changeTokenBalance(keter, user1, reward1.toString());
      expect((await staking.stakes(user1.address, 0))[2]).to.be.closeTo(reward1.toString(), 1);

      await advanceBlockTo(2000);

      const reward2 = await staking.calculateRewards(user1.address, 0);
      tx = await staking.connect(user1).harvestBatch([0]);

      const totalHarvested = Number(reward1) + Number(reward2);

      expect(tx).to.changeTokenBalance(keter, user1, reward2.toString());
      expect((await staking.stakes(user1.address, 0))[2].toNumber()).to.be.closeTo(totalHarvested, 1);
    });
  });
});
