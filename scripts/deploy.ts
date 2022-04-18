// This is a script for deploying your contracts. You can adapt it to deploy
// yours, or create new ones.
import hre from "hardhat";

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
  const mintPasses = await MintPasses.deploy("MintPass", "MP", "test", 9500, "10", "0", "2000", 100, "0x6168499c0cFfCaCD319c818142124B7A15E857ab", "0x01BE23585060835E02B77ef475b0Cc51aA1e0709", "0xd89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc");
  await mintPasses.deployed();
  console.log("MintPasses address:", mintPasses.address);

  const Soul = await hre.ethers.getContractFactory("Soul");
  const soul = await Soul.deploy();
  console.log("Soul address:", soul.address);

  const Keter = await hre.ethers.getContractFactory("Keter");
  const keter = await Keter.deploy();
  console.log("Keter address:", keter.address);

  const Scion = await hre.ethers.getContractFactory("Scion");
  const scion = await Scion.deploy(2054, "0x6168499c0cFfCaCD319c818142124B7A15E857ab", "0x01BE23585060835E02B77ef475b0Cc51aA1e0709", "0xd89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc", mintPasses.address, soul.address, keter.address)
  
  console.log("Scion address:", scion.address);
  
  (await mintPasses.setScionAddress(scion.address)).wait();
  (await soul.transfer(scion.address, "1000000000000000000000000000")).wait();

  // const chainlink = await Soul.attach("0x01BE23585060835E02B77ef475b0Cc51aA1e0709");
  // await chainlink.transfer(scion.address, "2000000000000000000");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
