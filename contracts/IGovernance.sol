// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

interface IGovernance {
    struct Proposal {
        string title;
        string discussion;
        uint256 deadline;
        string[] options;
        uint256[] optionVotes;
        // address => vote_option => vote_power
        mapping(address => mapping(uint256 => uint256)) votedPower;
        // pool address => user address => vote_option => vote_power
        mapping(address => mapping(address => mapping(uint256 => uint256))) posPoolVotedPower;
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

    event Proposed( uint256 indexed proposalId, address indexed proposer, string title);
    
    event Voted( uint256 indexed proposalId, address indexed voter, uint256 indexed votedOption, uint256 votedAmount);
    
    event WithdrawVoted( uint256 indexed proposalId, address indexed voter, uint256 indexed withdrawOption, uint256 withdrawAmount);

    function proposalCount() external view returns (uint256);

    function getVoteForProposal(uint256 proposalId, address voter, uint256 option) external view returns (uint256);
    
    function getVoteForProposal(uint256 proposalId, address voter) external view returns (uint256[] memory);
    
    function getPoolVoteForProposal(uint256 proposalId, address pool, address voter) external view returns (uint256[] memory);

    function getProposalById(uint256 proposalId) external view returns (ProposalAbstract memory);

    function getProposalList(uint256 offset, uint256 cnt) external view returns (ProposalAbstract[] memory);

    function getWinner(uint256 proposalId) external view returns (uint256);

    function setNextProposer(address proposer) external;

    function submitProposal( string memory title, string memory discussion, uint256 deadline, string[] memory options) external;

    function submitProposalByWhitelist( string memory title, string memory discussion, uint256 deadline, string[] memory options, address proposer) external;

    function submitHistoryProposalByWhitelist( string memory title, string memory discussion, uint256 deadline, string[] memory options, uint256[] memory optionVotes, address proposer) external;

    function setExtendDelay(uint256 _extendDelay) external;

    function setPoolWhitelist(address pool, bool flag) external;

    function vote(uint256 proposalId, uint256 optionId, uint256 power) external;

    function voteThroughPosPool(address pool, uint256 proposalId, uint256 optionId, uint256 power) external;
}