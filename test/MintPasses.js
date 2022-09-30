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
  let user1;
  let user2;

  // const provider = ethers.getDefaultProvider();

  const AUCTION_DURATION = 3 * 24 * 60; // 3 days (in minutes)
  let MINT_PASS_MINIMUM_BID_AMOUNT;

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
      expect(await mintPasses.active()).to.equal(false);
      expect(await mintPasses.isAuctionFinished()).to.equal(true);

      await mintPasses.connect(owner).setStart(AUCTION_DURATION, start);
      expect(await mintPasses.auctionDuration()).to.equal(
        AUCTION_DURATION * 60
      );
      expect(await mintPasses.start()).to.equal(start);
      expect(await mintPasses.active()).to.equal(true);
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
      expect(await mintPasses.active()).to.equal(true);
      expect(await mintPasses.isAuctionFinished()).to.equal(true);
    });
    it("setStart for prolongation", async () => {
      const start1 = await getTime();

      expect(await mintPasses.start()).to.equal(0);
      expect(await mintPasses.auctionDuration()).to.equal(
        args.MINT_PASS_AUCTION_DURATION
      );
      expect(await mintPasses.active()).to.equal(false);
      expect(await mintPasses.isAuctionFinished()).to.equal(true);

      await mintPasses.connect(owner).setStart(AUCTION_DURATION, start1);
      expect(await mintPasses.auctionDuration()).to.equal(
        AUCTION_DURATION * 60
      );
      expect(await mintPasses.start()).to.equal(start1);
      expect(await mintPasses.active()).to.equal(true);
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
      expect(await mintPasses.active()).to.equal(true);
      expect(await mintPasses.isAuctionFinished()).to.equal(false);

      const start2 = await getTime();
      await mintPasses.connect(owner).setStart(AUCTION_DURATION, start2);
      expect(await mintPasses.auctionDuration()).to.equal(
        AUCTION_DURATION * 60
      );
      expect(await mintPasses.start()).to.equal(start2);
      expect(await mintPasses.active()).to.equal(true);
      expect(await mintPasses.isAuctionFinished()).to.equal(false);

      await increaseTime(
        toBN(AUCTION_DURATION * 60)
          .div(2)
          .toString()
      );
      expect(await mintPasses.active()).to.equal(true);
      expect(await mintPasses.isAuctionFinished()).to.equal(false);
    });
    it("setActive", async () => {
      const start = await getTime();
      await mintPasses.connect(owner).setStart(AUCTION_DURATION, start);
      expect(await mintPasses.start()).to.equal(start);
      expect(await mintPasses.auctionDuration()).to.equal(
        AUCTION_DURATION * 60
      );
      expect(await mintPasses.active()).to.equal(true);
      expect(await mintPasses.isAuctionFinished()).to.equal(false);

      await mintPasses.connect(owner).setActive(false);
      expect(await mintPasses.start()).to.equal(start);
      expect(await mintPasses.auctionDuration()).to.equal(
        AUCTION_DURATION * 60
      );
      expect(await mintPasses.active()).to.equal(false);
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
      expect(await mintPasses.active()).to.equal(false);
      expect(await mintPasses.isAuctionFinished()).to.equal(true);
    });
    it("finishAuction", async () => {
      const start = await getTime();
      await mintPasses.connect(owner).setStart(AUCTION_DURATION, start);
      expect(await mintPasses.start()).to.equal(start);
      expect(await mintPasses.auctionDuration()).to.equal(
        AUCTION_DURATION * 60
      );
      expect(await mintPasses.active()).to.equal(true);
      expect(await mintPasses.isAuctionFinished()).to.equal(false);

      await increaseTime(toBN(10).toString());
      expect(await mintPasses.start()).to.equal(start);
      expect(await mintPasses.auctionDuration()).to.equal(
        AUCTION_DURATION * 60
      );
      expect(await mintPasses.active()).to.equal(true);
      expect(await mintPasses.isAuctionFinished()).to.equal(false);

      await mintPasses.connect(owner).finishAuction();
      const end = await getTime();

      expect(await mintPasses.start()).to.equal(start);
      expect(await mintPasses.auctionDuration()).to.equal(
        toBN(end - start)
          .minus(1)
          .toString()
      );
      expect(await mintPasses.active()).to.equal(true);
      expect(await mintPasses.isAuctionFinished()).to.equal(true);
    });
  });

  describe("bid", async () => {
    const bidsAmount = 1;
    const bidValue = toBN(args.MINT_PASS_MINIMUM_BID_AMOUNT).plus(1).toString();
    const value = toBN(bidValue).times(bidsAmount).toString();

    it("reverts if auction not active", async () => {
      const reason = "Inactive";

      await expect(
        mintPasses.connect(user1).bid(bidsAmount, bidValue, {
          value: value,
        })
      ).to.be.revertedWith(reason);

      const start = await getTime();
      await mintPasses.connect(owner).setStart(AUCTION_DURATION, start);
      await increaseTime(toBN(10).toString());
      await mintPasses.connect(owner).setActive(false);
      await expect(
        mintPasses.connect(user1).bid(bidsAmount, bidValue, {
          value: value,
        })
      ).to.be.revertedWith(reason);

      await mintPasses.connect(owner).setActive(true);
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
      await mintPasses.connect(owner).setStart(AUCTION_DURATION, start);

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
      await mintPasses.connect(owner).setStart(AUCTION_DURATION, start);

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
      await mintPasses.connect(owner).setStart(AUCTION_DURATION, start);

      let bidsAmount = 31;
      await expect(
        mintPasses.connect(user1).bid(bidsAmount, bidValue, {
          value: toBN(bidValue).times(bidsAmount).toString(),
        })
      ).to.be.revertedWith(reason);
    });
    it("places bid succcesfully", async () => {
      const start = await getTime();
      await mintPasses.connect(owner).setStart(AUCTION_DURATION, start);

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
        ListOption.ALL
      );

      expect(allBidList[0].bidder).to.equal(user1.address);
      expect(allBidList[0].bidValue).to.equal(bidValue);
      expect(allBidList[0].timestamp).to.equal(time);
      expect(allBidList[0].class).to.equal(BidClass.NONE);
      expect(allBidList[0].claimed).to.equal(false);

      const ownedBidCount = await mintPasses.connect(user1).countOwnedBids();
      const ownedBidList = await mintPasses
        .connect(user1)
        .getListBids(0, ownedBidCount, ListOption.OWNED);

      expect(ownedBidList[0].bidder).to.equal(user1.address);
      expect(ownedBidList[0].bidValue).to.equal(bidValue);
      expect(ownedBidList[0].timestamp).to.equal(time);
      expect(ownedBidList[0].class).to.equal(BidClass.NONE);
      expect(ownedBidList[0].claimed).to.equal(false);
    });
    it("emits BidPlaced", async () => {
      const start = await getTime();
      await mintPasses.connect(owner).setStart(AUCTION_DURATION, start);

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
      await mintPasses.connect(owner).setStart(AUCTION_DURATION, start);

      await mintPasses.connect(user1).bid(bidsAmount, bidValue, {
        value: valueCreate,
      });

      valueUpdate = toWei("1");
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
    it("reverts if auction not active", async () => {
      const reason = "Inactive";

      await mintPasses.connect(owner).setActive(false);

      await expect(
        mintPasses.connect(user1).updateBid(1, { value: valueUpdate })
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
        ListOption.ALL
      );

      expect(allBidList[0].bidder).to.equal(user1.address);
      expect(allBidList[0].bidValue).to.equal(
        toBN(bidValue.toString()).plus(valueUpdate).toString()
      );
      expect(allBidList[0].timestamp).to.equal(time);
      expect(allBidList[0].class).to.equal(BidClass.NONE);
      expect(allBidList[0].claimed).to.equal(false);

      const ownedBidCount = await mintPasses.connect(user1).countOwnedBids();
      const ownedBidList = await mintPasses
        .connect(user1)
        .getListBids(0, ownedBidCount, ListOption.OWNED);

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
      await mintPasses.connect(owner).setStart(AUCTION_DURATION, start);

      await mintPasses.connect(user1).bid(bidsAmount, bidValue, {
        value: value,
      });
    });

    it("reverts if inexistant bid", async () => {
      const reason = "Not the owner of the bid";

      await expect(mintPasses.connect(user1).cancelBid(0)).to.be.revertedWith(
        reason
      );

      await expect(mintPasses.connect(user1).cancelBid(2)).to.be.revertedWith(
        reason
      );
    });
    it("reverts if auction not finished", async () => {
      const reason = "";

      await mintPasses.connect(owner).finishAuction();

      await expect(mintPasses.connect(user1).cancelBid(1)).to.be.revertedWith(
        reason
      );
    });
    it("reverts if auction finished and class limits sets and bid class NONE", async () => {
      const reason = "";
      // TODO
      // why ?
    });
    it("reverts if not owner of bid", async () => {
      const reason = "Not the owner of the bid";

      await expect(mintPasses.connect(user2).cancelBid(1)).to.be.revertedWith(
        reason
      );
    });
    it("cancel bid succcesfully", async () => {
      const tx = await mintPasses.connect(user1).cancelBid(1);

      expect(tx).to.changeEtherBalance(user1, value);
      expect(tx).to.changeEtherBalance(mintPasses, -value);

      // getter
      const allBidCount = await mintPasses.countAllBids();
      const allBidList = await mintPasses.getListBids(
        0,
        allBidCount,
        ListOption.ALL
      );

      expect(allBidCount).to.equal(0);
      expect(allBidList.length).to.equal(0);

      const ownedBidCount = await mintPasses.connect(user1).countOwnedBids();
      const ownedBidList = await mintPasses
        .connect(user1)
        .getListBids(0, ownedBidCount, ListOption.OWNED);

      expect(ownedBidCount).to.equal(0);
      expect(ownedBidList.length).to.equal(0);
    });
    it("emits BidCanceled", async () => {
      await expect(mintPasses.connect(user1).cancelBid(1))
        .to.emit(mintPasses, "BidCanceled")
        .withArgs(user1.address, value, 1, (await getTime()).toString());
    });
  });

  describe("claimPass", async () => {
    const bidsAmount = 1;
    const bidValue = toBN(args.MINT_PASS_MINIMUM_BID_AMOUNT)
      .times(2)
      .plus(1)
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
      await mintPasses.connect(owner).setStart(AUCTION_DURATION, start);
    });

    it("reverts if auction active but not finished", async () => {
      const reason = "Auction inactive or hasn't finish yet";

      await mintPasses.connect(user1).bid(bidsAmount, bidValue, {
        value: value,
      });
      expect((await mintPasses.getListBids(0, 1, 0))[0].class).to.equal(
        BidClass.BRONZE
      );

      const start = await getTime();
      await mintPasses.connect(owner).setStart(AUCTION_DURATION, start);

      await expect(mintPasses.connect(user1).claimPass([1])).to.be.revertedWith(
        reason
      );
    });
    it("reverts if auction finished but not active", async () => {
      const reason = "Auction inactive or hasn't finish yet";

      await mintPasses.connect(user1).bid(bidsAmount, bidValue, {
        value: value,
      });
      expect((await mintPasses.getListBids(0, 1, 0))[0].class).to.equal(
        BidClass.BRONZE
      );
      await mintPasses.connect(owner).setActive(false);

      await expect(mintPasses.connect(user1).claimPass([1])).to.be.revertedWith(
        reason
      );
    });
    it("claim pass successfully", async () => {
      await mintPasses.connect(user1).bid(bidsAmount, bidValue, {
        value: value,
      });
      expect((await mintPasses.getListBids(0, 1, 0))[0].class).to.equal(
        BidClass.BRONZE
      );
      await mintPasses.connect(owner).finishAuction();

      await mintPasses.connect(user1).claimPass([1]);

      // TODO check storage and balances
    });
    it("does not take action if not owner of bid", async () => {
      await mintPasses.connect(user1).bid(bidsAmount, bidValue, {
        value: value,
      });
      expect((await mintPasses.getListBids(0, 1, 0))[0].class).to.equal(
        BidClass.BRONZE
      );
      await mintPasses.connect(owner).finishAuction();

      await mintPasses.connect(user2).claimPass([1]);

      // TODO check storage and balances
    });
    it("does not take action if bid already claimed", async () => {
      await mintPasses.connect(user1).bid(bidsAmount, bidValue, {
        value: value,
      });
      expect((await mintPasses.getListBids(0, 1, 0))[0].class).to.equal(
        BidClass.BRONZE
      );
      await mintPasses.connect(owner).finishAuction();

      await mintPasses.connect(user1).claimPass([1]);

      await mintPasses.connect(user1).claimPass([1]);

      // TODO check storage and balances
    });
    it("does not take action if bid is not won", async () => {
      let bidValue = toBN(args.MINT_PASS_MINIMUM_BID_AMOUNT).plus(1).toString();
      await mintPasses.connect(user1).bid(bidsAmount, bidValue, {
        value: value,
      });
      expect((await mintPasses.getListBids(0, 1, 0))[0].class).to.equal(
        BidClass.NONE
      );
      await mintPasses.connect(owner).finishAuction();

      await mintPasses.connect(user1).claimPass([1]);

      // TODO check storage and balances
    });
    it("emits PassClaimed", async () => {
      await mintPasses.connect(user1).bid(bidsAmount, bidValue, {
        value: value,
      });
      expect((await mintPasses.getListBids(0, 1, 0))[0].class).to.equal(
        BidClass.BRONZE
      );
      await mintPasses.connect(owner).finishAuction();

      await expect(mintPasses.connect(user1).claimPass([1]))
        .to.emit(mintPasses, "PassClaimed")
        .withArgs(user1.address, 0, 1, (await getTime()).toString());
    });
  });

  describe("get fees", async () => {
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
      await mintPasses.connect(owner).setStart(AUCTION_DURATION, start);

      const tx = await mintPasses.connect(user1).bid(bidsAmount, bidValue, {
        value: value,
      });
      await getCosts(tx);
    });
    it("updateBid", async () => {
      const start = await getTime();
      await mintPasses.connect(owner).setStart(AUCTION_DURATION, start);

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
      await mintPasses.connect(owner).setStart(AUCTION_DURATION, start);

      await mintPasses.connect(user1).bid(bidsAmount, bidValue, {
        value: value,
      });

      const tx = await mintPasses.connect(user1).cancelBid(1);
      await getCosts(tx);
    });
    it("claimPass", async () => {
      const start = await getTime();
      await mintPasses.connect(owner).setStart(AUCTION_DURATION, start);

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

      expect(await mintPasses.active()).to.equal(true);
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
  });
});
