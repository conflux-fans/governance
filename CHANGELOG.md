# changelog

## v0.2.0 (2023-101-16)

增加对 eSpace 矿池参加社区投票的支持. 大致实现方式为, 在 eSpace 同时部署一个 governance 合约. 增加投票时, 两边都回增加, 允许两边同时投票, 投票结果会同时考虑两边的投票.

生产环境升级时, 需做如下操作:

1. 部署 eSpace 合约
2. 添加历史 proposal 数据
3. 升级 core Governance 合约, 并设置 eSpace 合约地址
4. 启动 espace block number 更新脚本