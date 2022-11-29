import hre from "hardhat";
import { args } from "../helpers/arguments";
import { assets } from "../helpers/assets";
import { Class, weightLimits } from "../helpers/classLimits";
import { toWei, wait } from "../helpers/utils";
import { deployed } from "../helpers/deployed";

const { upgrades } = require("hardhat");
const verify = require("../scripts/verify");

let tx, verifyScript;
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
  staking;

async function main() {
  // This is just a convenience check
  if (hre.network.name === "hardhat") {
    console.warn(
      "You are trying to deploy a contract to the Hardhat Network, which" +
        "gets automatically created and destroyed every time. Use the Hardhat" +
        " option '--network localhost'"
    );
  }

  // ethers is available in the global scope
  const [deployer] = await hre.ethers.getSigners();
  console.log(
    "Deploying the contracts with the account:",
    await deployer.getAddress()
  );
  console.log("Account balance:", (await deployer.getBalance()).toString());

  await getContractFactory();
  // await deployLibraries();
  await deployContracts();
  await deployImplementations();
  await addContracts();
  await addProxies();
  await deployProxies();
  await initContracts();
  await setDependencies();
  await setUpContracts();
  await verifyContracts();
  await printContracts();
}

async function getContractFactory() {
  RandomGenerator = await hre.ethers.getContractFactory("RandomGenerator");
  Registry = await hre.ethers.getContractFactory("Registry");
  Keter = await hre.ethers.getContractFactory("Keter");
  Soul = await hre.ethers.getContractFactory("Soul");
  AssetsRegistry = await hre.ethers.getContractFactory("AssetsRegistry");
  Archangel = await hre.ethers.getContractFactory("Archangel");
  Watcher = await hre.ethers.getContractFactory("Watcher");
  MintPasses = await hre.ethers.getContractFactory("MintPasses", {
    // libraries: {
    //   RandomGenerator: randomGenerator.address,
    // },
  });
  MintPassesHolder = await hre.ethers.getContractFactory("MintPassesHolder");
  Scion = await hre.ethers.getContractFactory("Scion", {
    // libraries: {
    //   RandomGenerator: randomGenerator.address,
    // },
  });
  Staking = await hre.ethers.getContractFactory("Staking");
}

async function deployLibraries() {
  // Library
  randomGenerator = await RandomGenerator.deploy();
  await randomGenerator.deployed();

  console.log("RandomGenerator address:", randomGenerator.address);
  await wait(30_000);
}

async function deployContracts() {
  // Registry
  registry = await Registry.deploy();
  await registry.deployed();
  console.log("Registry address:", registry.address);
  await wait(30_000);

  // ERC20
  keter = await Keter.deploy();
  await keter.deployed();
  console.log("Keter address:", keter.address);
  await wait(30_000);

  soul = await Soul.deploy(args.SOUL_NAME, args.SOUL_SYMBOL, registry.address);
  await soul.deployed();
  console.log("Soul address:", soul.address);
  await wait(30_000);
}

async function deployImplementations() {
  // Assets
  assetsRegistry = await upgrades.deployImplementation(AssetsRegistry);
  console.log("AssetsRegistry impl address:", assetsRegistry.address);
  await wait(30_000);

  // ERC721
  archangel = await upgrades.deployImplementation(Archangel);
  console.log("Archangel impl address:", archangel.address);
  await wait(30_000);

  watcher = await upgrades.deployImplementation(Watcher);
  console.log("Watcher impl address:", watcher.address);
  await wait(30_000);

  mintPasses = await upgrades.deployImplementation(MintPasses);
  console.log("MintPasses impl address:", mintPasses.address);
  await wait(30_000);

  mintPassesHolder = await upgrades.deployImplementation(MintPassesHolder);
  console.log("MintPassesHolder impl address:", mintPassesHolder.address);
  await wait(30_000);

  scion = await upgrades.deployImplementation(Scion);
  console.log("Scion impl address:", scion.address);
  await wait(30_000);

  // Staking
  staking = await upgrades.deployImplementation(Staking);
  console.log("Staking impl address:", staking.address);
  await wait(30_000);
}

async function addContracts() {
  tx = await registry.addContract(args.TREASURY_ID, args.TREASURY_ADDRESS);
  await tx.wait();

  tx = await registry.addContract(args.KETER_ID, keter.address);
  await tx.wait();
  tx = await registry.addContract(args.SOUL_ID, soul.address);
  await tx.wait();
}

