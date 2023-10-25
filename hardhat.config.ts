import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "hardhat-conflux";
import * as dotenv from "dotenv";
dotenv.config();

// @ts-ignore
task("setWhitelist", "Set pool whitelist")
    .addParam("pool", "The pool's address")
    .addParam("white", "Is one pool whitelisted")
    .setAction(async (args: {pool: string, white: boolean}, hre: any) => {
        const contract = await hre.conflux.getContractAt("Governance", process.env.GOVERNANCE as string);
        const { pool, white } = args;
        const [account] = await hre.conflux.getSigners();
        const receipt = await contract.setPoolWhitelist(pool, white).sendTransaction({
            from: account.address,
        }).executed();
        console.log(`Set ${pool} to ${white} tx hash: ${receipt.transactionHash}`);
    });

const config: HardhatUserConfig = {
    solidity: "0.8.19",
    networks: {
        cfx: {
            url: "https://main.confluxrpc.com",
            accounts: [process.env.PRIVATE_KEY as string],
            chainId: 1029,
        },
        cfx_testnet: {
            url: "https://test.confluxrpc.com",
            accounts: [process.env.PRIVATE_KEY as string],
            chainId: 1,
        },
        net8888: {
            url: "http://net8888cfx.confluxrpc.com",
            accounts: [process.env.PRIVATE_KEY as string],
            chainId: 8888,
        }
    }
};

export default config;
