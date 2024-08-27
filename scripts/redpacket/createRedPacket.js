const {ethers} = require('hardhat');
const {MerkleTree} = require('merkletreejs');
const keccak256 = require('keccak256');
const claimerList = require('./claimerList.json');
const {saveRedpacketDeployment, readRedpacketDeployment} = require('../../utils');
require('dotenv').config();

let endSleep = false;

function hashToken(account) {
    return Buffer.from(ethers.solidityPackedKeccak256(['address'], [account]).slice(2), 'hex');
}

async function sleep() {
  for (let i = 0; i < 500; i++) {
    if (endSleep) break;
    await new Promise((resolve) => {
      setTimeout(() => {
        resolve(true);
      }, 500);
    });
  }
  if (!endSleep) console.log(`\nhad slept too long, but no result...`);
}

async function main() {
    const [deployer] = await ethers.getSigners();
    const deployment = readRedpacketDeployment();

    const RedpacketAddress = deployment.redPacketAddress;
    const SimpleTokenAddress = deployment.simpleTokenAddress;

    const redPacket = await ethers.getContractAt('RedPacket', RedpacketAddress, deployer);
    const simpleToken = await ethers.getContractAt('SimpleToken', SimpleTokenAddress, deployer);

    let tx = await simpleToken.approve(redPacket.target, ethers.parseEther('100'));
    await tx.wait();
    console.log('Approve Successfully');


    merkleTree = new MerkleTree(
        claimerList.map((user) => hashToken(user)),
        keccak256,
        { sortPairs: true }
    )
    merkleTreeRoot = merkleTree.getHexRoot();
    console.log('merkleTree Root is:', merkleTreeRoot);

    let creationParams = {
        merkleroot: merkleTreeRoot,
        recipient_number: 93,
        ifrandom: true,
        duration: 259200,
        seed: ethers.encodeBytes32String('test'),
        message: 'Hi',
        name: 'cache',
        token_type: 1,
        token_addr: SimpleTokenAddress,
        total_tokens: ethers.parseEther('100')
    };
    //Setting up event listeners
    redPacket.once('CreationSuccess', (total, id, name, message, creator, creation_time, token_address, number, ifrandom, duration) => {
        endSleep = true;
        saveRedpacketDeployment({ redPacketID: id, redPacketTotal: total.toString() });
        console.log(`CreationSuccess Event, total: ${total.toString()}\tRedpacketId: ${id}  `);
    });
    
    let createRedPacketRecipt = await redPacket.create_redPacked(...Object.values(creationParams),{
        gasLimit: 1483507
    });
    await createRedPacketRecipt.wait();
    
    console.log('Create Red Packet successfully');
    
    await sleep();
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
});