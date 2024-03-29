import { conflux } from "hardhat";

async function main() {
    // @ts-ignore
    const [account] = await conflux.getSigners();
    // @ts-ignore
    const governance = await conflux.getContractAt("Governance", process.env.GOVERNANCE as string);

    setInterval(async () => {
        try {
            let receipt = await governance.updateEspaceCoreChainInfo().sendTransaction({
                from: account,
            }).executed();
            console.log(`Update Espace Core Chain Info: ${receipt.outcomeStatus === 0 ? 'Success' : 'Failed'}`)
        } catch (error) {
            console.log(error);
        }
    }, 1000 * 60 * 1); // one minutes
    
    console.log('Service Started');
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
