// This is a script for deploying your contracts. You can adapt it to deploy
// yours, or create new ones.
import hre from "hardhat";
import { ContractTransaction } from "ethers";
import args from "./arguments";
import { toWei } from "../test/helpers/utils";
const verify = require("../scripts/verify");
const wait = async (ms: number) =>
  new Promise((resolve) => setTimeout(resolve, ms));

const Class = {
  NONE: 0,
  BRONZE: 1,
  SILVER: 2,
  GOLD: 3,
  PLATINUM: 4,
  RUBY: 5,
  ONYX: 6,
};

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

  const MintPasses = await hre.ethers.getContractFactory("MintPasses", {
    libraries: {
      RandomGenerator: "0x8682C14C778520e0c2D5c90d29467a32C0C0781e",
    },
  });

  const mintPasses = await MintPasses.deploy(
    args.MINT_PASS_NAME,
    args.MINT_PASS_SYMBOL,
    args.MINT_PASS_BASE_TOKEN_URI,
    args.MINT_PASS_TOTAL_BIDS_LIMIT,
    args.MINT_PASS_MINIMUM_BID_AMOUNT,
    args.MINT_PASS_AUCTION_DURATION
  );
  await mintPasses.deployed();
  console.log("MintPasses address:", mintPasses.address);

  const MintPassesHolder = await hre.ethers.getContractFactory(
    "MintPassesHolder"
  );
  const mintPassesHolder = await MintPassesHolder.deploy(mintPasses.address);
  await mintPassesHolder.deployed();

  console.log("MintPassesHolder address:", mintPassesHolder.address);

  await wait(30_000);

  const Soul = await hre.ethers.getContractFactory("Soul");
  const soul = await Soul.deploy(args.SOUL_NAME, args.SOUL_SYMBOL);
  console.log("Soul address:", soul.address);

  await wait(30_000);

  const Keter = await hre.ethers.getContractFactory("Keter");
  const keter = await Keter.deploy();
  console.log("Keter address:", keter.address);

  await wait(30_000);

  /***********************   ASSETS *******************************************/

  const AssetRegistry = await hre.ethers.getContractFactory("AssetsRegistry");
  const assetRegistry = await AssetRegistry.deploy();

  console.log("AssetRegistry address:", assetRegistry.address);

  await wait(30_000);

  let tx = await assetRegistry.setAssets(
    0,
    ["BGND001", "BGND002", "BGND005", "BGND004", "BGND006", "BGND003"],
    [1000, 250, 250, 100, 100, 10],
    [
      "Cumulus Sky",
      "Dusk Sky",
      "Static Sky",
      "Empire Sky",
      "Dire Sky",
      "Expanse Sky",
    ]
  );

  await tx.wait();

  tx = await assetRegistry.setAssets(
    1,
    [
      "HALO002",
      "HALO003",
      "HALO004",
      "HALO009",
      "HALO011",
      "HALO013",
      "HALO015",
      "HALO017",
      "HALO005",
      "HALO007",
      "HALO008",
      "HALO014",
      "HALO016",
      "HALO001",
      "HALO006",
      "HALO018",
      "HALO010",
      "HALO012",
      "HALO019",
      "HALO020",
    ],
    [
      1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 250, 250, 250, 250, 250,
      100, 100, 100, 10, 10, 10, 10,
    ],
    [
      "Graceful Ring",
      "Gold Ring",
      "Diamond Window",
      "Esoteric Astrolab",
      "Ascending Triangle",
      "Glorious Halo",
      "Nested Containment",
      "Double Helix",
      "Verdant Laurel",
      "Ring of Fire",
      "Fierce Nail",
      "Void Arc",
      "Pride of the Stag",
      "Fiery Arc",
      "Angular Wreith",
      "Waxing Arc",
      "Celebratory Crown",
      "Decending Wedge",
      "Cube of Metatron",
      "Shattered Pride",
    ]
  );

  await tx.wait();

  tx = await assetRegistry.setAssets(
    2,
    [
      "HEAD001",
      "HEAD002",
      "HEAD003",
      "HEAD003b",
      "HEAD005",
      "HEAD012",
      "HEAD014",
      "HEAD015",
      "HEAD016",
      "HEAD017",
      "HEAD026",
      "HEAD034",
      "HEAD038",
      "HEAD040",
      "HEAD004",
      "HEAD007",
      "HEAD008",
      "HEAD010",
      "HEAD011",
      "HEAD013",
      "HEAD018",
      "HEAD021",
      "HEAD022",
      "HEAD025",
      "HEAD027",
      "HEAD029",
      "HEAD030",
      "HEAD032",
      "HEAD035",
      "HEAD036",
      "HEAD039",
      "HEAD006",
      "HEAD019",
      "HEAD020",
      "HEAD028",
      "HEAD028b",
      "HEAD037",
      "HEAD009",
      "HEAD023",
      "HEAD024",
      "HEAD031",
      "HEAD033",
    ],
    [
      1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000,
      1000, 1000, 250, 250, 250, 250, 250, 250, 250, 250, 250, 250, 250, 250,
      250, 250, 250, 250, 250, 100, 100, 100, 100, 100, 100, 10, 10, 10, 10, 10,
    ],
    [
      "Holy Head",
      "Graded Head",
      "Lunar Head",
      "Sterling Lunar Head",
      "Truthful Head",
      "Hardened Head",
      "Watchful Head",
      "Blazing Head",
      "Proud Head",
      "Manic Head",
      "Venerable Head",
      "Segemented Head",
      "Ignited Head",
      "Hooded Head",
      "Traced Head",
      "Pinched Head",
      "Labarynthine Head",
      "Fateful Head",
      "Crowned Head",
      "Deep Head",
      "Fanciful Head",
      "Balanced Head",
      "Protective Head",
      "Nested Head",
      "Ringed Head",
      "Vigilant Head",
      "Shrouded Head",
      "Frilled Head",
      "Bullish Head",
      "Criminal Head",
      "Decentralized Head",
      "Ascended Head",
      "Fruiting Head",
      "Dreaming Head",
      "Succulant Head",
      "Ruby Succulant Head",
      "Horned Head",
      "Radiant Head",
      "Verdant Head",
      "Metamorphed Head",
      "Winged Head",
      "Praised Head",
    ]
  );

  await tx.wait();

  tx = await assetRegistry.setAssets(
    3,
    [
      "BODY001",
      "BODY004",
      "BODY005c",
      "BODY007b",
      "BODY009",
      "BODY010",
      "BODY012",
      "BODY015",
      "BODY002",
      "BODY003",
      "BODY005",
      "BODY005b",
      "BODY007",
      "BODY008",
      "BODY010b",
      "BODY011",
      "BODY013",
      "BODY013b",
      "BODY017",
      "BODY018",
      "BODY020",
      "BODY003b",
      "BODY003c",
      "BODY006",
      "BODY007c",
      "BODY010c",
      "BODY013c",
      "BODY014",
      "BODY016",
      "BODY019",
    ],
    [
      1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 250, 250, 250, 250, 250,
      250, 250, 250, 250, 250, 250, 250, 250, 100, 100, 100, 100, 100, 100, 100,
      100, 100,
    ],
    [
      "Shrouded Body",
      "Proud Body",
      "Truthful Body",
      "Platinum Cunning Body",
      "Hardened Body",
      "Layered Body",
      "Astrologic Body",
      "Secretive Body",
      "Hunted Body",
      "Holy Body",
      "Gold Truthful Body",
      "Onyx Truthful Body",
      "Cunning Body",
      "Fanciful Body",
      "Turquoise Layered Body",
      "Arcane Body",
      "Honorable Body",
      "Turquoise Honorable Body",
      "Accumulated Body",
      "Protective Body",
      "Slashed Body",
      "Onyx Holy Body",
      "Ruby Holy Body",
      "Erudite Body",
      "Onyx Cunning Body",
      "Sapphire Layered Body",
      "Ruby Honorable Body",
      "Venerable Body",
      "Dripping Body",
      "Quiet Body",
    ]
  );

  await tx.wait();

  tx = await assetRegistry.setAssets(
    4,
    [
      "WING000",
      "WING001",
      "WING002",
      "WING003",
      "WING004",
      "WING005",
      "WING006",
      "WING007",
      "WING008",
      "WING009",
      "WING010",
      "WING011",
    ],
    [1000, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10],
    [
      "No Wings",
      "Night Wings",
      "Verdant Wings",
      "Flowing Wings",
      "Falling Wings",
      "Dark Falling Wings",
      "Ultra Sound Wings",
      "Void Tendrals",
      "Streaming Wings",
      "Geometric Extrusions",
      "Chitinous Appendages",
      "Gothic Wings",
    ]
  );

  await tx.wait();

  tx = await assetRegistry.setAssets(
    5,
    [
      "HAND000",
      "HAND001",
      "HAND003",
      "HAND004",
      "HAND006",
      "HAND007",
      "HAND012",
      "HAND013",
      "HAND017",
      "HAND018",
      "HAND002",
      "HAND005",
      "HAND008",
      "HAND009",
      "HAND010",
      "HAND011",
      "HAND014",
      "HAND015",
      "HAND016",
    ],
    [
      1000, 100, 100, 100, 100, 100, 100, 100, 100, 100, 10, 10, 10, 10, 10, 10,
      10, 10, 10,
    ],
    [
      "No Hand",
      "Blessing Hand",
      "Key Bearer",
      "Scepter Bearer",
      "Grasping Hand",
      "Judging Hand",
      "Coin Bearer",
      "Card Bearer",
      "Orb Bearer",
      "Flame Bearer",
      "Sword Bearer",
      "Book Bearer",
      "Gift of Mortality",
      "Nectar Bearer",
      "Spear Bearer",
      "Staff Bearer",
      "Hammer Bearer",
      "Hook Bearer",
      "Broken Bearer",
    ]
  );

  await tx.wait();

  tx = await assetRegistry.setAssets(
    6,
    [
      "SIGL000",
      "SIGL006",
      "SIGL007",
      "SIGL008",
      "SIGL009",
      "SIGL012",
      "SIGL001",
      "SIGL002",
      "SIGL003",
      "SIGL004",
      "SIGL005",
      "SIGL010",
      "SIGL011",
    ],
    [1000, 100, 100, 100, 100, 100, 10, 10, 10, 10, 10, 10, 10],
    [
      "No Sigil",
      "Sign of Eternity",
      "Sign of Magik",
      "Sign of the Moon",
      "Sign of Life",
      "Sign of the Void",
      "Sign of Flame",
      "Sign of the Seraphim",
      "Sign of the Watchers",
      "Sign of Vision",
      "Sign of the Tree",
      "Sign of the Crown",
      "Sign of Ether",
    ]
  );

  await tx.wait();

  /***********************   SCIONS *******************************************/

  const Scion = await hre.ethers.getContractFactory("Scion", {
    libraries: {
      RandomGenerator: "0x8682C14C778520e0c2D5c90d29467a32C0C0781e",
    },
  });

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

  console.log("Scion address:", scion.address);

  (await mintPasses.setScionAddress(scion.address)).wait();
  (await soul.setScionAddress(scion.address)).wait();

  await wait(30_000);

  const Archangel = await hre.ethers.getContractFactory("Archangel");
  const archangel = await Archangel.deploy(
    soul.address,
    "https://backend.devangelproject.com/api/archangels/metadata/"
  );

  console.log("Archangel address:", archangel.address);

  const Watcher = await hre.ethers.getContractFactory("Watcher");
  const watcher = await Watcher.deploy(
    soul.address,
    "https://backend.devangelproject.com/api/watchers/metadata/"
  );

  console.log("Watcher address:", watcher.address);

  tx = await watcher.triggerBatchSale(toWei("444"));

  await tx.wait();

  const Staking = await hre.ethers.getContractFactory("Staking");
  const staking = await Staking.deploy(keter.address, scion.address);

  console.log("Staking address:", staking.address);

  tx = await mintPasses.setClassesWeightLimits(
    [
      Class.BRONZE,
      Class.SILVER,
      Class.GOLD,
      Class.PLATINUM,
      Class.RUBY,
      Class.ONYX,
    ],
    [15, 10, 5, 1, 0, 0],
    [2500, 2500, 2000, 1500, 1000, 800]
  );

  await tx.wait();

  console.log("Waiting 20 seconds before calling verify script...");
  await wait(20_000);

  let verifyScript = verify.buildVerifyScript(
    "MintPasses",
    mintPasses.address,
    hre.network.name,
    `${args.MINT_PASS_NAME} ${args.MINT_PASS_SYMBOL} ${args.MINT_PASS_BASE_TOKEN_URI} ${args.MINT_PASS_TOTAL_BIDS_LIMIT} ${args.MINT_PASS_MINIMUM_BID_AMOUNT} ${args.MINT_PASS_AUCTION_DURATION}`,
    true,
    "scripts/libraries.ts"
  );
  verify.logVerifyScript(verifyScript);
  await verify.verifyContract(verifyScript, 2);

  console.log("MintPasses verified");

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
    "AssetsRegistry",
    assetRegistry.address,
    hre.network.name,
    ``,
    false,
    ""
  );
  verify.logVerifyScript(verifyScript);
  await verify.verifyContract(verifyScript, 2);

  console.log("AssetsRegistry verified");

  verifyScript = verify.buildVerifyScript(
    "Scion",
    scion.address,
    hre.network.name,
    `${mintPasses.address} ${soul.address} ${keter.address} ${assetRegistry.address} ${args.SCION_NAME} ${args.SCION_SYMBOL} ${args.SCION_BASE_TOKEN_URI} ${args.DOWNGRADE} ${args.SAME_WEIGHT} ${args.RARITY_PLUS}`,
    true,
    "scripts/libraries.ts"
  );
  verify.logVerifyScript(verifyScript);
  await verify.verifyContract(verifyScript, 2);

  console.log("Scion verified");

  verifyScript = verify.buildVerifyScript(
    "Archangel",
    archangel.address,
    hre.network.name,
    `${soul.address} https://backend.devangelproject.com/api/archangels/metadata/`,
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
    `${soul.address} https://backend.devangelproject.com/api/watchers/metadata/`,
    false,
    ""
  );
  verify.logVerifyScript(verifyScript);
  await verify.verifyContract(verifyScript, 2);

  console.log("Archangel verified");

  verifyScript = verify.buildVerifyScript(
    "Staking",
    staking.address,
    hre.network.name,
    `${keter.address} ${scion.address}`,
    false,
    ""
  );
  verify.logVerifyScript(verifyScript);
  await verify.verifyContract(verifyScript, 2);

  console.log("Staking verified");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
