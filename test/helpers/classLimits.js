const { toWei } = require("./utils");

const Class = {
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

const weightLimits = [
  { bottom: 15, top: 2500 },
  { bottom: 10, top: 2500 },
  { bottom: 5, top: 2000 },
  { bottom: 1, top: 1500 },
  { bottom: 0, top: 1000 },
  { bottom: 0, top: 8000 },
];

module.exports.Class = Class;
module.exports.classLimits = classLimits;
module.exports.weightLimits = weightLimits;
