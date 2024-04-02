const { ethers, upgrades } = require("hardhat");
const { args } = require("./arguments");
const { assets } = require("./assets");
const { weightLimits, Class } = require("./classLimits");
const { toWei } = require("./utils");

let RandomGenerator,
  Registry,
  Keter,
  Soul,
  AssetsRegistry,
  Archangel,
  Watcher,
  MintPasses,
  MintPassesHolder,
  Scion,
  Staking;
let randomGenerator,
  registry,
  keter,
  soul,
  assetsRegistry,
  archangel,
  watcher,
  mintPasses,
  mintPassesHolder,
  scion,
  staking,
  treasury;

const init = async () => {
  const users = await ethers.getSigners();

  await getContractFactory();
  await deployLibraries();
  await deployContracts();
  await deployImplementations();
  await addContracts();
  await addProxies();
  await deployProxies();
  await initContracts();
  await setDependencies();
  await setUpContracts(users);

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

const getContractFactory = async () => {
  RandomGenerator = await ethers.getContractFactory("RandomGenerator");
  Registry = await ethers.getContractFactory("Registry");
  Keter = await ethers.getContractFactory("Keter");
  Soul = await ethers.getContractFactory("Soul");
  AssetsRegistry = await ethers.getContractFactory("AssetsRegistry");
  Archangel = await ethers.getContractFactory("Archangel");
  Watcher = await ethers.getContractFactory("Watcher");
  MintPasses = await ethers.getContractFactory("MintPasses", {});
  MintPassesHolder = await ethers.getContractFactory("MintPassesHolder");
  Scion = await ethers.getContractFactory("Scion", {});
  Staking = await ethers.getContractFactory("Staking");
};

const deployLibraries = async () => {
  // Library
  randomGenerator = await RandomGenerator.deploy();
  await randomGenerator.deployed();
};

const deployContracts = async () => {
  // Registry
  registry = await Registry.deploy();
  await registry.deployed();

  // ERC20
  keter = await Keter.deploy();
  await keter.deployed();

  soul = await Soul.deploy(args.SOUL_NAME, args.SOUL_SYMBOL);
  await soul.deployed();
};

const deployImplementations = async () => {
  // Assets
  assetsRegistry = await upgrades.deployImplementation(AssetsRegistry);

  // ERC721
  archangel = await upgrades.deployImplementation(Archangel);

  watcher = await upgrades.deployImplementation(Watcher);

  mintPasses = await upgrades.deployImplementation(MintPasses);

  mintPassesHolder = await upgrades.deployImplementation(MintPassesHolder);

  scion = await upgrades.deployImplementation(Scion);

  // Staking
  staking = await upgrades.deployImplementation(Staking);
};

const addContracts = async () => {
  await registry.addContract(args.TREASURY_ID, args.TREASURY_ADDRESS);

  await registry.addContract(args.KETER_ID, keter.address);
  await registry.addContract(args.SOUL_ID, soul.address);
};

const addProxies = async () => {
  await registry.addProxyContract(args.ASSETS_ID, assetsRegistry);

  await registry.addProxyContract(args.ARCHANGEL_ID, archangel);
  await registry.addProxyContract(args.WATCHER_ID, watcher);
  await registry.addProxyContract(args.MINTPASS_ID, mintPasses);
  await registry.addProxyContract(args.MINTPASS_HOLDER_ID, mintPassesHolder);
  await registry.addProxyContract(args.SCION_ID, scion);

  await registry.addProxyContract(args.STAKING_ID, staking);
};

const deployProxies = async () => {
  // Assets
  assetsRegistry = await AssetsRegistry.attach(await registry.getContract(args.ASSETS_ID));

  // ERC721
  archangel = await Archangel.attach(await registry.getContract(args.ARCHANGEL_ID));

  watcher = await Watcher.attach(await registry.getContract(args.WATCHER_ID));

  mintPasses = await MintPasses.attach(await registry.getContract(args.MINTPASS_ID));

  mintPassesHolder = await MintPassesHolder.attach(await registry.getContract(args.MINTPASS_HOLDER_ID));

  scion = await Scion.attach(await registry.getContract(args.SCION_ID));

  // Staking
  staking = await Staking.attach(await registry.getContract(args.STAKING_ID));
};

const initContracts = async () => {
  await assetsRegistry.__AssetRegistry_init();
  await archangel.__Archangel_init(args.ARCHANGEL_NAME, args.ARCHANGEL_SYMBOL, args.ARCHANGEL_BASE_TOKEN_URI);
  await watcher.__Watcher_init(args.WATCHER_NAME, args.WATCHER_SYMBOL, args.WATCHER_BASE_TOKEN_URI);
  await mintPasses.__MintPasses_init(
    args.MINT_PASS_NAME,
    args.MINT_PASS_SYMBOL,
    args.MINT_PASS_BASE_TOKEN_URI,
    args.MINT_PASS_MINIMUM_BID_AMOUNT,
    args.MINT_PASS_AUCTION_DURATION
  );
  await mintPassesHolder.__MintPassesHolder_init();
  await scion.__Scion_init(
    args.SCION_NAME,
    args.SCION_SYMBOL,
    args.SCION_BASE_TOKEN_URI,
    args.DOWNGRADE,
    args.SAME_WEIGHT,
    args.RARITY_PLUS
  );
  await staking.__Staking_init();
};

const setDependencies = async () => {
  await soul.setDependencies(registry.address);
  await archangel.setDependencies(registry.address);
  await watcher.setDependencies(registry.address);
  await mintPasses.setDependencies(registry.address);
  await mintPassesHolder.setDependencies(registry.address);
  await scion.setDependencies(registry.address);
  await staking.setDependencies(registry.address);
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

  treasury = registry.getContract(args.TREASURY_ID);
};

exports.init = init;