async function addProxies() {
  tx = await registry.addProxyContract(args.ASSETS_ID, assetsRegistry);
  await tx.wait();

  tx = await registry.addProxyContract(args.ARCHANGEL_ID, archangel);
  await tx.wait();
  tx = await registry.addProxyContract(args.WATCHER_ID, watcher);
  await tx.wait();
  tx = await registry.addProxyContract(args.MINTPASS_ID, mintPasses);
  await tx.wait();
  tx = await registry.addProxyContract(
    args.MINTPASS_HOLDER_ID,
    mintPassesHolder
  );
  await tx.wait();
  tx = await registry.addProxyContract(args.SCION_ID, scion);
  await tx.wait();

  tx = await registry.addProxyContract(args.STAKING_ID, staking);
  await tx.wait();
}

async function deployProxies() {
  // Assets
  assetsRegistry = await AssetsRegistry.attach(
    await registry.getContract(args.ASSETS_ID)
  );
  console.log("AssetsRegistry address:", assetsRegistry.address);
  await wait(30_000);

  // ERC721
  archangel = await Archangel.attach(
    await registry.getContract(args.ARCHANGEL_ID)
  );
  console.log("Archangel address:", archangel.address);
  await wait(30_000);

  watcher = await Watcher.attach(await registry.getContract(args.WATCHER_ID));
  console.log("Watcher address:", watcher.address);
  await wait(30_000);

  mintPasses = await MintPasses.attach(
    await registry.getContract(args.MINTPASS_ID)
  );
  console.log("MintPasses address:", mintPasses.address);
  await wait(30_000);

  mintPassesHolder = await MintPassesHolder.attach(
    await registry.getContract(args.MINTPASS_HOLDER_ID)
  );
  console.log("MintPassesHolder address:", mintPassesHolder.address);
  await wait(30_000);

  scion = await Scion.attach(await registry.getContract(args.SCION_ID));
  console.log("Scion address:", scion.address);
  await wait(30_000);

  // Staking
  staking = await Staking.attach(await registry.getContract(args.STAKING_ID));
  console.log("Staking address:", staking.address);
  await wait(30_000);
}

async function initContracts() {
  await assetsRegistry.__AssetRegistry_init();
  await archangel.__Archangel_init(
    args.ARCHANGEL_NAME,
    args.ARCHANGEL_SYMBOL,
    args.ARCHANGEL_BASE_TOKEN_URI
  );
  await watcher.__Watcher_init(
    args.WATCHER_NAME,
    args.WATCHER_SYMBOL,
    args.WATCHER_BASE_TOKEN_URI
  );
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
}

async function setDependencies() {
  tx = await soul.setDependencies(registry.address);
  await tx.wait();

  tx = await archangel.setDependencies(registry.address);
  await tx.wait();
  tx = await watcher.setDependencies(registry.address);
  await tx.wait();
  tx = await mintPasses.setDependencies(registry.address);
  await tx.wait();
  tx = await mintPassesHolder.setDependencies(registry.address);
  await tx.wait();
  tx = await scion.setDependencies(registry.address);
  await tx.wait();

  tx = await staking.setDependencies(registry.address);
  await tx.wait();
}

