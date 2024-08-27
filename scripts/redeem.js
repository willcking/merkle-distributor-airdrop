const { ethers }  = require('hardhat');

async function attach(name, address) {
  const contractFactory = await ethers.getContractFactory(name);
  return contractFactory.attach(address);
}

async function main() {
  const [admin, minter, relayer] = await ethers.getSigners();
  console.log(`Redeem token:`);
  console.log(`- admin:   ${admin.address} (${ethers.formatEther(await admin.provider.getBalance(admin.address))})`);
  console.log(`- minter:  ${minter.address} (${ethers.formatEther(await minter.provider.getBalance(minter.address))})`);
  console.log(`- relayer: ${relayer.address} (${ethers.formatEther(await relayer.provider.getBalance(relayer.address))})`);

  const registry    = (await attach('ERC721LazyMintWith712', process.env.ADDRESS)).connect(relayer);
  const tokenId     = process.env.TOKEN_ID;
  const account     = process.env.ACCOUNT;
  const signature   = process.env.SIGNATURE;

  const tx = await registry.redeem(account, tokenId, signature);
  const receipt = await tx.wait();

  console.log(receipt);
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
});