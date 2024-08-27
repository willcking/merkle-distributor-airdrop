const { ethers }  = require('hardhat');

async function attach(name, address) {
  const contractFactory = await ethers.getContractFactory(name);
  return contractFactory.attach(address);
}

async function main() {
  const [admin, minter, relayer] = await ethers.getSigners();
  console.log(`Sign authorization:`);
  console.log(`- admin:   ${admin.address} (${ethers.formatEther(await admin.provider.getBalance(admin.address))})`);
  console.log(`- minter:  ${minter.address} (${ethers.formatEther(await minter.provider.getBalance(minter.address))})`);
  console.log(`- relayer: ${relayer.address} (${ethers.formatEther(await relayer.provider.getBalance(relayer.address))})`);

  const registry = (await attach('ERC721LazyMintWith712', process.env.ADDRESS)).connect(minter);
  const { chainId } = await ethers.provider.getNetwork();
  const tokenId     = process.env.TOKEN_ID;
  const account     = process.env.ACCOUNT;
  const signature   = await minter.signTypedData(
    // Domain
    {
      name: 'Name',
      version: '1.0.0',
      chainId,
      verifyingContract: registry.target,
    },
    // Types
    {
      NFT: [
        { name: 'tokenId', type: 'uint256' },
        { name: 'account', type: 'address' },
      ],
    },
    // Value
    { tokenId, account },
  );

  console.log({ registry: registry.address, tokenId, account, signature });
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
});