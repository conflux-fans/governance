import { conflux } from "hardhat";

async function main() {
    // @ts-ignore
    const [account] = await conflux.getSigners();
    // @ts-ignore
    const Governance = await conflux.getContractAt("Governance", process.env.GOVERNANCE);

    /* let submiter = 'cfxtest:aak6rc909w6nppbj36xnj4nt0yeux0zg3pt2b4wrxk';
    let receipt = await Governance.addSubmiter().sendTransaction({
        from: account,
    }).executed(); */

    let posPool = 'cfxtest:acgwa148z517jj15w9je5sdzn8p8j044kjrvjz92c1';
    let receipt = await Governance.setPoolWhitelist(posPool, true).sendTransaction({
        from: account,
    }).executed();

    console.log("add submiter to governance:", receipt.outcomeStatus);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
