import { conflux } from "hardhat";

async function main() {
    // @ts-ignore
    const [account] = await conflux.getSigners();
    // @ts-ignore
    const Governance = await conflux.getContractFactory("Governance");
    let receipt = await Governance.constructor(3600 * 24 * 30).sendTransaction({
        from: account,
    }).executed();

    // set pool whitelist

    console.log("Governance deployed to:", receipt.contractCreated)
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
