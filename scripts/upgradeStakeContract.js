const { ethers, upgrades } = require('hardhat');

async function main() {
  const existingProxyAddress = '';
  const GptVerseStakeV2 = await ethers.getContractFactory('StakeContract');

  const upgradedProxy = await upgrades.upgradeProxy(
    existingProxyAddress,
    GptVerseStakeV2,
  );

  console.log('Proxy deployed to:', await upgradedProxy.getAddress());
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
