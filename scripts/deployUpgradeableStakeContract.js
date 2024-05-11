const { ethers, upgrades } = require('hardhat');

async function main() {
  const ownerAddress = '';
  const tokenAddress = '';

  const GptVerseStake = await ethers.getContractFactory('StakeContract');

  const gptVerseStakeProxy = await upgrades.deployProxy(
    GptVerseStake,
    [ownerAddress, tokenAddress],
    { initializer: 'initialize' },
  );

  console.log('Proxy deployed to:', await gptVerseStakeProxy.getAddress());
  console.log('Token Address:', tokenAddress);
  console.log('Owner Address:', ownerAddress);
}
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
