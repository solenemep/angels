import hre from "hardhat";
import { args } from "../helpers/arguments";
import { assets } from "../helpers/assets";
import { Class, weightLimits } from "../helpers/classLimits";
import { toWei, wait } from "../helpers/utils";
import { deployed } from "../helpers/deployed";
import { getContract } from "../helpers/getContract";

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
  await getRegistry();

  await upgradeAssetsRegistry();
  await upgradeArchangel();
  await upgradeWatcher();
  await upgradeMintPasses();
  await upgradeMintPassesHolder();
  await upgradeScion();
  await upgradeStaking();

  //   await getAddresses();
  //   await setDependencies();
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

async function getRegistry() {
  registry = Registry.attach(
    await getContract(args.REGISTRY_ID, hre.network.name)
  );
}

async function upgradeAssetsRegistry() {
  const assetsRegistryImpl = await upgrades.deployImplementation(
    AssetsRegistry
  );
  console.log("AssetsRegistry impl address:", assetsRegistryImpl.address);
  await wait(30_000);

  await registry.upgradeContract(args.ASSETS_ID, assetsRegistryImpl.address);
  await wait(30_000);
}

async function upgradeArchangel() {
  const archangelImpl = await upgrades.deployImplementation(Archangel);
  console.log("Archangel impl address:", archangelImpl.address);
  await wait(30_000);

  await registry.upgradeContract(args.ARCHANGEL_ID, archangelImpl.address);
  await wait(30_000);
}

async function upgradeWatcher() {
  const watcherImpl = await upgrades.deployImplementation(Watcher);
  console.log("Watcher impl address:", watcherImpl.address);
  await wait(30_000);

  await registry.upgradeContract(args.WATCHER_ID, watcherImpl.address);
  await wait(30_000);
}

async function upgradeMintPasses() {
  const mintPassesImpl = await upgrades.deployImplementation(MintPasses);
  console.log("MintPasses impl address:", mintPassesImpl.address);
  await wait(30_000);

  await registry.upgradeContract(args.MINTPASS_ID, mintPassesImpl.address);
  await wait(30_000);
}

async function upgradeMintPassesHolder() {
  const mintPassesHolderImpl = await upgrades.deployImplementation(
    MintPassesHolder
  );
  console.log("MintPassesHolder impl address:", mintPassesHolderImpl.address);
  await wait(30_000);

  await registry.upgradeContract(
    args.MINTPASS_HOLDER_ID,
    mintPassesHolderImpl.address
  );
  await wait(30_000);
}

async function upgradeScion() {
  const scionImpl = await upgrades.deployImplementation(Scion);
  console.log("Scion impl address:", scionImpl.address);
  await wait(30_000);

  await registry.upgradeContract(args.SCION_ID, scionImpl.address);
  await wait(30_000);
}

async function upgradeStaking() {
  const stakingImpl = await upgrades.deployImplementation(Staking);
  console.log("Staking impl address:", stakingImpl.address);
  await wait(30_000);

  await registry.upgradeContract(args.STAKING_ID, stakingImpl.address);
  await wait(30_000);
}

async function getAddresses() {
  keter = Keter.attach(await getContract(args.KETER_ID, hre.network.name));
  soul = Soul.attach(await getContract(args.SOUL_ID, hre.network.name));
  assetsRegistry = AssetsRegistry.attach(
    await getContract(args.ASSETS_ID, hre.network.name)
  );
  archangel = Archangel.attach(
    await getContract(args.ARCHANGEL_ID, hre.network.name)
  );
  watcher = Watcher.attach(
    await getContract(args.WATCHER_ID, hre.network.name)
  );
  mintPasses = MintPasses.attach(
    await getContract(args.MINTPASS_ID, hre.network.name)
  );
  mintPassesHolder = MintPassesHolder.attach(
    await getContract(args.MINTPASS_HOLDER_ID, hre.network.name)
  );
  scion = Scion.attach(await getContract(args.SCION_ID, hre.network.name));
  staking = Staking.attach(
    await getContract(args.STAKING_ID, hre.network.name)
  );
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

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
