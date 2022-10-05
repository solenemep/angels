const { ethers } = require("hardhat");
const { args } = require("./arguments");
const { assets } = require("./assets");

const init = async () => {
  const users = await ethers.getSigners();
  // Registry
  const AssetRegistry = await ethers.getContractFactory("AssetsRegistry");
  const assetRegistry = await AssetRegistry.deploy();

  // ERC20
  const Keter = await ethers.getContractFactory("Keter");
  const keter = await Keter.deploy();
  await keter.deployed();

  const Soul = await ethers.getContractFactory("Soul");
  const soul = await Soul.deploy(args.SOUL_NAME, args.SOUL_SYMBOL);
  await soul.deployed();

  // ERC721
  const Archangel = await ethers.getContractFactory("Archangel");
  const archangel = await Archangel.deploy(soul.address);
  await archangel.deployed();

  const MintPasses = await ethers.getContractFactory("MintPasses");
  const mintPasses = await MintPasses.deploy(
    args.MINT_PASS_NAME,
    args.MINT_PASS_SYMBOL,
    args.MINT_PASS_BASE_TOKEN_URI,
    args.MINT_PASS_TOTAL_BIDS_LIMIT,
    args.MINT_PASS_MINIMUM_BID_AMOUNT,
    args.MINT_PASS_AUCTION_DURATION,
    args.SUBSCRIPTION_ID,
    args.VRF_COORDINATOR_ADDRESS,
    args.LINK_TOKEN_ADDRESS,
    args.VRF_KEY_HASH
  );
  await mintPasses.deployed();

  const Scion = await hre.ethers.getContractFactory("Scion");
  const scion = await Scion.deploy(
    mintPasses.address,
    soul.address,
    keter.address,
    assetRegistry.address,
    args.SCION_NAME,
    args.SCION_SYMBOL,
    args.SCION_BASE_TOKEN_URI,
    args.DOWNGRADE,
    args.SAME_WEIGHT,
    args.RARITY_PLUS
  );
  await scion.deployed();

  await mintPassesSetUp(mintPasses, scion.address);

  await assetSetUp(assetRegistry);

  return {
    users,
    assetRegistry,
    keter,
    soul,
    archangel,
    mintPasses,
    scion,
  };
};

const mintPassesSetUp = async (mintPasses, scionAddress) => {
  await mintPasses.setScionAddress(scionAddress);
};

const assetSetUp = async (assetRegistry) => {
  for (const asset of assets) {
    await assetRegistry.setAssets(
      asset.assetId,
      asset.assets,
      asset.weigthSum,
      asset.weigths,
      asset.names
    );
  }
};

module.exports.init = init;
