import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "hardhat-conflux";
import { address as cfxAddress } from 'js-conflux-sdk';
import * as dotenv from "dotenv";
dotenv.config();

// @ts-ignore
task("setWhitelist", "Set pool whitelist")
    .addParam("pool", "The pool's address")
    .addParam("white", "Is one pool whitelisted")
    .setAction(async (args: {pool: string, white: string}, hre: any) => {
        const contract = await hre.conflux.getContractAt("Governance", process.env.GOVERNANCE as string);
        const { pool, white } = args;
        const [account] = await hre.conflux.getSigners();
        const receipt = await contract.setPoolWhitelist(pool, white === 'true').sendTransaction({
            from: account.address,
        }).executed();
        console.log(`Set ${pool} to ${white} tx hash: ${receipt.transactionHash}`);
    });

// @ts-ignore
task("setEgovWhitelist", "Set pool whitelist")
    .addParam("pool", "The pool's address")
    .addParam("white", "Is one pool whitelisted")
    .setAction(async (args: {pool: string, white: string}, hre: any) => {
        const contract = await hre.ethers.getContractAt("Governance", process.env.EGOVERNANCE as string);
        const { pool, white } = args;
        const tx = await contract.setPoolWhitelist(pool, white === 'true');
        await tx.wait();
        console.log(`Set ${pool} to ${white} tx hash: ${tx.hash}`);
    });

// @ts-ignore
task("addSubmitter", "add submitter")
    .addParam("submitter", "The account's address")
    .setAction(async (args: {submitter: string}, hre: any) => {
        const contract = await hre.conflux.getContractAt("Governance", process.env.GOVERNANCE as string);
        const { submitter } = args;
        const [account] = await hre.conflux.getSigners();
        const receipt = await contract.addSubmiter(submitter).sendTransaction({
            from: account.address,
        }).executed();
        console.log(`Add one submitter ${submitter} tx hash: ${receipt.transactionHash}`);
    });

// @ts-ignore
task("setEspaceGov", "set espace governance address")
    .setAction(async (args: {address: string}, hre: any) => {
        const contract = await hre.conflux.getContractAt("Governance", process.env.GOVERNANCE as string);
        const [account] = await hre.conflux.getSigners();
        let nonce = await hre.conflux.getNextNonce(account.address);
        const receipt = await contract.setEspaceGovernance(process.env.EGOVERNANCE).sendTransaction({
            from: account.address,
            nonce,
        }).executed();
        console.log(`setEspaceGovernance ${process.env.EGOVERNANCE} tx hash: ${receipt.transactionHash}`);
    });

// @ts-ignore
task("setCoreBridge", "set core bridge in espace governance")
    .addParam("address", "The account's address")
    .setAction(async (args: {address: string}, hre: any) => {
        const contract = await hre.ethers.getContractAt("EGovernance", process.env.EGOVERNANCE as string);
        const { address } = args;
        const tx = await contract.setCoreGovernanceBridge(cfxAddress.cfxMappedEVMSpaceAddress(address));
        await tx.wait();
        console.log(`setCoreBridge ${address} tx hash: ${tx.hash}`);
    });

// @ts-ignore
task("upgradeEgov", "Upgrade espace governance contract")
    .setAction(async (args: {}, hre: any) => {
        const contract = await hre.ethers.deployContract("EGovernance");
        await contract.waitForDeployment();
        const proxy = await hre.ethers.getContractAt("Proxy1967", process.env.EGOVERNANCE as string);
        const tx = await proxy.upgradeTo(contract.target);
        await tx.wait();
        console.log(`Upgrade to ${contract.target} success`);
    });

// @ts-ignore
task("upgradeGov", "Upgrade governance contract")
    .setAction(async (args: {}, hre: any) => {
        const [deployer] = await hre.conflux.getSigners();

        let nonce = await hre.conflux.getNextNonce(deployer.address);
        const Governance = await hre.conflux.getContractFactory("Governance");
        const deployReceipt = await Governance.constructor(3600).sendTransaction({
            from: deployer.address,
            nonce,
        }).executed();
        const implAddr = deployReceipt.contractCreated;

        nonce = await hre.conflux.getNextNonce(deployer.address);
        const contract = await hre.conflux.getContractAt("Proxy1967", process.env.GOVERNANCE as string);
        const receipt = await contract.upgradeTo(implAddr).sendTransaction({
            from: deployer.address,
            nonce,
        }).executed();
        console.log(`Upgrade to ${implAddr} ${receipt.outcomeStatus === 0 ? 'success' : 'failed'}`);
    });



const config: HardhatUserConfig = {
    solidity: "0.8.19",
    defaultNetwork: "ecfx_dev",
    networks: {
        cfx: {
            url: "https://main.confluxrpc.com",
            accounts: [process.env.PRIVATE_KEY as string],
            chainId: 1029,
        },
        cfx_dev: {
            url: "https://test.confluxrpc.com",
            accounts: [process.env.PRIVATE_KEY as string],
            chainId: 1,
        },
        ecfx: {
            url: "https://evm.confluxrpc.com",
            accounts: [process.env.PRIVATE_KEY as string],
            chainId: 1030,
        },
        ecfx_dev: {
            url: "https://evmtestnet.confluxrpc.com",
            accounts: [process.env.PRIVATE_KEY as string],
            chainId: 71,
        },
        net8888: {
            url: "http://net8888cfx.confluxrpc.com",
            accounts: [process.env.PRIVATE_KEY as string],
            chainId: 8888,
        },
        net8889: {
            url: "http://net8889eth.confluxrpc.com",
            accounts: [process.env.PRIVATE_KEY as string],
            chainId: 8889,
        }
    }
};

export default config;
