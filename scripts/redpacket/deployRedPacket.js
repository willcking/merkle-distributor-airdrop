const { ethers } = require('hardhat');
const { saveRedpacketDeployment } = require('../../utils');

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log('Deploying contracts with the account:', deployer.address);

  const redPacketFactory = await ethers.getContractFactory('RedPacket');
  const redPacket = await redPacketFactory.deploy();
  await redPacket.waitForDeployment();

  console.log('RedPacket address:', redPacket.target);

  let initRecipt = await redPacket.initialize({
    gasLimit: 1483507
  });
  await initRecipt.wait();

  saveRedpacketDeployment({
    redPacketAddress: redPacket.target,
    redPacketOwner: deployer.address,
  })
}


main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });