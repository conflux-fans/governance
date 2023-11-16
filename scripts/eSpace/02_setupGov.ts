import { ethers } from 'hardhat';
import { address } from 'js-conflux-sdk';

async function main() {
    const gov = await ethers.getContractAt("EGovernance", process.env.EGOVERNANCE as string);

    const tx = await gov.setCoreGovernanceBridge(address.cfxMappedEVMSpaceAddress(process.env.GOVERNANCE as string));
    await tx.wait();

    console.log('Set core governance bridge finished');
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});