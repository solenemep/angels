const { readFile } = require("fs/promises");

const FILE_PATH = "./addresses.json";

exports.getContract = async (contractName, networkName) => {
  let jsonString = "";
  let obj = {};
  try {
    jsonString = await readFile(FILE_PATH, "utf-8");
    obj = JSON.parse(jsonString);
  } catch (e) {
    // If exists, do nothing
  }
  const contract = obj[contractName];
  const contractAddress = contract[networkName].address;
  return contractAddress;
};
