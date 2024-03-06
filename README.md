# Governance

This is the contract code of Conflux community governance. It is developed by hardhat.

## How to deploy

### Core Space

Deploy the core space contract.

```bash
npx hardhat run scripts/deployGovernance.ts --network cfx
```

### eSpace

Deploy and setup the eSpace contract.

```bash
npx hardhat run scripts/eSpace/01_deploy.ts --network ecfx
npx hardhat run scripts/eSpace/02_setupGov.ts --network ecfx
```

Set the eSpace contract address in the core space contract.

```bash
npx hardhat setEspaceGov --network cfx
```

### start the core space block number sync service

```bash
pm2 start "npx hardhat run services/syncCoreBlockNumber.ts --network cfx" --name governance-block-number
```