async function setUpContracts() {
  for (const asset of assets) {
    tx = await assetsRegistry.setAssets(
      asset.assetId,
      asset.assets,
      asset.weigths,
      asset.names
    );
    await tx.wait();
  }

  tx = await keter.mint(staking.address, toWei("1000000"));
  await tx.wait();

  tx = await mintPasses.setClassesWeightLimits(
    [
      Class.BRONZE,
      Class.SILVER,
      Class.GOLD,
      Class.PLATINUM,
      Class.RUBY,
      Class.ONYX,
    ],
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
  await tx.wait();

  tx = await watcher.triggerBatchSale();
  await tx.wait();
}

async function verifyContracts() {
  console.log("Waiting 20 seconds before calling verify script...");
  await wait(20_000);

  // Registry
  verifyScript = verify.buildVerifyScript(
    "Registry",
    registry.address,
    hre.network.name,
    ``,
    false,
    ""
  );
  verify.logVerifyScript(verifyScript);
  await verify.verifyContract(verifyScript, 2);
  console.log("Registry verified");

  // ERC20
  verifyScript = verify.buildVerifyScript(
    "Keter",
    keter.address,
    hre.network.name,
    ``,
    false,
    ""
  );
  verify.logVerifyScript(verifyScript);
  await verify.verifyContract(verifyScript, 2);
  console.log("Keter verified");

  verifyScript = verify.buildVerifyScript(
    "Soul",
    soul.address,
    hre.network.name,
    `${args.SOUL_NAME} ${args.SOUL_SYMBOL}`,
    false,
    ""
  );
  verify.logVerifyScript(verifyScript);
  await verify.verifyContract(verifyScript, 2);
  console.log("Soul verified");

  // Assets
  verifyScript = verify.buildVerifyScript(
    "AssetsRegistry",
    assetsRegistry.address,
    hre.network.name,
    ``,
    false,
    ""
  );
  verify.logVerifyScript(verifyScript);
  await verify.verifyContract(verifyScript, 2);
  console.log("AssetsRegistry verified");

  // ERC721
  verifyScript = verify.buildVerifyScript(
    "Archangel",
    archangel.address,
    hre.network.name,
    `${args.ARCHANGEL_NAME} ${args.ARCHANGEL_SYMBOL} ${args.ARCHANGEL_BASE_TOKEN_URI}`,
    false,
    ""
  );
  verify.logVerifyScript(verifyScript);
  await verify.verifyContract(verifyScript, 2);
  console.log("Archangel verified");

  verifyScript = verify.buildVerifyScript(
    "Watcher",
    watcher.address,
    hre.network.name,
    `${args.WATCHER_NAME} ${args.WATCHER_SYMBOL} ${args.WATCHER_BASE_TOKEN_URI}`,
    false,
    ""
  );
  verify.logVerifyScript(verifyScript);
  await verify.verifyContract(verifyScript, 2);
  console.log("Watcher verified");

  verifyScript = verify.buildVerifyScript(
    "MintPasses",
    mintPasses.address,
    hre.network.name,
    `${args.MINT_PASS_NAME} ${args.MINT_PASS_SYMBOL} ${args.MINT_PASS_BASE_TOKEN_URI} ${args.MINT_PASS_MINIMUM_BID_AMOUNT} ${args.MINT_PASS_AUCTION_DURATION}`,
    true,
    "scripts/libraries.ts"
  );
  verify.logVerifyScript(verifyScript);
  await verify.verifyContract(verifyScript, 2);
  console.log("MintPasses verified");

  verifyScript = verify.buildVerifyScript(
    "MintPassesHolder",
    mintPassesHolder.address,
    hre.network.name,
    ``,
    false,
    ""
  );
  verify.logVerifyScript(verifyScript);
  await verify.verifyContract(verifyScript, 2);
  console.log("MintPassesHolder verified");

  verifyScript = verify.buildVerifyScript(
    "Scion",
    scion.address,
    hre.network.name,
    `${args.SCION_NAME} ${args.SCION_SYMBOL} ${args.SCION_BASE_TOKEN_URI} ${args.DOWNGRADE} ${args.SAME_WEIGHT} ${args.RARITY_PLUS}`,
    true,
    "scripts/libraries.ts"
  );
  verify.logVerifyScript(verifyScript);
  await verify.verifyContract(verifyScript, 2);
  console.log("Scion verified");

  verifyScript = verify.buildVerifyScript(
    "Staking",
    staking.address,
    hre.network.name,
    ``,
    false,
    ""
  );
  verify.logVerifyScript(verifyScript);
  await verify.verifyContract(verifyScript, 2);
  console.log("Staking verified");
}

async function printContracts() {
  await deployed(args.REGITRY_ID, hre.network.name, registry.address);
  await deployed(args.KETER_ID, hre.network.name, keter.address);
  await deployed(args.SOUL_ID, hre.network.name, soul.address);
  await deployed(args.ASSETS_ID, hre.network.name, assetsRegistry.address);
  await deployed(args.ARCHANGEL_ID, hre.network.name, archangel.address);
  await deployed(args.WATCHER_ID, hre.network.name, watcher.address);
  await deployed(args.MINTPASS_ID, hre.network.name, mintPasses.address);
  await deployed(
    args.MINTPASS_HOLDER_ID,
    hre.network.name,
    mintPassesHolder.address
  );
  await deployed(args.SCION_ID, hre.network.name, scion.address);
  await deployed(args.STAKING_ID, hre.network.name, staking.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
