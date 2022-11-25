const { ethers, upgrades } = require("hardhat");
const { args } = require("./arguments");
const { assets } = require("./assets");
const { weightLimits, Class } = require("./classLimits");
const { toWei } = require("./utils");

const addresses = {
  goerli: {
    // --network goerli
    registryAddress: "",
    randomGeneratorAddress: "",
    keterAddress: "0xB561F45E4A3B146c8797ee5B59B097E0AC58f72e",
    soulAddress: "0xcd7490578d7c3b667864AE07A28598cABe141FDF",
    assetsRegistryAddress: "0xdff85d705D995E52f38a277E71141063c7d6B854",
    archangelAddress: "0x23bca218328A073c96b70987Edbe55294eF62A8a",
    watcherAddress: "0x49fFF65f187337404560Ad2AA54A99FccaC88601",
    mintPassesAddress: "0x562dA393D8C7615dde0C415417c86E0Fbe117f24",
    mintPassesHolderAddress: "0x562dA393D8C7615dde0C415417c86E0Fbe117f24",
    scionAddress: "0x23bca218328A073c96b70987Edbe55294eF62A8a",
    stakingAddress: "0x49fFF65f187337404560Ad2AA54A99FccaC88601",
  },
};

let network = "goerli";

let registry;
let randomGenerator;
let assetsRegistry;
let keter;
let soul;
let archangel;
let watcher;
let mintPassesHolder;
let mintPasses;
let scion;
let staking;

const treasury = "0x49fFF65f187337404560Ad2AA54A99FccaC88601";

const init = async () => {
  const users = await ethers.getSigners();

  await deployLibrary();
  await deployContracts();
  await deployImplementations();
  await addContracts();
  await addProxyContracts();
  await deployProxies();
  await initContracts();
  await setDependencies();
  await setUpContracts(users);

  //   // Library
  //   const RandomGenerator = await ethers.getContractFactory("RandomGenerator");
  //   randomGenerator = await RandomGenerator.attach(addresses[network].randomGeneratorAddress);
  //   // Registry
  //   const Registry = await ethers.getContractFactory("Registry");
  //   registry = await Registry.attach(addresses[network].registryAddress);
  //   // Assets
  //   const AssetsRegistry = await ethers.getContractFactory("AssetsRegistry");
  //   assetsRegistry = await AssetsRegistry.attach(addresses[network].assetsRegistryAddress);
  //   // ERC20
  //   const Keter = await ethers.getContractFactory("Keter");
  //   keter = await Keter.attach(addresses[network].keterAddress);
  //   const Soul = await ethers.getContractFactory("Soul");
  //   soul = await Soul.attach(addresses[network].soulAddress);
  //   // ERC721
  //   const Archangel = await ethers.getContractFactory("Archangel");
  //   archangel = await Archangel.attach(addresses[network].archangelAddress);
  //   const Watcher = await ethers.getContractFactory("Watcher");
  //   watcher = await Watcher.attach(addresses[network].watcherAddress);
  //   const MintPasses = await ethers.getContractFactory("MintPasses", {
  //     libraries: {
  //       RandomGenerator: randomGenerator.address,
  //     },
  //   });
  //   mintPasses = await MintPasses.attach(addresses[network].mintPassesAddress);
  //   const MintPassesHolder = await ethers.getContractFactory("MintPassesHolder");
  //   mintPassesHolder = await MintPassesHolder.attach(addresses[network].mintPassesHolderAddress);
  //   const Scion = await ethers.getContractFactory("Scion", {
  //     libraries: {
  //       RandomGenerator: randomGenerator.address,
  //     },
  //   });
  //   scion = await Scion.attach(addresses[network].scionAddress);
  //   // Staking
  //   const Staking = await ethers.getContractFactory("Staking");
  //   staking = await Staking.attach(addresses[network].stakingAddress);

  return {
    users,
    treasury,
    randomGenerator,
    assetsRegistry,
    keter,
    soul,
    archangel,
    watcher,
    mintPasses,
    mintPassesHolder,
    scion,
    staking,
  };
};

const deployLibrary = async () => {
  // Library
  const RandomGenerator = await ethers.getContractFactory("RandomGenerator");
  randomGenerator = await RandomGenerator.deploy();
  await randomGenerator.deployed();
};

const deployContracts = async () => {
  // Registry
  const Registry = await ethers.getContractFactory("Registry");
  registry = await Registry.deploy();
  await registry.deployed();

  // ERC20
  const Keter = await ethers.getContractFactory("Keter");
  keter = await Keter.deploy();
  await keter.deployed();

  const Soul = await ethers.getContractFactory("Soul");
  soul = await Soul.deploy(args.SOUL_NAME, args.SOUL_SYMBOL, registry.address);
  await soul.deployed();
};

