import { expect } from "chai";
import { ethers } from "hardhat";
import * as hreHelper from "@nomicfoundation/hardhat-toolbox/network-helpers";
const { loadFixture, time } = hreHelper;

const ONE_GWEI = 1_000_000_000n;
const ONE_ETH = 1_000_000_000_000_000_000n;
const ONE_YEAR_IN_SECS = 365 * 24 * 60 * 60;
const MOCK_ADDR = "0x0888000000000000000000000000000000000002";
const TEST_ADDR = '0x0888000000000000000000000000000000000011';

describe("Governance", function () {
    async function deployGovernanceFixture() {
        const [owner, otherAccount] = await ethers.getSigners();

        const Governance = await ethers.getContractFactory("Governance");
        const governance = await Governance.deploy(ONE_YEAR_IN_SECS);
        
        const Mocks = await ethers.getContractFactory("Mocks");
        // deploy and get bytecode
        const mock1 = await Mocks.deploy();
        const code = await mock1.getDeployedCode();
        
        // set bytecode
        await hreHelper.setCode(MOCK_ADDR, code as string);
        // get contract
        const mock = await ethers.getContractAt("Mocks", MOCK_ADDR);

        // set mock whitelist
        await governance.setPoolWhitelist(MOCK_ADDR, true);

        // submit proposal
        const title = "Proposal 1";
        const description = "Proposal 1 description";
        const deadline = (await time.latest()) + ONE_YEAR_IN_SECS;
        const options = ['O1', 'O2'];
        const proposer = TEST_ADDR;
        await governance.submitProposalByWhitelist(title, description, deadline, options, proposer);

        return { governance, owner, otherAccount, mock };
    }

    describe('Mocks should work', async () => {
        it('Method userVotePower return 1', async () => {
            const { mock } = await loadFixture(deployGovernanceFixture);
            expect(await mock.userVotePower(TEST_ADDR)).to.equal(1000n * ONE_ETH);
        });
    });

    describe("Submit Proposal", function () {
        it('Should submit proposal', async () => {
            const { governance } = await loadFixture(deployGovernanceFixture);

            // submit proposal
            const title = "Proposal 2";
            const description = "Proposal 2 description";
            const deadline = (await time.latest()) + ONE_YEAR_IN_SECS;
            const options = ['O1', 'O2'];
            const proposer = TEST_ADDR;
            await governance.submitProposalByWhitelist(title, description, deadline, options, proposer);

            expect(await governance.proposalCount()).to.equal(2);
        });
    });

    describe("Vote", function () {
        it('Should vote proposal', async () => {
            const { governance } = await loadFixture(deployGovernanceFixture);

            // vote option 0
            await governance.vote(0, 0, 1n * ONE_ETH);
            expect(await governance.getWinner(0)).to.equal(0);
        });

        it('Should vote proposal through pool', async () => {
            const { governance } = await loadFixture(deployGovernanceFixture);

            // vote option 0
            await governance.voteThroughPosPool(MOCK_ADDR, 0, 0, 1n * ONE_ETH);
            expect(await governance.getWinner(0)).to.equal(0);
        });
    });
});