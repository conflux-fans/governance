// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@confluxfans/contracts/InternalContracts/Staking.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./IPoSPool.sol";

contract Governance is AccessControl {
    bytes32 public constant PROPOSAL_ROLE = keccak256("PROPOSAL_ROLE");
    // internal contracts
    Staking public constant STAKING = Staking(
        address(0x0888000000000000000000000000000000000002)
    );
    struct Proposal {
        string title;
        string discussion;
        uint256 deadline;
        string[] options;
        uint256[] optionVotes;
        // address => vote_option => vote_power
        mapping(address => mapping(uint256 => uint256)) votedPower;
        address proposer;
    }

    struct ProposalAbstract {
        string title;
        string discussion;
        uint256 deadline;
        string[] options;
        uint256[] optionVotes;
        string status;
        address proposer;
        uint256 proposalId;
    }

    event Proposed(
        uint256 indexed proposalId,
        address indexed proposer,
        string title
    );
    event Voted(
        uint256 indexed proposalId,
        address indexed voter,
        uint256 indexed votedOption,
        uint256 votedAmount
    );
    event WithdrawVoted(
        uint256 indexed proposalId,
        address indexed voter,
        uint256 indexed withdrawOption,
        uint256 withdrawAmount
    );

    // proposal
    address public nextProposer;
    uint256 public proposalCnt;
    Proposal[] public proposals;

    // extend delay
    uint256 public extendDelay;
    mapping(address => bool) public poolWhitelist;

    constructor(uint256 _extendDelay) {
        extendDelay = _extendDelay;
        _setupRole(PROPOSAL_ROLE, msg.sender);
    }

    function getBlockNumber() public view returns (uint256) {
        return block.number;
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
        res.deadline = proposal.deadline;
        res.options = proposal.options;
        res.optionVotes = proposal.optionVotes;
        res.proposer = proposal.proposer;
        res.proposalId = idx;
        if (res.deadline < block.number) {
            res.status = "Closed";
        } else {
            res.status = "Active";
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

    function getProposalById(uint256 proposalId)
        public
        view
        returns (ProposalAbstract memory)
    {
        require(proposalId < proposalCnt, "invalid proposal ID");
        return summarizeProposal(proposalId);
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
        for (uint256 i = 0; i < proposal.optionVotes.length; ++i)
            if (proposal.optionVotes[i] > winnerVoted) {
                winnerVoted = proposal.optionVotes[i];
                winner = i;
            } else if (proposal.optionVotes[i] == winnerVoted) {
                winner = proposal.optionVotes.length;
            }
        return winner;
    }

    function setNextProposer(address proposer) public onlyRole(PROPOSAL_ROLE) {
        nextProposer = proposer;
    }

    function _submit(
        string memory title,
        string memory discussion,
        uint256 deadline,
        string[] memory options,
        address proposer
    ) internal {
        require(options.length <= 1000, "too many options");

        proposals.push();
        Proposal storage proposal = proposals[proposalCnt];

        proposal.title = title;
        proposal.discussion = discussion;
        proposal.deadline = deadline;
        proposal.options = options;
        proposal.optionVotes = new uint256[](options.length);
        proposal.proposer = proposer;

        emit Proposed(proposalCnt, proposer, title);
        nextProposer = address(0);
        proposalCnt += 1;
    }

    function submitProposal(
        string memory title,
        string memory discussion,
        uint256 deadline,
        string[] memory options
    ) public {
        require(msg.sender == nextProposer, "sender is not the next proposer");
        _submit(title, discussion, deadline, options, msg.sender);
    }

    function submitProposalByWhitelist(
        string memory title,
        string memory discussion,
        uint256 deadline,
        string[] memory options,
        address proposer
    ) public onlyRole(PROPOSAL_ROLE) {
        _submit(title, discussion, deadline, options, proposer);
    }

    function submitHistoryProposalByWhitelist(
        string memory title,
        string memory discussion,
        uint256 deadline,
        string[] memory options,
        uint256[] memory optionVotes,
        address proposer
    ) public onlyRole(PROPOSAL_ROLE) {
        require(deadline < block.number, "history proposal is not closed");
        _submit(title, discussion, deadline, options, proposer);
        proposals[proposals.length - 1].optionVotes = optionVotes;
    }

    function setExtendDelay(uint256 _extendDelay) public onlyRole(PROPOSAL_ROLE) {
        extendDelay = _extendDelay;
    }

    function setPoolWhitelist(address pool, bool flag) public onlyRole(PROPOSAL_ROLE) {
        poolWhitelist[pool] = flag;
    }

    function _vote(uint256 proposalId, uint256 optionId, uint256 power, uint256 availableVotePower) public {
        require(proposalId < proposalCnt, "invalid proposal ID");
        Proposal storage proposal = proposals[proposalId];
        require(proposal.deadline >= block.number, "the proposal has finished");
        require(optionId < proposal.options.length, "invalid option ID");

        uint256 lastWinner = getWinner(proposalId);

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

        uint256 newWinner = getWinner(proposalId);
        if (
            newWinner != lastWinner &&
            block.number + extendDelay > proposal.deadline
        ) {
            proposal.deadline = block.number + extendDelay;
        }
    }

    function vote(uint256 proposalId, uint256 optionId, uint256 power) public {
        uint256 availableVotePower = STAKING.getVotePower(msg.sender, block.number);
        _vote(proposalId, optionId, power, availableVotePower);
    }

    function voteThroughPosPool(address pool, uint256 proposalId, uint256 optionId, uint256 power) public {
        require(poolWhitelist[pool], "pool is not in whitelist");
        uint256 availableVotePower = IPoSPool(pool).userVotePower(msg.sender);
        _vote(proposalId, optionId, power, availableVotePower);
    }
}