const deployImplementations = async () => {
  // Assets
  const AssetsRegistry = await ethers.getContractFactory("AssetsRegistry");
  assetsRegistry = await upgrades.deployImplementation(AssetsRegistry);

  // ERC721
  const Archangel = await ethers.getContractFactory("Archangel");
  archangel = await upgrades.deployImplementation(Archangel);

  const Watcher = await ethers.getContractFactory("Watcher");
  watcher = await upgrades.deployImplementation(Watcher);

  const MintPasses = await ethers.getContractFactory("MintPasses", {
    // libraries: {
    //   RandomGenerator: randomGenerator.address,
    // },
  });
  mintPasses = await upgrades.deployImplementation(MintPasses);

  const MintPassesHolder = await ethers.getContractFactory("MintPassesHolder");
  mintPassesHolder = await upgrades.deployImplementation(MintPassesHolder);

  const Scion = await hre.ethers.getContractFactory("Scion", {
    // libraries: {
    //   RandomGenerator: randomGenerator.address,
    // },
  });
  scion = await upgrades.deployImplementation(Scion);

  // Staking
  const Staking = await hre.ethers.getContractFactory("Staking");
  staking = await upgrades.deployImplementation(Staking);
};

const addContracts = async () => {
  await registry.addContract("TREASURY", treasury);

  await registry.addContract("KETER", keter.address);
  await registry.addContract("SOUL", soul.address);
};

const addProxyContracts = async () => {
  await registry.addProxyContract("ASSETS", assetsRegistry);

  await registry.addProxyContract("ARCHANGEL", archangel);
  await registry.addProxyContract("WATCHER", watcher);
  await registry.addProxyContract("MINTPASS", mintPasses);
  await registry.addProxyContract("MINTPASS_HOLDER", mintPassesHolder);
  await registry.addProxyContract("SCION", scion);

  await registry.addProxyContract("STAKING", staking);
};

const deployProxies = async () => {
  // Assets
  const AssetsRegistry = await ethers.getContractFactory("AssetsRegistry");
  assetsRegistry = await AssetsRegistry.attach(await registry.getContract("ASSETS"));

  // ERC721
  const Archangel = await ethers.getContractFactory("Archangel");
  archangel = await Archangel.attach(await registry.getContract("ARCHANGEL"));

  const Watcher = await ethers.getContractFactory("Watcher");
  watcher = await Watcher.attach(await registry.getContract("WATCHER"));

  const MintPasses = await ethers.getContractFactory("MintPasses", {
    // libraries: {
    //   RandomGenerator: randomGenerator.address,
    // },
  });
  mintPasses = await MintPasses.attach(await registry.getContract("MINTPASS"));

  const MintPassesHolder = await ethers.getContractFactory("MintPassesHolder");
  mintPassesHolder = await MintPassesHolder.attach(await registry.getContract("MINTPASS_HOLDER"));

  const Scion = await hre.ethers.getContractFactory("Scion", {
    // libraries: {
    //   RandomGenerator: randomGenerator.address,
    // },
  });
  scion = await Scion.attach(await registry.getContract("SCION"));

  // Staking
  const Staking = await hre.ethers.getContractFactory("Staking");
  staking = await Staking.attach(await registry.getContract("STAKING"));
};

const initContracts = async () => {
  await assetsRegistry.__AssetRegistry_init();
  await archangel.__Archangel_init("", registry.address);
  await watcher.__Watcher_init("", registry.address);
  await mintPasses.__MintPasses_init(
    args.MINT_PASS_NAME,
    args.MINT_PASS_SYMBOL,
    args.MINT_PASS_BASE_TOKEN_URI,
    args.MINT_PASS_MINIMUM_BID_AMOUNT,
    args.MINT_PASS_AUCTION_DURATION,
    registry.address
  );
  await mintPassesHolder.__MintPassesHolder_init(registry.address);
  await scion.__Scion_init(
    args.SCION_NAME,
    args.SCION_SYMBOL,
    args.SCION_BASE_TOKEN_URI,
    args.DOWNGRADE,
    args.SAME_WEIGHT,
    args.RARITY_PLUS,
    registry.address
  );
  await staking.__Staking_init(registry.address);
};

const setDependencies = async () => {
  await archangel.setDependencies();
  await watcher.setDependencies();
  await mintPassesHolder.setDependencies();
  await scion.setDependencies();
  await staking.setDependencies();
};

const setUpContracts = async (users) => {
  for (const asset of assets) {
    await assetsRegistry.setAssets(asset.assetId, asset.assets, asset.weigths, asset.names);
  }

  await keter.transfer(staking.address, toWei("1000000"));
  await keter.mint(users[1].address, toWei("100000"));
  await keter.mint(users[2].address, toWei("100000"));
  await keter.mint(users[3].address, toWei("100000"));
  await keter.mint(users[4].address, toWei("100000"));
  await keter.mint(users[5].address, toWei("100000"));
  await keter.mint(users[6].address, toWei("100000"));

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

module.exports.init = init;
