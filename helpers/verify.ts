const { exec } = require("child_process");

module.exports.buildVerifyScript = function (
  name: string,
  address: string,
  network: string,
  args: string,
  withL: boolean,
  libraryPath: string,
) {
  if(withL) {
    return { 
      script: `npx hardhat verify --contract contracts/${name}.sol:${name} ${address} ${args} --libraries ${libraryPath} --network ${network}`,
      name,
    }
  } else {
  return { 
    script: `npx hardhat verify --contract contracts/${name}.sol:${name} ${address} ${args} --network ${network}`,
    name,
  } }
};

module.exports.logVerifyScript = function (instance: {
  name: string;
  script: string;
}) {
  console.log(`VERIFY SCRIPT(${instance.name}): ${instance.script}`);
};

module.exports.verifyContract = function (
  instance: { name: string; script: string },
  attempts: number
) {
  console.log(`Verifying Contract: ${instance.name}`);

  return new Promise<void>((resolve) => {
    function go(attempt: number) {
      if (attempt > attempts) {
        console.log(
          `Verify script (${instance.name}) failed after ${attempts} attempts: ${instance.script}`
        );
        return resolve();
      }

      exec(instance.script, (error: string, stdout: string, stderr: string) => {
        if (error) {
          console.log(`Attempt ${attempt} failed.  Retrying...`);
          console.log(error);
          console.log(stderr);

          // Recursively try again
          return go(attempt + 1);
        }

        // Verification successful
        console.log(stdout);
        console.log(`Verifying Contract: ${instance.name} - SUCCESS`);
        resolve();
      });
    }

    // Kick off the first try
    go(1);
  });
};
