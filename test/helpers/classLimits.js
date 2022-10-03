const { toWei } = require("./utils");

const BidClass = {
  NONE: 0,
  BRONZE: 1,
  SILVER: 2,
  GOLD: 3,
  PLATINUM: 4,
  RUBY: 5,
  ONYX: 6,
};

const classLimits = [
  { bottom: toWei("2"), top: toWei("10") },
  { bottom: toWei("10"), top: toWei("20") },
  { bottom: toWei("20"), top: toWei("30") },
  { bottom: toWei("30"), top: toWei("40") },
  { bottom: toWei("40"), top: toWei("50") },
  { bottom: toWei("50"), top: toWei("60") },
];

module.exports.classLimits = classLimits;
