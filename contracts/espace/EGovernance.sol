// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../IPoSPool.sol";
import "../IGovernance.sol";

/*
* proposal can only be created from core space, also the deadline is set by core space
*/
contract EGovernance is AccessControl, IGovernance, Initializable {
    using EnumerableSet for EnumerableSet.AddressSet; // Add the library methods

    bytes32 private constant PROPOSAL_ROLE = keccak256("PROPOSAL_ROLE");

    address public coreGovernanceBridge;

    uint256 private coreSpaceBlockNumber;
    uint64 private coreSpaceVoteRound;
    
    // proposal
    // address public nextProposer;
    uint256 private proposalCnt;
    Proposal[] public proposals;

    EnumerableSet.AddressSet private poolWhitelist;
    mapping(uint256 => uint256[]) private _coreProposalOptionVotes;

    modifier onlyBridge() {
        require(msg.sender == coreGovernanceBridge, "Only bridge is allowed");
        _;
    }

    constructor() {
        _grantRole(PROPOSAL_ROLE, msg.sender);
    }

    function initialize() public initializer {
        _grantRole(PROPOSAL_ROLE, msg.sender);
    }

    function setCoreGovernanceBridge(address bridge) public onlyRole(PROPOSAL_ROLE) {
        coreGovernanceBridge = bridge;
    }

    function summarizeProposal(uint256 idx)
        internal
        view
        returns (ProposalAbstract memory)
    {
        Proposal storage proposal = proposals[idx];
        ProposalAbstract memory res;
        res.title = proposal.title;
        res.discussion = proposal.discussion;
        res.description = proposal.description;
        res.deadline = proposal.deadline;
        res.options = proposal.options;
        res.optionVotes = proposal.optionVotes;
        res.proposer = proposal.proposer;
        res.proposalId = idx;
        if (res.deadline < coreSpaceBlockNumber) {
            res.status = "Closed";
        } else {
            res.status = "Active";
        }

        // sum core space votes
        for(uint256 i = 0; i < res.optionVotes.length; ++i) {
            res.optionVotes[i] += _coreProposalOptionVotes[idx][i];
        }

        return res;
    }

    function proposalCount() public view returns (uint256) {
        return proposalCnt;
    }

    function getVoteForProposal(uint256 proposalId, address voter, uint256 option)
        public
        view
        returns (uint256)
    {
        require(proposalId < proposalCnt, "invalid proposal ID");
        Proposal storage proposal = proposals[proposalId];
        return proposal.votedPower[voter][option];
    }

    function getVoteForProposal(uint256 proposalId, address voter) public view returns (uint256[] memory) {
        require(proposalId < proposalCnt, "invalid proposal ID");
        Proposal storage proposal = proposals[proposalId];
        uint256[] memory res = new uint256[](proposal.options.length);
        for(uint256 i = 0; i < proposal.options.length; ++i) {
            res[i] = proposal.votedPower[voter][i];
        }
        return res;
    }

    function getPoolVoteForProposal(uint256 proposalId, address pool, address voter) public view returns (uint256[] memory) {
        require(proposalId < proposalCnt, "invalid proposal ID");
        Proposal storage proposal = proposals[proposalId];
        uint256[] memory res = new uint256[](proposal.options.length);
        for(uint256 i = 0; i < proposal.options.length; ++i) {
            res[i] = proposal.posPoolVotedPower[pool][voter][i];
        }
        return res;
    }

    function getProposalById(uint256 proposalId)
        public
        view
        returns (ProposalAbstract memory)
    {
        require(proposalId < proposalCnt, "invalid proposal ID");
        return summarizeProposal(proposalId);
    }

    function getProposalOptionVotes(uint256 proposalId) public view returns (uint256[] memory) {
        require(proposalId < proposalCnt, "invalid proposal ID");
        Proposal storage proposal = proposals[proposalId];
        return proposal.optionVotes;
    }

    function getProposalList(uint256 offset, uint256 cnt)
        public
        view
        returns (ProposalAbstract[] memory)
    {
        require(offset < proposalCnt, "invalid offset");
        require(cnt <= 100, "cnt is larger than 100");
        uint256 i = proposalCnt - 1 - offset;
        if (cnt > i + 1) cnt = i + 1;
        ProposalAbstract[] memory res = new ProposalAbstract[](cnt);
        for (uint256 k = 0; k < cnt; ++k) {
            res[k] = summarizeProposal(i - k);
        }
        return res;
    }

    function getWinner(uint256 proposalId) public view returns (uint256) {
        Proposal storage proposal = proposals[proposalId];
        uint256 winner = proposal.optionVotes.length;
        uint256 winnerVoted = 0;
        for (uint256 i = 0; i < proposal.optionVotes.length; ++i) {
            if (proposal.optionVotes[i] > winnerVoted) {
                winnerVoted = proposal.optionVotes[i];
                winner = i;
            } else if (proposal.optionVotes[i] == winnerVoted) {
                winner = proposal.optionVotes.length;
            }
        }
        
        // TODO consider core space votes

        return winner;
    }

    function _submit(
        string memory title,
        string memory discussion,
        uint256 deadline,
        string[] memory options,
        address proposer,
        string memory description
    ) internal {
        require(options.length <= 1000, "too many options");

        proposals.push();
        Proposal storage proposal = proposals[proposalCnt];

        proposal.title = title;
        proposal.discussion = discussion;
        proposal.description = description;
        proposal.deadline = deadline;
        proposal.options = options;
        proposal.optionVotes = new uint256[](options.length);
        proposal.proposer = proposer;

        _coreProposalOptionVotes[proposalCnt] = new uint256[](options.length);

        emit Proposed(proposalCnt, proposer, title);
        // nextProposer = address(0);
        proposalCnt += 1;
    }

    function submitHistoryProposalByWhitelist(
        string memory title,
        string memory discussion,
        uint256 deadline,
        string[] memory options,
        uint256[] memory optionVotes,
        address proposer,
        string memory description
    ) public onlyRole(PROPOSAL_ROLE) {
        require(deadline < block.number, "history proposal is not closed");
        _submit(title, discussion, deadline, options, proposer, description);
        // proposals[proposals.length - 1].optionVotes = optionVotes;
        _coreProposalOptionVotes[proposalCnt - 1] = optionVotes;
    }

    function submitProposal(
        string memory title,
        string memory discussion,
        uint256 deadline,
        string[] memory options,
        address proposer,
        string memory description
    ) public onlyBridge {
        _submit(title, discussion, deadline, options, proposer, description);
    }

    function setProposalDeadline(uint256 proposalId, uint256 deadline) public onlyBridge {
        require(proposalId < proposalCnt, "invalid proposal ID");
        Proposal storage proposal = proposals[proposalId];
        proposal.deadline = deadline;
    }

    function setProposalCoreVotes(uint256 propoalId, uint256[] memory optionVotes) public onlyBridge {
        require(propoalId < proposalCnt, "invalid proposal ID");
        _coreProposalOptionVotes[propoalId] = optionVotes;
    }

    function updateCoreChainInfo(uint256 _blockNumber, uint64 _voteRound) public onlyBridge {
        coreSpaceBlockNumber = _blockNumber;
        coreSpaceVoteRound = _voteRound;
    }

    // this is the method for ICoreSpaceInfo, which will return the latest core space block number
    function blockNumber() public view returns (uint256) {
        return coreSpaceBlockNumber;
    }
    // return the current vote round of core space
    function currentVoteRound() public view returns (uint64) {
        return coreSpaceVoteRound;
    }

    function addSubmiter(address user) public onlyRole(PROPOSAL_ROLE) {
        _grantRole(PROPOSAL_ROLE, user);
    }

    function removeSubmiter(address user) public onlyRole(PROPOSAL_ROLE) {
        _revokeRole(PROPOSAL_ROLE, user);
    }

    function setPoolWhitelist(address pool, bool flag) public onlyRole(PROPOSAL_ROLE) {
        if (flag) {
            poolWhitelist.add(pool);
        } else {
            poolWhitelist.remove(pool);
        }
    }

    function _vote(uint256 proposalId, uint256 optionId, uint256 power, uint256 availableVotePower) internal {
        require(proposalId < proposalCnt, "invalid proposal ID");
        Proposal storage proposal = proposals[proposalId];
        require(proposal.deadline >= block.number, "the proposal has finished");
        require(optionId < proposal.options.length, "invalid option ID");

        uint256 lastVotedPower = proposal.votedPower[msg.sender][optionId];
        if (lastVotedPower > 0) {
            proposal.optionVotes[optionId] -= lastVotedPower;
            proposal.votedPower[msg.sender][optionId] = 0;
            emit WithdrawVoted(
                proposalId,
                msg.sender,
                optionId,
                lastVotedPower
            );
        }

        // check total votePower is not execeed the availableVotePower
        uint256 currentVotedPower = 0;
        for(uint256 i = 0; i < proposal.options.length; ++i) {
            currentVotedPower += proposal.votedPower[msg.sender][i];
        }
        require(currentVotedPower + power <= availableVotePower, "exceed total vote power");

        //
        proposal.votedPower[msg.sender][optionId] = power;
        proposal.optionVotes[optionId] += power;
        
        emit Voted(proposalId, msg.sender, optionId, power);

    }

    function vote(uint256 proposalId, uint256 optionId, uint256 power) public {
        require(false, "eSpace do not support");
        uint256 availableVotePower = 0;  // note espace do not support vote pow vote power
        _vote(proposalId, optionId, power, availableVotePower);
    }

    function _voteThroughPos(uint256 proposalId, uint256 optionId, uint256 power, uint256 availableVotePower, address pool) internal {
        require(proposalId < proposalCnt, "invalid proposal ID");
        Proposal storage proposal = proposals[proposalId];
        require(proposal.deadline >= block.number, "the proposal has finished");
        require(optionId < proposal.options.length, "invalid option ID");

        uint256 lastVotedPower = proposal.posPoolVotedPower[pool][msg.sender][optionId];
        if (lastVotedPower > 0) {
            proposal.optionVotes[optionId] -= lastVotedPower;
            proposal.posPoolVotedPower[pool][msg.sender][optionId] = 0;
            emit WithdrawVoted(
                proposalId,
                msg.sender,
                optionId,
                lastVotedPower
            );
        }

        // check total votePower is not execeed the availableVotePower
        uint256 currentVotedPower = 0;
        for(uint256 i = 0; i < proposal.options.length; ++i) {
            currentVotedPower += proposal.posPoolVotedPower[pool][msg.sender][i];
        }
        require(currentVotedPower + power <= availableVotePower, "exceed total vote power");

        //
        proposal.posPoolVotedPower[pool][msg.sender][optionId] = power;
        proposal.optionVotes[optionId] += power;
        
        emit Voted(proposalId, msg.sender, optionId, power);
    }

    // todo test
    function voteThroughPosPool(address pool, uint256 proposalId, uint256 optionId, uint256 power) public {
        require(poolWhitelist.contains(pool), "pool is not in whitelist");
        uint256 availableVotePower = IPoSPool(pool).userVotePower(msg.sender);
        _voteThroughPos(proposalId, optionId, power, availableVotePower, pool);
    }
}