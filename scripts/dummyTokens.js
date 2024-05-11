const hre = require('hardhat');

async function main() {
  const ownerAdress = '';

  const FirstToken = await hre.ethers.getContractFactory('FTT');

  const firstToken = await FirstToken.deploy(ownerAdress);
  console.log('First Token Contract Address', await firstToken.getAddress());
}

main().catch((error) => {
  console.log(error);
  process.exitCode = 1;
});
