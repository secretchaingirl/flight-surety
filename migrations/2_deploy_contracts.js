const FlightSuretyApp = artifacts.require("FlightSuretyApp");
const FlightSuretyData = artifacts.require("FlightSuretyData");
const fs = require('fs');

module.exports = async function(deployer, network, accounts) {

    const delta = accounts[1];      // 1st airline to be bootstrapped in contracts

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

                    return FlightSuretyData.deployed()
                        .then(async (dataInstance) => {
                            await dataInstance.authorizeCaller(FlightSuretyApp.address);
                            console.log('FlightSuretyApp contract address authorized as caller of FlightSuretyData contract');

                            // Finish contract setup by bootstrapping:
                            //  - add 1st airline
                            //  - vote for 1st airline
                            //  - approve 1st airline (registered)
                            await dataInstance.addAirline(delta, "Delta Airlines");
                            await dataInstance.addVote(delta);
                            await dataInstance.approveAirline(delta);
                            console.log('Initial airline registered and funded(Delta)');

                            await dataInstance.addFlight(
                                                            delta,
                                                            "DL3558",
                                                            "GRR",
                                                            (Date.parse("2019-06-02T01:30")/1000),
                                                            "MLE",
                                                            (Date.parse("2019-06-03T07:00")/1000)
                                                        );

                            await dataInstance.addFlight(
                                                            delta,
                                                            "DL3859",
                                                            "GRR",
                                                            (Date.parse("2019-06-02T10:05")/1000),
                                                            "MLE",
                                                            (Date.parse("2019-06-03T07:00")/1000)
                                                        );

                            await dataInstance.addFlight(
                                                            delta,
                                                            "DL7850",
                                                            "GRR",
                                                            (Date.parse("2019-06-02T08:00")/1000),
                                                            "MLE",
                                                            (Date.parse("2019-06-03T07:00")/1000)
                                                        );

                            await dataInstance.addFlight(
                                                            delta,
                                                            "DL850",
                                                            "GRR",
                                                            (Date.parse("2019-06-02T06:00")/1000),
                                                            "MLE",
                                                            (Date.parse("2019-06-03T07:00")/1000)
                                                        );

                            // Get App contract instance and submit funding for 1st airline
                            return FlightSuretyApp.deployed()
                                .then(async (appInstance) => {
                                    await appInstance.fundAirline({from: delta, value: web3.utils.toWei('10', 'ether')});
                                    console.log('Initial airline funded with 10 ether');
                                });
                        });
                });
        });
}