import { conflux } from "hardhat";

async function main() {
    // @ts-ignore
    const [account] = await conflux.getSigners();
    // @ts-ignore
    const Governance = await conflux.getContractFactory("Governance");
    let receipt = await Governance.constructor(3600).sendTransaction({
        from: account,
    }).executed();

    const governanceAddr = receipt.contractCreated;

    // @ts-ignore
    const Proxy = await conflux.getContractFactory("Proxy1967");
    receipt = await Proxy.constructor(governanceAddr, '0x8129fc1c').sendTransaction({
        from: account,
    }).executed();

    const proxyAddr = receipt.contractCreated;

    console.log("Governance deployed to:", proxyAddr)

    // @ts-ignore
    const governance = await conflux.getContractAt("Governance", proxyAddr);
    
    // one hour
    receipt = await governance.setExtendDelay(3600).sendTransaction({
        from: account,
    }).executed();

    receipt = await governance.setMinVoteRatio(1_000_000_0 * 5).sendTransaction({
        from: account,
    }).executed();

    console.log('Finished');
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
