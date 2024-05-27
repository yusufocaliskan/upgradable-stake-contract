# Hardhat Project

This project presents an advanced, upgradable staking contract developed in Solidity, aimed at providing flexibility and scalability for decentralized finance (DeFi) applications. Utilizing the Hardhat framework, the contract supports seamless deployment, upgrading, and testing processes, ensuring a robust and efficient staking mechanism on the Ethereum blockchain.

Key Features:
- The contract can be easily upgraded to include new features or fix issues without disrupting the existing staking pools or user data.
Deployment:
- Deploy the staking contract on the Sepolia network with a simple command, making it accessible on a live blockchain.
Staking Pools:
- Create and manage multiple staking pools with configurable parameters such as start and end times, annual percentage yield (APY), and minimum/maximum staking limits.
User-Friendly Staking:
- Users can stake tokens into designated pools, add additional stakes, and claim rewards efficiently.
  
## Upgradable Stake Contract

Deploy: Stake Contract

```shell
npx hardhat run scripts/deployUpgradeableStakeContract.js  --network bscMainnet
```

Upgrade: The upgradable Stake Contrat

```shell
npx hardhat run scripts/upgradeStakeContract.js --network bscTestnet
```

Testing comman

```shell
npx hardhat test test/StakeContract.js
```

Start the hardhat node on local (if you wish)

```shell
npx hardhat node
```

Others

```shell
npx hardhat help
REPORT_GAS=true npx hardhat test
```

# Usage

Create a new Stake Pool

```shell
await stakeContract.createStakePool(
      'test1', //id
      'Test Stake Pool', //name
      1715242924, //start
      1746778924, //end
      5000, //apy 50%
      parseUnits('1', 18), //min
      parseUnits('1000000', 18), //max
    );
```

Stake token to the pool by giving a stake pool Id

```shell
    await stakeContract.stakeToken(
      user1.address, //user
      parseUnits('1', 18), //amount
      'test1', //pool id
    );
```

Additional stake can be added to the same pool

```shell
    await stakeContract.stakeToken(
      user1.address, //user
      parseUnits('2', 18), //amount
      'test1', //pool id
    );

await stakeContract.stakeToken(
      user1.address, //user
      parseUnits('3', 18), //amount
      'test1', //pool id
    );
```

Total Claim: Claim the rewards in the pool by giving the pool id:

```shell await updateTimestampAsDays(365);

    const tx = await stakeContract.claimReward4Total(
      user1.address, //user
      'test1', //pool id
    );
```

Claming for each stake : Claim the rewards in the pool by giving the pool id:

```shell
await updateTimestampAsDays(365);

    const tx = await stakeContract.claimReward4Each(
      user1.address, //user
      'test1', //pool id
      '1', //stake id
    );
```
