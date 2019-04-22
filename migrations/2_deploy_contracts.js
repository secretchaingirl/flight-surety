const FlightSuretyApp = artifacts.require("FlightSuretyApp");
const FlightSuretyData = artifacts.require("FlightSuretyData");
const fs = require('fs');

module.exports = async function(deployer, network, accounts) {

    const airLine = 'Delta';

    deployer.deploy(FlightSuretyData)
        .then(() => {
            // Deploy App contract with the data for the 1st airline
            return deployer.deploy(FlightSuretyApp, FlightSuretyData.address)
                .then(() => {
                    // Setup dapp and oracle config
                    let config = {
                        localhost: {
                            url: 'http://localhost:7545',
                            dataAddress: FlightSuretyData.address,
                            appAddress: FlightSuretyApp.address
                        }
                    }

                    fs.writeFileSync(__dirname + '/../src/dapp/config.json',JSON.stringify(config, null, '\t'), 'utf-8');
                    fs.writeFileSync(__dirname + '/../src/server/config.json',JSON.stringify(config, null, '\t'), 'utf-8');

                    console.log('Dapp and Oracle configurations deployed');

                    // Finish contract setup by:
                    //  - get data contract instance
                    //  - add the 1st airline to the data contract to bootstrap
                    //  - authorize app contract as caller of the data contract
                    return FlightSuretyData.deployed()
                        .then((dataInstance) => {
                            return dataInstance.authorizeCaller(FlightSuretyApp.address)
                                .then(async () => {

                                    console.log('FlightSuretyApp contract address authorized as caller of data contract');

                                    await dataInstance.add(accounts[1], airLine)
                                    console.log(`${accounts[1]} - airline added (${airLine})`);

                                    await dataInstance.vote(accounts[1]);
                                    console.log('1 vote');

                                    await dataInstance.approve(accounts[1]);
                                    console.log('Approved.');
                                });
                        });
                });
        });
}