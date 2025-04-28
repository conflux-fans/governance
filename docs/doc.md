# Gov Doc

本合约为 Governance v2 合约，相较于 v1 版本，主要有以下改进:

1. 允许一个人同时对不同的选项进行投票
2. 允许任何人在满足某条件的情况下发起一个新的投票
3. 支持使用 PoSPool 中的投票权进行投票

## 合约接口

合约主要接口均同 v1 保持一致， 主要 `vote` 接口增加了一个参数，用于指定投票的数量。

```js
function vote(uint256 proposalId, uint256 optionId, uint256 power) external;
```

另外增加了一个接口 `voteThroughPosPool`，用于使用矿池中的投票权进行投票。

```js
// 第一个参数为矿池地址
function voteThroughPosPool(address pool, uint256 proposalId, uint256 optionId, uint256 power) external;
```

完整的合约接口如下：

```js
interface IGovernance {
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
    // proposal 总数
    function proposalCount() external view returns (uint256);
    // 获取某 proposal 的某用户当前的投票数量
    function getVoteForProposal(uint256 proposalId, address voter, uint256 option) external view returns (uint256);
    // 根据 id 获取投票信息
    function getProposalById(uint256 proposalId) external view returns (ProposalAbstract memory);
    // 获取投票列表
    function getProposalList(uint256 offset, uint256 cnt) external view returns (ProposalAbstract[] memory);
    // 获取投票结果
    function getWinner(uint256 proposalId) external view returns (uint256);
    // 投票
    function vote(uint256 proposalId, uint256 optionId, uint256 power) external;
    // 通过矿池投票
    function voteThroughPosPool(address pool, uint256 proposalId, uint256 optionId, uint256 power) external;

    function setNextProposer(address proposer) external;

    function submitProposal( string memory title, string memory discussion, uint256 deadline, string[] memory options) external;

    function submitProposalByWhitelist( string memory title, string memory discussion, uint256 deadline, string[] memory options, address proposer) external;

    function submitHistoryProposalByWhitelist( string memory title, string memory discussion, uint256 deadline, string[] memory options, uint256[] memory optionVotes, address proposer) external;

    function setExtendDelay(uint256 _extendDelay) external;

    function setPoolWhitelist(address pool, bool flag) external;
}
```

## eSpace proposal

为了允许 eSpace 的矿池参与 proposal 投票, 同时会在 eSpace 中部署一个 Governance 合约. 目前限制 proposal 的添加只能通过 core space, core space 的增加方法会同步在 eSpace 的 governance 合约中增加一个 proposal.

Core 和 eSpace 的 governance 合约允许同时进行投票，各选项的票数为 Core 和 eSpace 之和.

eSpace 的 Governance 合约接口同 Core 保持一致，只是关闭了 pow 投票接口 (`vote`), 只允许通过 PoS 矿池进行投票 (`voteThroughPosPool`).
