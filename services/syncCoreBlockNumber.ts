import { conflux } from "hardhat";

async function main() {
    // @ts-ignore
    const [account] = await conflux.getSigners();
    // @ts-ignore
    const governance = await conflux.getContractAt("Governance", process.env.GOVERNANCE as string);

    setInterval(async () => {
        let receipt = await governance.updateEspaceCoreBlockNumber().sendTransaction({
            from: account,
        }).executed();
    }, 1000 * 60 * 5); // five minutes
    
    console.log('Finished');
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
