// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@confluxfans/contracts/InternalContracts/Staking.sol";
import "@confluxfans/contracts/InternalContracts/ParamsControl.sol";
import "@confluxfans/contracts/InternalContracts/PoSRegister.sol";
import "@confluxfans/contracts/InternalContracts/CrossSpaceCall.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "./IPoSPool.sol";
import "./IGovernance.sol";

contract Governance is AccessControl, IGovernance, Initializable {
    // Add the library methods
    using EnumerableSet for EnumerableSet.AddressSet;

    bytes32 private constant PROPOSAL_ROLE = keccak256("PROPOSAL_ROLE");
    // internal contracts
    Staking private constant STAKING = Staking(0x0888000000000000000000000000000000000002);
    PoSRegister private constant POS_REGISTER = PoSRegister(0x0888000000000000000000000000000000000005);
    ParamsControl private constant PARAMS_CONTROL = ParamsControl(0x0888000000000000000000000000000000000007);
    CrossSpaceCall internal constant CROSS_SPACE_CALL = CrossSpaceCall(0x0888000000000000000000000000000000000006);

    uint256 public constant RATIO_BASE = 1_000_000_000;
    uint256 public MIN_VOTE_RATIO = 1_000_000_0 * 5;
    
    // proposal
    address public nextProposer;
    uint256 public proposalCnt;
    Proposal[] public proposals;

    // extend delay
    uint256 public extendDelay;
    // Declare a set state variable
    EnumerableSet.AddressSet private poolWhitelist;

    address public espaceGovernance;

    constructor(uint256 _extendDelay) {
        extendDelay = _extendDelay;
        _grantRole(PROPOSAL_ROLE, msg.sender);
    }

    function initialize() public initializer {
        _grantRole(PROPOSAL_ROLE, msg.sender);
    }

    function setEspaceGovernance(address _espaceGovernance) public onlyRole(PROPOSAL_ROLE) {
        espaceGovernance = _espaceGovernance;
    }

    function setExtendDelay(uint256 _extendDelay) public onlyRole(PROPOSAL_ROLE) {
        extendDelay = _extendDelay;
    }

    function setMinVoteRatio(uint256 _minVoteRatio) public onlyRole(PROPOSAL_ROLE) {
        MIN_VOTE_RATIO = _minVoteRatio;
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
        res.description = proposal.description;
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

        // add espace votes
        if (espaceGovernance != address(0)) {
            uint256[] memory espaceVotes = eSpaceGetPoposalOptionVotes(idx);
            for(uint256 i = 0; i < res.optionVotes.length; ++i) {
                res.optionVotes[i] += espaceVotes[i];
            }
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

        uint256[] memory votes = new uint256[](proposal.optionVotes.length);

        // add eSpace votes
        if (espaceGovernance != address(0)) {
            uint256[] memory espaceVotes = eSpaceGetPoposalOptionVotes(proposalId);
            for(uint256 i = 0; i < proposal.optionVotes.length; ++i) {
                votes[i] += espaceVotes[i];
            }
        }

        // add core space votes
        for(uint256 i = 0; i < proposal.optionVotes.length; ++i) {
            votes[i] += proposal.optionVotes[i];
        }


        for (uint256 i = 0; i < votes.length; ++i) {
            if (votes[i] > winnerVoted) {
                winnerVoted = votes[i];
                winner = i;
            } else if (votes[i] == winnerVoted) { // if two options have same votes, the winner will set to no one
                winner = votes.length;
            }
        }

        return winner;
    }

    function currentRoundTotalPoSVotes() public view returns (uint256) {
        return PARAMS_CONTROL.posStakeForVotes(PARAMS_CONTROL.currentRound());
    }

    function userPoSStakes(address user) public view returns (uint256) {
        // get address self staked votes
        bytes32 identity = POS_REGISTER.addressToIdentifier(user);
        (uint256 totalStaked, uint256 totalUnlocked) = POS_REGISTER.getVotes(identity);
        uint256  totalPoSVotes = totalStaked - totalUnlocked;

        // sum votes in pos pools
        uint256 len = poolWhitelist.length();
        for(uint256 i = 0; i < len; i++) {
            address pool = poolWhitelist.at(i);
            IPoSPool.UserSummary memory userSummary = IPoSPool(pool).userSummary(user);
            totalPoSVotes += userSummary.available;
        }
        return totalPoSVotes * 1000 ether;
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

        emit Proposed(proposalCnt, proposer, title);
        nextProposer = address(0);
        proposalCnt += 1;

        // sync to espace governane
        eSpaceSubmitProposal(title, discussion, deadline, options, proposer, description);
    }

    // submit if user's vote power meet the requirement
    function submit(
        string memory title,
        string memory discussion,
        uint256 deadline,
        string[] memory options,
        string memory description
    ) public {
        uint256 totalPoSVotes = currentRoundTotalPoSVotes();
        uint256 _userVotes = userPoSStakes(msg.sender);
        require(_userVotes > totalPoSVotes * MIN_VOTE_RATIO / RATIO_BASE, "not enough votes");
        _submit(title, discussion, deadline, options, msg.sender, description);
    }

    function submitProposal(
        string memory title,
        string memory discussion,
        uint256 deadline,
        string[] memory options,
        string memory description
    ) public {
        require(msg.sender == nextProposer, "sender is not the next proposer");
        _submit(title, discussion, deadline, options, msg.sender, description);
    }

    function submitProposalByWhitelist(
        string memory title,
        string memory discussion,
        uint256 deadline,
        string[] memory options,
        address proposer,
        string memory description
    ) public onlyRole(PROPOSAL_ROLE) {
        _submit(title, discussion, deadline, options, proposer, description);
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
        proposals[proposals.length - 1].optionVotes = optionVotes;
    }

    function setNextProposer(address proposer) public onlyRole(PROPOSAL_ROLE) {
        nextProposer = proposer;
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

        // sync to espace governane
        eSpaceSetDeadline(proposalId, proposal.deadline);
        eSpaceSetProposalCoreVotes(proposalId, proposal.optionVotes);
    }

    function vote(uint256 proposalId, uint256 optionId, uint256 power) public {
        uint256 availableVotePower = STAKING.getVotePower(msg.sender, block.number);
        _vote(proposalId, optionId, power, availableVotePower);
    }

    function _voteThroughPos(uint256 proposalId, uint256 optionId, uint256 power, uint256 availableVotePower, address pool) internal {
        require(proposalId < proposalCnt, "invalid proposal ID");
        Proposal storage proposal = proposals[proposalId];
        require(proposal.deadline >= block.number, "the proposal has finished");
        require(optionId < proposal.options.length, "invalid option ID");

        uint256 lastWinner = getWinner(proposalId);

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

        uint256 newWinner = getWinner(proposalId);
        if (
            newWinner != lastWinner &&
            block.number + extendDelay > proposal.deadline
        ) {
            proposal.deadline = block.number + extendDelay;
        }

        // sync to espace governane
        eSpaceSetDeadline(proposalId, proposal.deadline);
        eSpaceSetProposalCoreVotes(proposalId, proposal.optionVotes);
    }

    function voteThroughPosPool(address pool, uint256 proposalId, uint256 optionId, uint256 power) public {
        require(poolWhitelist.contains(pool), "pool is not in whitelist");
        uint256 availableVotePower = IPoSPool(pool).userVotePower(msg.sender);
        _voteThroughPos(proposalId, optionId, power, availableVotePower, pool);
    }

    function updateEspaceCoreChainInfo() public {
        eSpaceUpdateCoreChainInfo();
    }

    ///////////////////////////// cross space methods ////////////////////////////
    function eSpaceSubmitProposal(
        string memory title,
        string memory discussion,
        uint256 deadline,
        string[] memory options,
        address proposer,
        string memory description
    ) internal {
        if (espaceGovernance == address(0)) {return;}
        CROSS_SPACE_CALL.callEVM(_ePoolGovB20(), abi.encodeWithSignature("submitProposal(string,string,uint256,string[],address,string)", title, discussion, deadline, options, proposer, description));
    }

    function eSpaceSetProposalCoreVotes(uint256 proposalId, uint256[] memory optionVotes) internal {
        if (espaceGovernance == address(0)) {return;}
        CROSS_SPACE_CALL.callEVM(_ePoolGovB20(), abi.encodeWithSignature("setProposalCoreVotes(uint256,uint256[])", proposalId, optionVotes));
    }

    function eSpaceSetDeadline(uint256 proposalId, uint256 deadline) internal {
        if (espaceGovernance == address(0)) {return;}
        CROSS_SPACE_CALL.callEVM(_ePoolGovB20(), abi.encodeWithSignature("setProposalDeadline(uint256,uint256)", proposalId, deadline));
    }

    function eSpaceGetPoposalOptionVotes(uint256 proposalId) internal view returns (uint256[] memory) {
        if (espaceGovernance == address(0)) {return new uint256[](0);}
        bytes memory nums = CROSS_SPACE_CALL.staticCallEVM(_ePoolGovB20(), abi.encodeWithSignature("getProposalOptionVotes(uint256)", proposalId));
        return abi.decode(nums, (uint256[]));
    }

    function eSpaceUpdateCoreChainInfo() internal {
        if (espaceGovernance == address(0)) {return;}
        CROSS_SPACE_CALL.callEVM(_ePoolGovB20(), abi.encodeWithSignature("updateCoreChainInfo(uint256,uint64)", block.number, PARAMS_CONTROL.currentRound()));
    }

    function _ePoolGovB20() internal view returns (bytes20) {
        return bytes20(espaceGovernance);
    }
}