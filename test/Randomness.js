const { expect } = require("chai");
const { increaseTime } = require("./helpers/utils");
const { init } = require("./helpers/init");

describe("Randomness", async () => {
  let randomGenerator;
  let user1;

  beforeEach("setup", async () => {
    const setups = await init();
    owner = setups.users[0];
    user1 = setups.users[1];

    randomGenerator = setups.randomGenerator;
  });

  describe("test randomness", async () => {
    const range = 1000; // generation in range 0 to 1000
    const sample = 30000; // number of iteration
    const margin = 2; // margin of error

    // example with sample = 10000
    // 30000 random number generated
    // each random number is between 0 and 30000
    // in perfect uniform distribution :
    // the frequency X is chosen is 30000 / 1000 = 30
    // so the probability X is chosen is 30 / 1000 = 0.03
    // here we include a margin of error :
    // frequency can variate between 30 - 3 = 27 and 30 + 3 = 33

    it("distribute random number in a range of values", async () => {
      let frequency = Array(range).fill(0);
      for (let i = 0; i < sample; i++) {
        const random = await randomGenerator.random(user1.address, range, i);
        frequency[random.toNumber()] = frequency[random.toNumber()] + 1;
        await increaseTime(60 * 60);
      }

      let probability = Array(range).fill(0);
      for (let j = 0; j < range; j++) {
        probability[j] = frequency[j] / range;

        expect(probability[j]).to.be.closeTo(
          sample / range ** 2,
          (sample / range + margin) / range
        );
      }
    });
  });
});
