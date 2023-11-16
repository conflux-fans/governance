import { ethers } from "hardhat";

async function main() {
    const [account] = await ethers.getSigners();
  
    const govImpl = await ethers.deployContract("EGovernance");
    await govImpl.waitForDeployment();

    console.log(
        `govImpl deploy to ${govImpl.target}`
    );

    const proxy = await ethers.deployContract("Proxy1967", [govImpl.target, '0x8129fc1c']);
    await proxy.waitForDeployment();

    console.log(`EGovernance deploy to ${proxy.target}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
