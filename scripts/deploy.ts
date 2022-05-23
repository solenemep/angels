// This is a script for deploying your contracts. You can adapt it to deploy
// yours, or create new ones.
import hre from "hardhat";
import args from "./arguments";
const verify = require("../scripts/verify");
const wait = async (ms: number) => new Promise(resolve => setTimeout(resolve, ms));

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

  const MintPasses = await hre.ethers.getContractFactory("MintPasses");
  const mintPasses = await MintPasses.deploy(args.MINT_PASS_NAME, args.MINT_PASS_SYMBOL, args.MINT_PASS_BASE_TOKEN_URI, args.MINT_PASS_TOTAL_BIDS_LIMIT, args.MINT_PASS_MINIMUM_BID_AMOUNT, args.MINT_PASS_START, args.MINT_PASS_AUCTION_DURATION, args.SUBSCRIPTION_ID, args.VRF_COORDINATOR_ADDRESS, args.LINK_TOKEN_ADDRESS, args.VRF_KEY_HASH);
  await mintPasses.deployed();
  console.log("MintPasses address:", mintPasses.address);

  const Soul = await hre.ethers.getContractFactory("Soul");
  const soul = await Soul.deploy(args.SOUL_NAME, args.SOUL_SYMBOL);
  console.log("Soul address:", soul.address);

  const Keter = await hre.ethers.getContractFactory("Keter");
  const keter = await Keter.deploy();
  console.log("Keter address:", keter.address);

  const Scion = await hre.ethers.getContractFactory("Scion");
  const scion = await Scion.deploy(args.SUBSCRIPTION_ID, args.VRF_COORDINATOR_ADDRESS, args.LINK_TOKEN_ADDRESS, args.VRF_KEY_HASH, mintPasses.address, soul.address, keter.address, args.SCION_NAME, args.SCION_SYMBOL)
  
  console.log("Scion address:", scion.address);
  
  (await mintPasses.setScionAddress(scion.address)).wait();
  (await soul.transfer(scion.address, "1000000000000000000000000000")).wait();

  const Archangel = await hre.ethers.getContractFactory("Archangel");
  const archangel = await Archangel.deploy(soul.address);

  console.log("Archangel address:", archangel.address);

  // const chainlink = await Soul.attach("0x01BE23585060835E02B77ef475b0Cc51aA1e0709");
  // await chainlink.transfer(scion.address, "2000000000000000000");

  console.log('Waiting 20 seconds before calling verify script...')
  await wait(20_000);

  let verifyScript = verify.buildVerifyScript('MintPasses', mintPasses.address, hre.network.name, `${args.MINT_PASS_NAME} ${args.MINT_PASS_SYMBOL} ${args.MINT_PASS_BASE_TOKEN_URI} ${args.MINT_PASS_TOTAL_BIDS_LIMIT} ${args.MINT_PASS_MINIMUM_BID_AMOUNT} ${args.MINT_PASS_START} ${args.MINT_PASS_AUCTION_DURATION} ${args.SUBSCRIPTION_ID} ${args.VRF_COORDINATOR_ADDRESS} ${args.LINK_TOKEN_ADDRESS} ${args.VRF_KEY_HASH}`);
  verify.logVerifyScript(verifyScript);
  await verify.verifyContract(verifyScript, 2);

  console.log("MintPasses verified");

  verifyScript = verify.buildVerifyScript('Soul', soul.address, hre.network.name, `${args.SOUL_NAME} ${args.SOUL_SYMBOL}`);
  verify.logVerifyScript(verifyScript);
  await verify.verifyContract(verifyScript, 2);

  console.log("Soul verified");

  verifyScript = verify.buildVerifyScript('Keter', keter.address, hre.network.name, ``);
  verify.logVerifyScript(verifyScript);
  await verify.verifyContract(verifyScript, 2);

  console.log("Keter verified");

  verifyScript = verify.buildVerifyScript('Scion', keter.address, hre.network.name, `${args.SUBSCRIPTION_ID} ${args.VRF_COORDINATOR_ADDRESS} ${args.LINK_TOKEN_ADDRESS} ${args.VRF_KEY_HASH} ${mintPasses.address} ${soul.address} ${keter.address} ${args.SCION_NAME} ${args.SCION_SYMBOL}`);
  verify.logVerifyScript(verifyScript);
  await verify.verifyContract(verifyScript, 2);

  console.log("Scion verified");

  verifyScript = verify.buildVerifyScript('Archangel', keter.address, hre.network.name, `${soul.address}`);
  verify.logVerifyScript(verifyScript);
  await verify.verifyContract(verifyScript, 2);

  console.log("Archangel verified");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
