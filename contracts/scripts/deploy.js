const hre = require("hardhat");

async function main() {
  // Deploy TEST token first (if not already deployed)
  const TestToken = await hre.ethers.getContractFactory("TestToken");
  const testToken = await TestToken.deploy("TEST Token", "TEST", ethers.parseEther("1000000")); // 1M tokens
  await testToken.waitForDeployment();
  console.log("TestToken deployed to:", await testToken.getAddress());

  // Deploy DeepfakeDetection contract
  const DeepfakeDetection = await hre.ethers.getContractFactory("DeepfakeDetection");
  const deepfakeDetection = await DeepfakeDetection.deploy(await testToken.getAddress());
  await deepfakeDetection.waitForDeployment();
  console.log("DeepfakeDetection deployed to:", await deepfakeDetection.getAddress());

  // Verify contracts on Etherscan
  if (process.env.ETHERSCAN_API_KEY) {
    console.log("Waiting for block confirmations...");
    await deepfakeDetection.deployTransaction.wait(6);
    await testToken.deployTransaction.wait(6);

    await hre.run("verify:verify", {
      address: await testToken.getAddress(),
      constructorArguments: ["TEST Token", "TEST", ethers.parseEther("1000000")],
    });

    await hre.run("verify:verify", {
      address: await deepfakeDetection.getAddress(),
      constructorArguments: [await testToken.getAddress()],
    });
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  }); 