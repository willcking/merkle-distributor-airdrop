const { ethers } = require('hardhat');
const { MerkleTree } = require('merkletreejs');
const keccak256 = require('keccak256');
const { readRedpacketDeployment } = require('../../utils');
const claimerList = require('./claimerList.json');
require('dotenv').config();

function hashToken(account) {
  return Buffer.from(ethers.solidityPackedKeccak256(['address'], [account]).slice(2), 'hex');
}

async function main() {
    const [deployer] = await ethers.getSigners();
    const deployment = readRedpacketDeployment();

    const RedPacketAddress = deployment.redPacketAddress;
    const SimpleTokenAddress = deployment.simpleTokenAddress;
    const redpacketID = deployment.redPacketID;
    const simpleToken = await ethers.getContractAt('SimpleToken', SimpleTokenAddress, deployer);
    const redPacket = await ethers.getContractAt('RedPacket', RedPacketAddress, deployer);

    merkleTree = new MerkleTree(
      claimerList.map((user) => hashToken(user)),
      keccak256,
      { sortPairs: true }
    );

    async function cliamRedPacket(user) {
        let proof = merkleTree.getHexProof(hashToken(user.address));
        console.log('merkleTree proof: ', proof);

        const balanceBefore = await simpleToken.balanceOf(user.address);

        let createRedPacketRecipt = await redPacket.connect(user).claim(redpacketID, proof);
        await createRedPacketRecipt.wait();

        const balanceAfter = await simpleToken.balanceOf(user.address);
        console.log(`user ${user.address} has claimd ${balanceAfter - balanceBefore}`);
    }

  console.log("\n=========Begin to claim Red Packet=========\n")
  
  await cliamRedPacket(deployer);

  console.log('\n=========Claim Red Packet successfully=========\n');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
});