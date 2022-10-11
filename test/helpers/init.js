const { ethers } = require("hardhat");
const { args } = require("./arguments");
const { assets } = require("./assets");
const { weightLimits, Class } = require("./classLimits");

const addresses = {
  goerli: {
    // --network goerli
    randomGeneratorAddress: "",
    assetRegistryAddress: "0xdff85d705D995E52f38a277E71141063c7d6B854",
    keterAddress: "0xB561F45E4A3B146c8797ee5B59B097E0AC58f72e",
    soulAddress: "0xcd7490578d7c3b667864AE07A28598cABe141FDF",
    archangelAddress: "0xec6C448d425B8F63458A149043C60F596579AB84",
    mintPassesAddress: "0x562dA393D8C7615dde0C415417c86E0Fbe117f24",
    scionAddress: "0x23bca218328A073c96b70987Edbe55294eF62A8a",
    stakingAddress: "0x49fFF65f187337404560Ad2AA54A99FccaC88601",
  },
};

const network = "goerli";

const init = async (isFork) => {
  const users = await ethers.getSigners();

  let randomGenerator;
  let assetRegistry;
  let keter;
  let soul;
  let archangel;
  let mintPasses;
  let scion;
  let staking;

  if (isFork) {
    // Library
    const RandomGenerator = await ethers.getContractFactory("RandomGenerator");
    randomGenerator = await RandomGenerator.deploy();
    await randomGenerator.deployed();

    // Registry
    const AssetRegistry = await ethers.getContractFactory("AssetsRegistry");
    assetRegistry = await AssetRegistry.attach(addresses[network].assetRegistryAddress);

    // ERC20
    const Keter = await ethers.getContractFactory("Keter");
    keter = await Keter.attach(addresses[network].keterAddress);
    const Soul = await ethers.getContractFactory("Soul");
    soul = await Soul.attach(addresses[network].soulAddress);

    // ERC721
    const Archangel = await ethers.getContractFactory("Archangel");
    archangel = await Archangel.attach(addresses[network].archangelAddress);

    const MintPasses = await ethers.getContractFactory("MintPasses", {
      libraries: {
        RandomGenerator: randomGenerator.address,
      },
    });
    mintPasses = await MintPasses.attach(addresses[network].mintPassesAddress);

    const Scion = await ethers.getContractFactory("Scion", {
      libraries: {
        RandomGenerator: randomGenerator.address,
      },
    });
    scion = await Scion.attach(addresses[network].scionAddress);

    // Staking
    const Staking = await ethers.getContractFactory("Staking");
    staking = await Staking.attach(addresses[network].stakingAddress);
  } else {
    // Library
    const RandomGenerator = await ethers.getContractFactory("RandomGenerator");
    randomGenerator = await RandomGenerator.deploy();
    await randomGenerator.deployed();

    // Registry
    const AssetRegistry = await ethers.getContractFactory("AssetsRegistry");
    assetRegistry = await AssetRegistry.deploy();
    await assetRegistry.deployed();

    // ERC20
    const Keter = await ethers.getContractFactory("Keter");
    keter = await Keter.deploy();
    await keter.deployed();

    const Soul = await ethers.getContractFactory("Soul");
    soul = await Soul.deploy(args.SOUL_NAME, args.SOUL_SYMBOL);
    await soul.deployed();

    // ERC721
    const Archangel = await ethers.getContractFactory("Archangel");
    archangel = await Archangel.deploy(soul.address);
    await archangel.deployed();

    const MintPasses = await ethers.getContractFactory("MintPasses", {
      libraries: {
        RandomGenerator: randomGenerator.address,
      },
    });
    mintPasses = await MintPasses.deploy(
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

    const Scion = await hre.ethers.getContractFactory("Scion", {
      libraries: {
        RandomGenerator: randomGenerator.address,
      },
    });
    scion = await Scion.deploy(
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

    // Staking
    const Staking = await hre.ethers.getContractFactory("Staking");
    staking = await Staking.deploy(keter.address, scion.address);
    await staking.deployed();

    await mintPassesSetUp(mintPasses, scion.address);
    await assetSetUp(assetRegistry);
  }

  return {
    users,
    randomGenerator,
    assetRegistry,
    keter,
    soul,
    archangel,
    mintPasses,
    scion,
    staking,
  };
};

const mintPassesSetUp = async (mintPasses, scionAddress) => {
  await mintPasses.setScionAddress(scionAddress);

  await mintPasses.setClassesWeightLimits(
    [Class.BRONZE, Class.SILVER, Class.GOLD, Class.PLATINUM, Class.RUBY, Class.ONYX],
    [
      weightLimits[0].bottom,
      weightLimits[1].bottom,
      weightLimits[2].bottom,
      weightLimits[3].bottom,
      weightLimits[4].bottom,
      weightLimits[5].bottom,
    ],
    [
      weightLimits[0].top,
      weightLimits[1].top,
      weightLimits[2].top,
      weightLimits[3].top,
      weightLimits[4].top,
      weightLimits[5].top,
    ]
  );
};

const assetSetUp = async (assetRegistry) => {
  for (const asset of assets) {
    await assetRegistry.setAssets(asset.assetId, asset.assets, asset.weigthSum, asset.weigths, asset.names);
  }
};

module.exports.init = init;
