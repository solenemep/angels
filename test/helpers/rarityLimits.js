const { toWei } = require("./utils");

const Rarity = {
  COMMON: 0,
  RARE: 1,
  EPIC_RARE: 2,
  LENGENDARY: 3,
  MYSTIC: 4,
  EXTRA_CELESTIAL: 5,
};

const rarityLimits = [
  { bottom: 15, top: 100 },
  { bottom: 8, top: 15 },
  { bottom: 5, top: 8 },
  { bottom: 3, top: 5 },
  { bottom: 1, top: 3 },
  { bottom: 0, top: 1 },
];

module.exports.Rarity = Rarity;
module.exports.rarityLimits = rarityLimits;
