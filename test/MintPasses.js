const { ZERO_ADDRESS } = require("@openzeppelin/test-helpers/src/constants");
const { expect } = require("chai");
const { args } = require("./helpers/arguments");
const { classLimits } = require("./helpers/classLimits");
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
} = require("./helpers/utils");

describe("MintPasses", async () => {
  let mintPasses;
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

  beforeEach("setup", async () => {
    const setups = await init();
    owner = setups.users[0];
    user1 = setups.users[1];
    user2 = setups.users[2];
    user3 = setups.users[3];
    user4 = setups.users[4];
    user5 = setups.users[5];
    user6 = setups.users[6];

    mintPasses = setups.mintPasses;

    await snapshot();
  });

  afterEach("revert", async () => {
    await restore();
  });

  describe("auction", async () => {
    it("setStart", async () => {
      const start = await getTime();

      expect(await mintPasses.start()).to.equal(0);
      expect(await mintPasses.auctionDuration()).to.equal(
        args.MINT_PASS_AUCTION_DURATION
      );
      expect(await mintPasses.isAuctionFinished()).to.equal(true);

      await mintPasses.connect(owner).startAuction(AUCTION_DURATION, start);
      expect(await mintPasses.auctionDuration()).to.equal(
        AUCTION_DURATION * 60
      );
      expect(await mintPasses.start()).to.equal(start);
      expect(await mintPasses.isAuctionFinished()).to.equal(false);

      await increaseTimeTo(
        toBN(start)
          .plus(AUCTION_DURATION * 60)
          .plus(10)
          .toString()
      );
      expect(await mintPasses.auctionDuration()).to.equal(
        AUCTION_DURATION * 60
      );
      expect(await mintPasses.start()).to.equal(start);
      expect(await mintPasses.isAuctionFinished()).to.equal(true);
    });
    it("setStart for prolongation", async () => {
      const start1 = await getTime();

      expect(await mintPasses.start()).to.equal(0);
      expect(await mintPasses.auctionDuration()).to.equal(
        args.MINT_PASS_AUCTION_DURATION
      );
      expect(await mintPasses.isAuctionFinished()).to.equal(true);

      await mintPasses.connect(owner).startAuction(AUCTION_DURATION, start1);
      expect(await mintPasses.auctionDuration()).to.equal(
        AUCTION_DURATION * 60
      );
      expect(await mintPasses.start()).to.equal(start1);
      expect(await mintPasses.isAuctionFinished()).to.equal(false);

      await increaseTimeTo(
        toBN(start1)
          .plus(toBN(AUCTION_DURATION * 60).div(2))
          .toString()
      );
      expect(await mintPasses.auctionDuration()).to.equal(
        AUCTION_DURATION * 60
      );
      expect(await mintPasses.start()).to.equal(start1);
      expect(await mintPasses.isAuctionFinished()).to.equal(false);

      const start2 = await getTime();
      await mintPasses.connect(owner).startAuction(AUCTION_DURATION, start2);
      expect(await mintPasses.auctionDuration()).to.equal(
        AUCTION_DURATION * 60
      );
      expect(await mintPasses.start()).to.equal(start2);
      expect(await mintPasses.isAuctionFinished()).to.equal(false);

      await increaseTime(
        toBN(AUCTION_DURATION * 60)
          .div(2)
          .toString()
      );
      expect(await mintPasses.isAuctionFinished()).to.equal(false);
    });
    it("finishAuction automatically", async () => {
      const start = await getTime();
      await mintPasses.connect(owner).startAuction(AUCTION_DURATION, start);
      expect(await mintPasses.start()).to.equal(start);
      expect(await mintPasses.auctionDuration()).to.equal(
        AUCTION_DURATION * 60
      );
      expect(await mintPasses.isAuctionFinished()).to.equal(false);

      expect(await mintPasses.start()).to.equal(start);
      expect(await mintPasses.auctionDuration()).to.equal(
        AUCTION_DURATION * 60
      );
      expect(await mintPasses.isAuctionFinished()).to.equal(false);

      await increaseTimeTo(
        toBN(start)
          .plus(AUCTION_DURATION * 60)
          .plus(10)
          .toString()
      );
      expect(await mintPasses.start()).to.equal(start);
      expect(await mintPasses.auctionDuration()).to.equal(
        AUCTION_DURATION * 60
      );
      expect(await mintPasses.isAuctionFinished()).to.equal(true);
    });
    it("finishAuction manually", async () => {
      const start = await getTime();
      await mintPasses.connect(owner).startAuction(AUCTION_DURATION, start);
      expect(await mintPasses.start()).to.equal(start);
      expect(await mintPasses.auctionDuration()).to.equal(
        AUCTION_DURATION * 60
      );
      expect(await mintPasses.isAuctionFinished()).to.equal(false);

      await increaseTime(toBN(10).toString());
      expect(await mintPasses.start()).to.equal(start);
      expect(await mintPasses.auctionDuration()).to.equal(
        AUCTION_DURATION * 60
      );
      expect(await mintPasses.isAuctionFinished()).to.equal(false);

      await mintPasses.connect(owner).finishAuction();
      const end = await getTime();

      expect(await mintPasses.start()).to.equal(start);
      expect(await mintPasses.auctionDuration()).to.equal(
        toBN(end - start)
          .minus(1)
          .toString()
      );
      expect(await mintPasses.isAuctionFinished()).to.equal(true);
    });
  });

  describe("bid", async () => {
    const bidsAmount = 1;
    const bidValue = toBN(args.MINT_PASS_MINIMUM_BID_AMOUNT).plus(1).toString();
    const value = toBN(bidValue).times(bidsAmount).toString();

    it("reverts if auction not active", async () => {
      const reason = "Auction inactive";

      await mintPasses.connect(owner).finishAuction();

      await expect(
        mintPasses.connect(user1).bid(bidsAmount, bidValue, {
          value: value,
        })
      ).to.be.revertedWith(reason);

      const start = await getTime();
      await mintPasses.connect(owner).startAuction(AUCTION_DURATION, start);
      await increaseTime(toBN(10).toString());

      await mintPasses.connect(owner).finishAuction();
      await expect(
        mintPasses.connect(user1).bid(bidsAmount, bidValue, {
          value: value,
        })
      ).to.be.revertedWith(reason);
    });
    it("reverts if lower than minimum bid", async () => {
      const reason = "Bid value must be bigger then minimum bid";

      const start = await getTime();
      await mintPasses.connect(owner).startAuction(AUCTION_DURATION, start);

      let bidValue = 0;
      await expect(
        mintPasses.connect(user1).bid(bidsAmount, bidValue, {
          value: toBN(bidValue).times(bidsAmount).toString(),
        })
      ).to.be.revertedWith(reason);

      bidValue = toBN(args.MINT_PASS_MINIMUM_BID_AMOUNT).toString();
      await expect(
        mintPasses.connect(user1).bid(bidsAmount, bidValue, {
          value: toBN(bidValue).times(bidsAmount).toString(),
        })
      ).to.be.revertedWith(reason);
    });
    it("reverts if not enough funds", async () => {
      const reason = "There is not enough funds to make bids";

      const start = await getTime();
      await mintPasses.connect(owner).startAuction(AUCTION_DURATION, start);

      await expect(
        mintPasses.connect(user1).bid(bidsAmount, bidValue, {
          value: toBN(0).toString(),
        })
      ).to.be.revertedWith(reason);

      await expect(
        mintPasses.connect(user1).bid(bidsAmount, bidValue, {
          value: toBN(bidValue).times(bidsAmount).minus(1).toString(),
        })
      ).to.be.revertedWith(reason);
    });
    it("reverts if too many bids", async () => {
      const reason = "Too many bids during 1 transaction";

      const start = await getTime();
      await mintPasses.connect(owner).startAuction(AUCTION_DURATION, start);

      let bidsAmount = 31;
      await expect(
        mintPasses.connect(user1).bid(bidsAmount, bidValue, {
          value: toBN(bidValue).times(bidsAmount).toString(),
        })
      ).to.be.revertedWith(reason);
    });
    it("places bid succcesfully", async () => {
      const start = await getTime();
      await mintPasses.connect(owner).startAuction(AUCTION_DURATION, start);

      const time = await getTime();
      const tx = await mintPasses.connect(user1).bid(bidsAmount, bidValue, {
        value: value,
      });

      expect(tx).to.changeEtherBalance(user1, -value);
      expect(tx).to.changeEtherBalance(mintPasses, value);

      // getter
      const allBidCount = await mintPasses.countAllBids();
      const allBidList = await mintPasses.getListBids(
        0,
        allBidCount,
        ListOption.ALL,
        ZERO_ADDRESS
      );
      expect(allBidList[0].bidIndex).to.equal(1);
      expect(allBidList[0].bidder).to.equal(user1.address);
      expect(allBidList[0].bidValue).to.equal(bidValue);
      expect(allBidList[0].timestamp).to.equal(time);
      expect(allBidList[0].class).to.equal(BidClass.NONE);
      expect(allBidList[0].claimed).to.equal(false);

      const ownedBidCount = await mintPasses.countOwnedBids(user1.address);
      const ownedBidList = await mintPasses.getListBids(
        0,
        ownedBidCount,
        ListOption.OWNED,
        user1.address
      );
      expect(ownedBidList[0].bidIndex).to.equal(1);
      expect(ownedBidList[0].bidder).to.equal(user1.address);
      expect(ownedBidList[0].bidValue).to.equal(bidValue);
      expect(ownedBidList[0].timestamp).to.equal(time);
      expect(ownedBidList[0].class).to.equal(BidClass.NONE);
      expect(ownedBidList[0].claimed).to.equal(false);
    });
    it("emits BidPlaced", async () => {
      const start = await getTime();
      await mintPasses.connect(owner).startAuction(AUCTION_DURATION, start);

      await expect(
        mintPasses.connect(user1).bid(bidsAmount, bidValue, {
          value: value,
        })
      )
        .to.emit(mintPasses, "BidPlaced")
        .withArgs(user1.address, bidValue, 1, (await getTime()).toString());
    });
  });

  describe("updateBid", async () => {
    const bidsAmount = 1;
    const bidValue = toBN(args.MINT_PASS_MINIMUM_BID_AMOUNT).plus(1).toString();
    const valueCreate = toBN(bidValue).times(bidsAmount).toString();

    let valueUpdate;

    beforeEach("setup", async () => {
      const start = await getTime();
      await mintPasses.connect(owner).startAuction(AUCTION_DURATION, start);

      await mintPasses.connect(user1).bid(bidsAmount, bidValue, {
        value: valueCreate,
      });

      valueUpdate = toWei("1");
    });

    it("reverts if auction not active", async () => {
      const reason = "Auction inactive";

      await mintPasses.connect(owner).finishAuction();

      await expect(
        mintPasses.connect(user1).updateBid(1, { value: valueUpdate })
      ).to.be.revertedWith(reason);
    });
    it("reverts if inexistant bid", async () => {
      const reason = "Not the owner of the bid";

      await expect(
        mintPasses.connect(user1).updateBid(0, { value: valueUpdate })
      ).to.be.revertedWith(reason);

      await expect(
        mintPasses.connect(user1).updateBid(2, { value: valueUpdate })
      ).to.be.revertedWith(reason);
    });
    it("reverts if not enough funds", async () => {
      const reason = "There is not enough funds to update bid";

      await expect(
        mintPasses.connect(user1).updateBid(1, { value: toBN(0).toString() })
      ).to.be.revertedWith(reason);
    });
    it("reverts if not owner of bid", async () => {
      const reason = "Not the owner of the bid";

      await expect(
        mintPasses.connect(user2).updateBid(1, { value: valueUpdate })
      ).to.be.revertedWith(reason);
    });
    it("update bid succcesfully", async () => {
      const time = await getTime();
      const tx = await mintPasses
        .connect(user1)
        .updateBid(1, { value: valueUpdate });

      expect(tx).to.changeEtherBalance(user1, -valueUpdate);
      expect(tx).to.changeEtherBalance(mintPasses, valueUpdate);

      // getter
      const allBidCount = await mintPasses.countAllBids();
      const allBidList = await mintPasses.getListBids(
        0,
        allBidCount,
        ListOption.ALL,
        ZERO_ADDRESS
      );
      expect(allBidList[0].bidIndex).to.equal(1);
      expect(allBidList[0].bidder).to.equal(user1.address);
      expect(allBidList[0].bidValue).to.equal(
        toBN(bidValue.toString()).plus(valueUpdate).toString()
      );
      expect(allBidList[0].timestamp).to.equal(time);
      expect(allBidList[0].class).to.equal(BidClass.NONE);
      expect(allBidList[0].claimed).to.equal(false);

      const ownedBidCount = await mintPasses.countOwnedBids(user1.address);
      const ownedBidList = await mintPasses.getListBids(
        0,
        ownedBidCount,
        ListOption.OWNED,
        user1.address
      );
      expect(ownedBidList[0].bidIndex).to.equal(1);
      expect(ownedBidList[0].bidder).to.equal(user1.address);
      expect(ownedBidList[0].bidValue).to.equal(
        toBN(bidValue.toString()).plus(valueUpdate).toString()
      );
      expect(ownedBidList[0].timestamp).to.equal(time);
      expect(ownedBidList[0].class).to.equal(BidClass.NONE);
      expect(ownedBidList[0].claimed).to.equal(false);
    });
    it("emits BidUpdated", async () => {
      await expect(
        mintPasses.connect(user1).updateBid(1, {
          value: valueUpdate,
        })
      )
        .to.emit(mintPasses, "BidUpdated")
        .withArgs(
          user1.address,
          bidValue,
          toBN(bidValue.toString()).plus(valueUpdate).toString(),
          1,
          (await getTime()).toString()
        );
    });
  });

  describe("cancelBid", async () => {
    const bidsAmount = 1;
    const bidValue = toBN(args.MINT_PASS_MINIMUM_BID_AMOUNT).plus(1).toString();
    const value = toBN(bidValue).times(bidsAmount).toString();

    beforeEach("setup", async () => {
      const start = await getTime();
      await mintPasses.connect(owner).startAuction(AUCTION_DURATION, start);

      await mintPasses.connect(user1).bid(bidsAmount, bidValue, {
        value: value,
      });
    });

    it("reverts if auction not finished", async () => {
      const reason = "Auction active";

      await expect(mintPasses.connect(user1).cancelBid(1)).to.be.revertedWith(
        reason
      );
    });
    it("reverts if inexistant bid", async () => {
      const reason = "Not the owner of the bid";

      await mintPasses.connect(owner).finishAuction();

      await expect(mintPasses.connect(user1).cancelBid(0)).to.be.revertedWith(
        reason
      );

      await expect(mintPasses.connect(user1).cancelBid(2)).to.be.revertedWith(
        reason
      );
    });
    it("reverts if not owner of bid", async () => {
      const reason = "Not the owner of the bid";

      await mintPasses.connect(owner).finishAuction();

      await expect(mintPasses.connect(user2).cancelBid(1)).to.be.revertedWith(
        reason
      );
    });
    it("cancel bid succcesfully", async () => {
      await mintPasses.connect(owner).finishAuction();

      const tx = await mintPasses.connect(user1).cancelBid(1);

      expect(tx).to.changeEtherBalance(user1, value);
      expect(tx).to.changeEtherBalance(mintPasses, -value);

      // getter
      const allBidCount = await mintPasses.countAllBids();
      const allBidList = await mintPasses.getListBids(
        0,
        allBidCount,
        ListOption.ALL,
        ZERO_ADDRESS
      );
      expect(allBidCount).to.equal(0);
      expect(allBidList.length).to.equal(0);

      const ownedBidCount = await mintPasses.countOwnedBids(user1.address);
      const ownedBidList = await mintPasses.getListBids(
        0,
        ownedBidCount,
        ListOption.OWNED,
        user1.address
      );
      expect(ownedBidCount).to.equal(0);
      expect(ownedBidList.length).to.equal(0);
    });
    it("emits BidCanceled", async () => {
      await mintPasses.connect(owner).finishAuction();

      await expect(mintPasses.connect(user1).cancelBid(1))
        .to.emit(mintPasses, "BidCanceled")
        .withArgs(user1.address, value, 1, (await getTime()).toString());
    });
  });

  describe("getBidClass", async () => {
    const bidsAmounts = [30, 30, 30, 30, 30, 30, 30];
    const bidValues = [
      toBN(args.MINT_PASS_MINIMUM_BID_AMOUNT).times(2).toString(),
      toBN(args.MINT_PASS_MINIMUM_BID_AMOUNT).times(10).toString(),
      toBN(args.MINT_PASS_MINIMUM_BID_AMOUNT).times(20).toString(),
      toBN(args.MINT_PASS_MINIMUM_BID_AMOUNT).times(30).toString(),
      toBN(args.MINT_PASS_MINIMUM_BID_AMOUNT).times(40).toString(),
      toBN(args.MINT_PASS_MINIMUM_BID_AMOUNT).times(50).toString(),
    ];

    beforeEach("setup", async () => {
      const start = await getTime();
      await mintPasses.connect(owner).startAuction(AUCTION_DURATION, start);

      await mintPasses.connect(user1).bid(bidsAmounts[0], bidValues[0], {
        value: toBN(bidValues[0]).times(bidsAmounts[0]).toFixed().toString(),
      });
      await mintPasses.connect(user2).bid(bidsAmounts[1], bidValues[1], {
        value: toBN(bidValues[1]).times(bidsAmounts[1]).toFixed().toString(),
      });
      await mintPasses.connect(user3).bid(bidsAmounts[2], bidValues[2], {
        value: toBN(bidValues[2]).times(bidsAmounts[2]).toFixed().toString(),
      });
      await mintPasses.connect(user4).bid(bidsAmounts[3], bidValues[3], {
        value: toBN(bidValues[3]).times(bidsAmounts[3]).toFixed().toString(),
      });
      await mintPasses.connect(user5).bid(bidsAmounts[4], bidValues[4], {
        value: toBN(bidValues[4]).times(bidsAmounts[4]).toFixed().toString(),
      });
      await mintPasses.connect(user6).bid(bidsAmounts[5], bidValues[5], {
        value: toBN(bidValues[5]).times(bidsAmounts[5]).toFixed().toString(),
      });

      await mintPasses.connect(owner).finishAuction();
    });

    it("has no class yet", async () => {
      const listU1Bids = await mintPasses.getListBids(
        0,
        30,
        ListOption.OWNED,
        user1.address
      );
      for (let i = 0; i < 30; i++) {
        expect(listU1Bids[i].class).to.equal(BidClass.NONE);
      }
      const listU2Bids = await mintPasses.getListBids(
        0,
        30,
        ListOption.OWNED,
        user2.address
      );
      for (let i = 0; i < 30; i++) {
        expect(listU2Bids[i].class).to.equal(BidClass.NONE);
      }
      const listU3Bids = await mintPasses.getListBids(
        0,
        30,
        ListOption.OWNED,
        user3.address
      );
      for (let i = 0; i < 30; i++) {
        expect(listU3Bids[i].class).to.equal(BidClass.NONE);
      }
      const listU4Bids = await mintPasses.getListBids(
        0,
        30,
        ListOption.OWNED,
        user4.address
      );
      for (let i = 0; i < 30; i++) {
        expect(listU4Bids[i].class).to.equal(BidClass.NONE);
      }
      const listU5Bids = await mintPasses.getListBids(
        0,
        30,
        ListOption.OWNED,
        user5.address
      );
      for (let i = 0; i < 30; i++) {
        expect(listU5Bids[i].class).to.equal(BidClass.NONE);
      }
      const listU6Bids = await mintPasses.getListBids(
        0,
        30,
        ListOption.OWNED,
        user6.address
      );
      for (let i = 0; i < 30; i++) {
        expect(listU6Bids[i].class).to.equal(BidClass.NONE);
      }
    });

    it("has class", async () => {
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

      const listU1Bids = await mintPasses.getListBids(
        0,
        30,
        ListOption.OWNED,
        user1.address
      );
      for (let i = 0; i < 30; i++) {
        expect(listU1Bids[i].class).to.equal(BidClass.BRONZE);
      }
      const listU2Bids = await mintPasses.getListBids(
        0,
        30,
        ListOption.OWNED,
        user2.address
      );
      for (let i = 0; i < 30; i++) {
        expect(listU2Bids[i].class).to.equal(BidClass.SILVER);
      }
      const listU3Bids = await mintPasses.getListBids(
        0,
        30,
        ListOption.OWNED,
        user3.address
      );
      for (let i = 0; i < 30; i++) {
        expect(listU3Bids[i].class).to.equal(BidClass.GOLD);
      }
      const listU4Bids = await mintPasses.getListBids(
        0,
        30,
        ListOption.OWNED,
        user4.address
      );
      for (let i = 0; i < 30; i++) {
        expect(listU4Bids[i].class).to.equal(BidClass.PLATINUM);
      }
      const listU5Bids = await mintPasses.getListBids(
        0,
        30,
        ListOption.OWNED,
        user5.address
      );
      for (let i = 0; i < 30; i++) {
        expect(listU5Bids[i].class).to.equal(BidClass.RUBY);
      }
      const listU6Bids = await mintPasses.getListBids(
        0,
        30,
        ListOption.OWNED,
        user6.address
      );
      for (let i = 0; i < 30; i++) {
        expect(listU6Bids[i].class).to.equal(BidClass.ONYX);
      }
    });
  });

  describe("claimPass", async () => {
    const bidsAmount = 1;
    const bidValue = toBN(args.MINT_PASS_MINIMUM_BID_AMOUNT)
      .times(2)
      .toString();
    const value = toBN(bidValue).times(bidsAmount).toString();

    beforeEach("setup", async () => {
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

      const start = await getTime();
      await mintPasses.connect(owner).startAuction(AUCTION_DURATION, start);
    });

    it("reverts if auction active", async () => {
      const reason = "Auction active";

      await mintPasses.connect(user1).bid(bidsAmount, bidValue, {
        value: value,
      });
      expect(
        (await mintPasses.getListBids(0, 1, 0, ZERO_ADDRESS))[0].class
      ).to.equal(BidClass.BRONZE);

      await expect(mintPasses.connect(user1).claimPass([1])).to.be.revertedWith(
        reason
      );
    });
    it("reverts if too much to claim", async () => {
      const reason = "Too much indexes";

      await mintPasses.connect(user1).bid(bidsAmount, bidValue, {
        value: value,
      });

      await mintPasses.connect(user1).bid(30, bidValue, {
        value: toBN(bidValue).times(30).toString(),
      });

      expect(
        (await mintPasses.getListBids(0, 31, 0, ZERO_ADDRESS))[0].class
      ).to.equal(BidClass.BRONZE);

      await mintPasses.connect(owner).finishAuction();

      let arrayToClaim = [];
      for (let i = 1; i < 32; i++) {
        arrayToClaim.push(i);
      }

      await expect(
        mintPasses.connect(user1).claimPass(arrayToClaim)
      ).to.be.revertedWith(reason);
    });
    it("claim pass successfully", async () => {
      const time = await getTime();
      await mintPasses.connect(user1).bid(bidsAmount, bidValue, {
        value: value,
      });
      expect(
        (await mintPasses.getListBids(0, 1, 0, ZERO_ADDRESS))[0].class
      ).to.equal(BidClass.BRONZE);
      await mintPasses.connect(owner).finishAuction();

      const tx = await mintPasses.connect(user1).claimPass([1]);

      expect(tx).to.changeEtherBalance(mintPasses, -value);
      expect(tx).to.changeEtherBalance(await mintPasses.treasury(), value);

      expect(tx).to.changeTokenBalance(mintPasses, user1, 1);

      // getter
      const allBidCount = await mintPasses.countAllBids();
      const allBidList = await mintPasses.getListBids(
        0,
        allBidCount,
        ListOption.ALL,
        ZERO_ADDRESS
      );
      expect(allBidList[0].bidIndex).to.equal(1);
      expect(allBidList[0].bidder).to.equal(user1.address);
      expect(allBidList[0].bidValue).to.equal(bidValue);
      expect(allBidList[0].timestamp).to.equal(time);
      expect(allBidList[0].class).to.equal(BidClass.BRONZE);
      expect(allBidList[0].claimed).to.equal(true);

      const ownedBidCount = await mintPasses.countOwnedBids(user1.address);
      const ownedBidList = await mintPasses.getListBids(
        0,
        ownedBidCount,
        ListOption.OWNED,
        user1.address
      );
      expect(ownedBidList[0].bidIndex).to.equal(1);
      expect(ownedBidList[0].bidder).to.equal(user1.address);
      expect(ownedBidList[0].bidValue).to.equal(bidValue);
      expect(ownedBidList[0].timestamp).to.equal(time);
      expect(ownedBidList[0].class).to.equal(BidClass.BRONZE);
      expect(ownedBidList[0].claimed).to.equal(true);

      // TODO test rarity generation
    });
    it("does not take action if inexistant bid", async () => {
      const time = await getTime();
      await mintPasses.connect(user1).bid(bidsAmount, bidValue, {
        value: value,
      });
      expect(
        (await mintPasses.getListBids(0, 1, 0, ZERO_ADDRESS))[0].class
      ).to.equal(BidClass.BRONZE);
      await mintPasses.connect(owner).finishAuction();

      const tx = await mintPasses.connect(user1).claimPass([0, 2]);

      expect(tx).to.changeEtherBalance(mintPasses, 0);
      expect(tx).to.changeEtherBalance(await mintPasses.treasury(), 0);

      expect(tx).to.changeTokenBalance(mintPasses, user1, 0);
      expect(tx).to.changeTokenBalance(mintPasses, user2, 0);

      // getter
      const allBidCount = await mintPasses.countAllBids();
      const allBidList = await mintPasses.getListBids(
        0,
        allBidCount,
        ListOption.ALL,
        ZERO_ADDRESS
      );
      expect(allBidList[0].bidIndex).to.equal(1);
      expect(allBidList[0].bidder).to.equal(user1.address);
      expect(allBidList[0].bidValue).to.equal(bidValue);
      expect(allBidList[0].timestamp).to.equal(time);
      expect(allBidList[0].class).to.equal(BidClass.BRONZE);
      expect(allBidList[0].claimed).to.equal(false);

      const ownedBidCount = await mintPasses.countOwnedBids(user1.address);
      const ownedBidList = await mintPasses.getListBids(
        0,
        ownedBidCount,
        ListOption.OWNED,
        user1.address
      );
      expect(ownedBidList[0].bidIndex).to.equal(1);
      expect(ownedBidList[0].bidder).to.equal(user1.address);
      expect(ownedBidList[0].bidValue).to.equal(bidValue);
      expect(ownedBidList[0].timestamp).to.equal(time);
      expect(ownedBidList[0].class).to.equal(BidClass.BRONZE);
      expect(ownedBidList[0].claimed).to.equal(false);
    });
    it("does not take action if not owner of bid", async () => {
      const time = await getTime();
      await mintPasses.connect(user1).bid(bidsAmount, bidValue, {
        value: value,
      });
      expect(
        (await mintPasses.getListBids(0, 1, 0, ZERO_ADDRESS))[0].class
      ).to.equal(BidClass.BRONZE);
      await mintPasses.connect(owner).finishAuction();

      const tx = await mintPasses.connect(user2).claimPass([1]);

      expect(tx).to.changeEtherBalance(mintPasses, 0);
      expect(tx).to.changeEtherBalance(await mintPasses.treasury(), 0);

      expect(tx).to.changeTokenBalance(mintPasses, user1, 0);
      expect(tx).to.changeTokenBalance(mintPasses, user2, 0);

      // getter
      const allBidCount = await mintPasses.countAllBids();
      const allBidList = await mintPasses.getListBids(
        0,
        allBidCount,
        ListOption.ALL,
        ZERO_ADDRESS
      );
      expect(allBidList[0].bidIndex).to.equal(1);
      expect(allBidList[0].bidder).to.equal(user1.address);
      expect(allBidList[0].bidValue).to.equal(bidValue);
      expect(allBidList[0].timestamp).to.equal(time);
      expect(allBidList[0].class).to.equal(BidClass.BRONZE);
      expect(allBidList[0].claimed).to.equal(false);

      const ownedBidCount = await mintPasses.countOwnedBids(user1.address);
      const ownedBidList = await mintPasses.getListBids(
        0,
        ownedBidCount,
        ListOption.OWNED,
        user1.address
      );
      expect(ownedBidList[0].bidIndex).to.equal(1);
      expect(ownedBidList[0].bidder).to.equal(user1.address);
      expect(ownedBidList[0].bidValue).to.equal(bidValue);
      expect(ownedBidList[0].timestamp).to.equal(time);
      expect(ownedBidList[0].class).to.equal(BidClass.BRONZE);
      expect(ownedBidList[0].claimed).to.equal(false);
    });
    it("does not take action if bid already claimed", async () => {
      const time = await getTime();
      await mintPasses.connect(user1).bid(bidsAmount, bidValue, {
        value: value,
      });
      expect(
        (await mintPasses.getListBids(0, 1, 0, ZERO_ADDRESS))[0].class
      ).to.equal(BidClass.BRONZE);
      await mintPasses.connect(owner).finishAuction();

      await mintPasses.connect(user1).claimPass([1]);

      const tx = await mintPasses.connect(user1).claimPass([1]);

      expect(tx).to.changeEtherBalance(mintPasses, 0);
      expect(tx).to.changeEtherBalance(await mintPasses.treasury(), 0);

      expect(tx).to.changeTokenBalance(mintPasses, user1, 0);
      expect(tx).to.changeTokenBalance(mintPasses, user2, 0);

      // getter
      const allBidCount = await mintPasses.countAllBids();
      const allBidList = await mintPasses.getListBids(
        0,
        allBidCount,
        ListOption.ALL,
        ZERO_ADDRESS
      );
      expect(allBidList[0].bidIndex).to.equal(1);
      expect(allBidList[0].bidder).to.equal(user1.address);
      expect(allBidList[0].bidValue).to.equal(bidValue);
      expect(allBidList[0].timestamp).to.equal(time);
      expect(allBidList[0].class).to.equal(BidClass.BRONZE);
      expect(allBidList[0].claimed).to.equal(true);

      const ownedBidCount = await mintPasses.countOwnedBids(user1.address);
      const ownedBidList = await mintPasses.getListBids(
        0,
        ownedBidCount,
        ListOption.OWNED,
        user1.address
      );
      expect(ownedBidList[0].bidIndex).to.equal(1);
      expect(ownedBidList[0].bidder).to.equal(user1.address);
      expect(ownedBidList[0].bidValue).to.equal(bidValue);
      expect(ownedBidList[0].timestamp).to.equal(time);
      expect(ownedBidList[0].class).to.equal(BidClass.BRONZE);
      expect(ownedBidList[0].claimed).to.equal(true);
    });
    it("does not take action if bid is not won", async () => {
      const time = await getTime();
      let bidValue = toBN(args.MINT_PASS_MINIMUM_BID_AMOUNT).plus(1).toString();
      await mintPasses.connect(user1).bid(bidsAmount, bidValue, {
        value: value,
      });
      expect(
        (await mintPasses.getListBids(0, 1, 0, ZERO_ADDRESS))[0].class
      ).to.equal(BidClass.NONE);
      await mintPasses.connect(owner).finishAuction();

      const tx = await mintPasses.connect(user1).claimPass([1]);

      expect(tx).to.changeEtherBalance(mintPasses, 0);
      expect(tx).to.changeEtherBalance(await mintPasses.treasury(), 0);

      expect(tx).to.changeTokenBalance(mintPasses, user1, 0);
      expect(tx).to.changeTokenBalance(mintPasses, user2, 0);

      // getter
      const allBidCount = await mintPasses.countAllBids();
      const allBidList = await mintPasses.getListBids(
        0,
        allBidCount,
        ListOption.ALL,
        ZERO_ADDRESS
      );
      expect(allBidList[0].bidIndex).to.equal(1);
      expect(allBidList[0].bidder).to.equal(user1.address);
      expect(allBidList[0].bidValue).to.equal(bidValue);
      expect(allBidList[0].timestamp).to.equal(time);
      expect(allBidList[0].class).to.equal(BidClass.NONE);
      expect(allBidList[0].claimed).to.equal(false);

      const ownedBidCount = await mintPasses.countOwnedBids(user1.address);
      const ownedBidList = await mintPasses.getListBids(
        0,
        ownedBidCount,
        ListOption.OWNED,
        user1.address
      );
      expect(ownedBidList[0].bidIndex).to.equal(1);
      expect(ownedBidList[0].bidder).to.equal(user1.address);
      expect(ownedBidList[0].bidValue).to.equal(bidValue);
      expect(ownedBidList[0].timestamp).to.equal(time);
      expect(ownedBidList[0].class).to.equal(BidClass.NONE);
      expect(ownedBidList[0].claimed).to.equal(false);
    });
    it("emits PassClaimed", async () => {
      await mintPasses.connect(user1).bid(bidsAmount, bidValue, {
        value: value,
      });
      expect(
        (await mintPasses.getListBids(0, 1, 0, ZERO_ADDRESS))[0].class
      ).to.equal(BidClass.BRONZE);
      await mintPasses.connect(owner).finishAuction();

      await expect(mintPasses.connect(user1).claimPass([1]))
        .to.emit(mintPasses, "PassClaimed")
        .withArgs(user1.address, 0, 1, (await getTime()).toString());
    });
  });

  describe("claimPromotionMintingPasses", async () => {
    beforeEach("setup", async () => {
      const start = await getTime();
      await mintPasses.connect(owner).startAuction(AUCTION_DURATION, start);

      await mintPasses.connect(owner).addPromotionMintingAddress(user1.address);
      await mintPasses.connect(owner).addPromotionMintingAddress(user2.address);
    });
    it("reverts if auction active", async () => {
      const reason = "Auction active";

      await expect(
        mintPasses.connect(user1).claimPromotionMintingPasses()
      ).to.be.revertedWith(reason);
    });
    it("reverts if not beneficiary", async () => {
      const reason = "MintPasses: not beneficary";

      await mintPasses.connect(owner).finishAuction();

      await expect(
        mintPasses.connect(user3).claimPromotionMintingPasses()
      ).to.be.revertedWith(reason);
    });
    it("reverts if already claimed", async () => {
      const reason = "MintPasses: not beneficary";

      await mintPasses.connect(owner).finishAuction();

      await mintPasses.connect(user1).claimPromotionMintingPasses();

      await expect(
        mintPasses.connect(user1).claimPromotionMintingPasses()
      ).to.be.revertedWith(reason);
    });
    it("claim promotion pass successfully", async () => {
      await mintPasses.connect(owner).finishAuction();

      const tx1 = await mintPasses.connect(user1).claimPromotionMintingPasses();
      const tx2 = await mintPasses.connect(user2).claimPromotionMintingPasses();

      expect(tx1).to.changeTokenBalance(mintPasses, user1, 1);
      expect(tx2).to.changeTokenBalance(mintPasses, user2, 1);

      // TODO test rarity generation
    });
    it("emits PromotionPassClaimed", async () => {
      await mintPasses.connect(owner).finishAuction();

      await expect(mintPasses.connect(user1).claimPromotionMintingPasses())
        .to.emit(mintPasses, "PromotionPassClaimed")
        .withArgs(user1.address, 0, (await getTime()).toString());
    });
  });

  describe("use case", async () => {
    const bidsAmounts = [30, 30, 30, 30, 30, 30, 30];
    const bidValues = [
      toBN(args.MINT_PASS_MINIMUM_BID_AMOUNT).times(2).toString(),
      toBN(args.MINT_PASS_MINIMUM_BID_AMOUNT).times(10).toString(),
      toBN(args.MINT_PASS_MINIMUM_BID_AMOUNT).times(20).toString(),
      toBN(args.MINT_PASS_MINIMUM_BID_AMOUNT).times(30).toString(),
      toBN(args.MINT_PASS_MINIMUM_BID_AMOUNT).times(40).toString(),
      toBN(args.MINT_PASS_MINIMUM_BID_AMOUNT).times(50).toString(),
    ];

    beforeEach("setup", async () => {
      const start = await getTime();
      await mintPasses.connect(owner).startAuction(AUCTION_DURATION, start);

      await mintPasses.connect(user1).bid(bidsAmounts[0], bidValues[0], {
        value: toBN(bidValues[0]).times(bidsAmounts[0]).toFixed().toString(),
      });
      await mintPasses.connect(user2).bid(bidsAmounts[1], bidValues[1], {
        value: toBN(bidValues[1]).times(bidsAmounts[1]).toFixed().toString(),
      });
      await mintPasses.connect(user3).bid(bidsAmounts[2], bidValues[2], {
        value: toBN(bidValues[2]).times(bidsAmounts[2]).toFixed().toString(),
      });
      await mintPasses.connect(user4).bid(bidsAmounts[3], bidValues[3], {
        value: toBN(bidValues[3]).times(bidsAmounts[3]).toFixed().toString(),
      });
      await mintPasses.connect(user5).bid(bidsAmounts[4], bidValues[4], {
        value: toBN(bidValues[4]).times(bidsAmounts[4]).toFixed().toString(),
      });
      await mintPasses.connect(user6).bid(bidsAmounts[5], bidValues[5], {
        value: toBN(bidValues[5]).times(bidsAmounts[5]).toFixed().toString(),
      });

      await mintPasses.connect(owner).finishAuction();

      expect(await mintPasses.countAllBids()).to.equal(180);
      expect(await mintPasses.countOwnedBids(user1.address)).to.equal(30);
      expect(await mintPasses.countOwnedBids(user2.address)).to.equal(30);
      expect(await mintPasses.countOwnedBids(user3.address)).to.equal(30);
      expect(await mintPasses.countOwnedBids(user4.address)).to.equal(30);
      expect(await mintPasses.countOwnedBids(user5.address)).to.equal(30);
      expect(await mintPasses.countOwnedBids(user6.address)).to.equal(30);
    });

    it("obtention of mintPass", async () => {
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

      let arrayToClaim = [];
      for (let i = 1; i < 31; i++) {
        arrayToClaim.push(i);
      }
      await mintPasses.connect(user1).claimPass(arrayToClaim);

      arrayToClaim = [];
      for (let i = 31; i < 61; i++) {
        arrayToClaim.push(i);
      }
      await mintPasses.connect(user2).claimPass(arrayToClaim);

      arrayToClaim = [];
      for (let i = 61; i < 91; i++) {
        arrayToClaim.push(i);
      }
      await mintPasses.connect(user3).claimPass(arrayToClaim);

      arrayToClaim = [];
      for (let i = 91; i < 121; i++) {
        arrayToClaim.push(i);
      }
      await mintPasses.connect(user4).claimPass(arrayToClaim);

      arrayToClaim = [];
      for (let i = 121; i < 151; i++) {
        arrayToClaim.push(i);
      }
      await mintPasses.connect(user5).claimPass(arrayToClaim);

      arrayToClaim = [];
      for (let i = 151; i < 181; i++) {
        arrayToClaim.push(i);
      }
      await mintPasses.connect(user6).claimPass(arrayToClaim);

      expect(await mintPasses.balanceOf(user1.address)).to.equal(30);
      expect(await mintPasses.balanceOf(user2.address)).to.equal(30);
      expect(await mintPasses.balanceOf(user3.address)).to.equal(30);
      expect(await mintPasses.balanceOf(user4.address)).to.equal(30);
      expect(await mintPasses.balanceOf(user5.address)).to.equal(30);
      expect(await mintPasses.balanceOf(user6.address)).to.equal(30);
    });
  });

  describe.skip("get fees", async () => {
    const bidsAmount = 1;
    const bidValue = toBN(args.MINT_PASS_MINIMUM_BID_AMOUNT)
      .times(2)
      .plus(1)
      .toString();
    const value = toBN(bidValue).times(bidsAmount).toString();

    it("setClasses", async () => {
      const time = await getTime();

      const tx = await await mintPasses
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
      await getCosts(tx);
    });
    it("bid", async () => {
      const start = await getTime();
      await mintPasses.connect(owner).startAuction(AUCTION_DURATION, start);

      const tx = await mintPasses.connect(user1).bid(bidsAmount, bidValue, {
        value: value,
      });
      await getCosts(tx);
    });
    it("updateBid", async () => {
      const start = await getTime();
      await mintPasses.connect(owner).startAuction(AUCTION_DURATION, start);

      await mintPasses.connect(user1).bid(bidsAmount, bidValue, {
        value: value,
      });

      valueUpdate = toWei("1");

      const tx = await mintPasses
        .connect(user1)
        .updateBid(1, { value: valueUpdate });
      await getCosts(tx);
    });
    it("cancelBid", async () => {
      const start = await getTime();
      await mintPasses.connect(owner).startAuction(AUCTION_DURATION, start);

      await mintPasses.connect(user1).bid(bidsAmount, bidValue, {
        value: value,
      });

      await mintPasses.connect(owner).finishAuction();

      const tx = await mintPasses.connect(user1).cancelBid(1);
      await getCosts(tx);
    });
    it("claimPass", async () => {
      const start = await getTime();
      await mintPasses.connect(owner).startAuction(AUCTION_DURATION, start);

      await mintPasses.connect(user1).bid(bidsAmount, bidValue, {
        value: value,
      });

      expect(await mintPasses.auctionDuration()).to.equal(
        AUCTION_DURATION * 60
      );

      await increaseTimeTo(
        toBN(start)
          .plus(AUCTION_DURATION * 60)
          .plus(10)
          .toString()
      );
      expect(await mintPasses.isAuctionFinished()).to.equal(true);

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

      const tx = await mintPasses.connect(user1).claimPass([1]);
      await getCosts(tx);
    });
    it("claimPromotionMintingPasses", async () => {
      await mintPasses.connect(owner).addPromotionMintingAddress(user1.address);
      const tx = await mintPasses.connect(user1).claimPromotionMintingPasses();
      await getCosts(tx);
    });
  });
});
