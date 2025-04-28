# Misc

## 目前主网和测试网地址

### 测试网

GOVERNANCE=cfxtest:achxp4p0bcsngpz6b5mv11p2wsn2u51sdjuyzjfm8f
EGOVERNANCE=0x95Af72EaC6f5e08b6Ab51874582FA8F8C5E93D28

### 主网

GOVERNANCE=cfx:acd1xg56needgaj9br1dw251135ag1y8fat0zk0arr
EGOVERNANCE=0x4CE48b7e15A6120B7DAFC59bA5184085a51C05Ff

## 如何发起投票

目前发起投票有两种方式:

1. 管理员可直接发起投票: `submitProposalByWhitelist`
2. 如果某用户的质押量, 超过当前 PoS 质押总量的 5% 也可以发起投票: 通过 `submit` 方法

发起投票需要通过 Core Space 的合约发起, eSpace 的合约不支持发起投票.

之前相关的提案说的是满足`总投票权`的 5%, 这里有一点出入 (目前没有一种方式可以获取总的投票权重)

## 增加管理员

任何管理员可以增加新的管理员

```sh
npx hardhat addSubmitter --submitter cfxtest:aam4....b2a5 --network cfx_dev
```

## 矿池白名单管理

只有在白名单中的矿池才能参与投票, 管理员可以通过如何命令增加矿池

Core Space:

```sh
# --white true 表示增加白名单, --white false 表示删除白名单
npx hardhat setWhitelist --pool cfxtest:aa....b2a5 --white true --network cfx_dev
```

eSpace:

```sh
npx hardhat setEgovWhitelist --pool cfxtest:aa....b2a5 --white true --network ecfx_dev
```