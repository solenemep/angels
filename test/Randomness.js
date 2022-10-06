const { expect } = require("chai");
const { increaseTime, restore, snapshot } = require("./helpers/utils");
const { init } = require("./helpers/init");

const getMedian = (arr) => {
  const mid = Math.floor(arr.length / 2),
    nums = [...arr].sort((a, b) => a - b);
  return arr.length % 2 !== 0 ? nums[mid] : (nums[mid - 1] + nums[mid]) / 2;
};

const getAverage = (arr) => {
  return arr.reduce((a, b) => a + b, 0) / arr.length;
};

const getStandardDeviation = (arr) => {
  const average = getAverage(arr);

  arr = arr.map((el) => {
    return (el - average) ** 2;
  });

  const total = arr.reduce((a, b) => a + b, 0);

  return Math.sqrt(total / arr.length);
};

describe("Randomness", async () => {
  let randomGenerator;
  let user1;

  beforeEach("setup", async () => {
    const setups = await init();
    owner = setups.users[0];
    user1 = setups.users[1];

    randomGenerator = setups.randomGenerator;

    await snapshot();
  });

  afterEach("revert", async () => {
    await restore();
  });

  describe("test randomness", async () => {
    const sample = 30000; // number of iteration
    const range = 1000; // generation in range 0 to 1000

    let frequency = Array(range).fill(0);
    let probability = Array(range).fill(0);

    // example :
    // 30000 random number generated
    // each random number is between range of 0 and 1000
    // in perfect uniform distribution :
    // the frequency X is generated is 30000 / 1000 = 30
    // so the probability X is generated is 30 / 1000 = 0.03
    // here we include a margin of error :
    // probability is 30 +/- margin

    it("shows acceptable median, average and standard deviation", async () => {
      const margin = 12; // margin of error

      for (let i = 0; i < sample; i++) {
        const random = await randomGenerator.random(user1.address, range, i);
        frequency[random.toNumber()] = frequency[random.toNumber()] + 1;

        await increaseTime(60 * 60);
      }

      const median = getMedian(frequency);
      expect(median).to.equal(sample / range);
      const average = getAverage(frequency);
      expect(average).to.equal(sample / range);
      const standardDeviation = getStandardDeviation(frequency);
      expect(standardDeviation).to.be.closeTo(
        sample / range / Math.sqrt(12), // standard deviation in perfect unifom distribution
        (sample / range + margin) / Math.sqrt(12) -
          sample / range / Math.sqrt(12)
      );
    });

    it("distribute random number in a range of values with acceptable margin of error", async () => {
      const margin = 20; // margin of error

      for (let i = 0; i < sample; i++) {
        const random = await randomGenerator.random(user1.address, range, i);
        frequency[random.toNumber()] = frequency[random.toNumber()] + 1;

        await increaseTime(60 * 60);
      }

      for (let j = 0; j < range; j++) {
        probability[j] = frequency[j] / range;

        expect(frequency[j]).to.be.closeTo(sample / range, margin);
        expect(probability[j]).to.be.closeTo(
          sample / range ** 2, // probability in perfect uniform distribution
          (sample / range + margin) / range - sample / range ** 2
        );
      }
      console.log(probability);
    });
  });
});
