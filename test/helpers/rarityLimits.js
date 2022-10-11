const { toWei } = require("./utils");

const NFTRarity = {
  COMMON: 0,
  RARE: 1,
  EPIC: 2,
  EPIC_RARE: 3,
  LENGENDARY: 4,
  MYSTIC: 5,
  EXTRA_CELESTIAL: 6,
};

const rarityLimits = [
  { bottom: toWei("1"), top: toWei("100") },
  { bottom: toWei("101"), top: toWei("150") },
  { bottom: toWei("151"), top: toWei("170") },
  { bottom: toWei("171"), top: toWei("186") },
  { bottom: toWei("187"), top: toWei("196") },
  { bottom: toWei("197"), top: toWei("200") },
];

module.exports.NFTRarity = NFTRarity;
module.exports.rarityLimits = rarityLimits;
