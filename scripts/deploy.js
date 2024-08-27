const { ethers }  = require('hardhat');

async function deploy(name, ...params) {
  const contractFactory = await ethers.getContractFactory(name);
  return await contractFactory.deploy(...params).then(f => f.waitForDeployment());
}

async function main() {
  const [admin, minter, relayer] = await ethers.getSigners();
  console.log(`Deploying contracts:`);
  console.log(`- admin:   ${admin.address} (${ethers.formatEther(await admin.provider.getBalance(admin.address))})`);
  console.log(`- minter:  ${minter.address} (${ethers.formatEther(await minter.provider.getBalance(minter.address))})`);
  console.log(`- relayer: ${relayer.address} (${ethers.formatEther(await relayer.provider.getBalance(relayer.address))})`);

  const registry = (await deploy('ERC721LazyMintWith712', 'Name', 'Symbol')).connect(admin);
  await registry.grantRole(await registry.MINTER_ROLE(), minter.address);

  console.log({ registry: registry.target });
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
});