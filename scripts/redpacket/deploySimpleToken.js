const {ethers} = require('hardhat');
const {saveRedpacketDeployment} = require('../../utils');

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log('Deploying contract with the account:', deployer.address);

    const Token = await ethers.getContractFactory('SimpleToken');
    const token = await Token.deploy('RedToken', 'RT', 18, 1000000);
    await token.waitForDeployment();
    console.log('RedToken contract address is:', token.target);

    let balance = await token.balanceOf(deployer.address);
    console.log(`balance of deployer ${balance.toString()}`);
  
    saveRedpacketDeployment({
      simpleTokenAddress: token.target,
    });
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });