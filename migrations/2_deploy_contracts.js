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
                            console.log('FlightSuretyApp contract address authorized as caller of FlightSuretyData contract\n');

                            // Finish contract setup by bootstrapping:
                            //  - add 1st airline
                            //  - vote for 1st airline
                            //  - approve 1st airline (registered)
                            await dataInstance.addAirline(delta, "Delta Airlines");
                            await dataInstance.addVote(delta);
                            await dataInstance.approveAirline(delta);
                            await dataInstance.addFunds(delta);
                            console.log('Initial airline registered and funded with 10 ether (Delta)\n');

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

                            await dataInstance.addFlight(
                                                            delta,
                                                            "DL2023",
                                                            "GRR",
                                                            (Date.parse("2019-06-02T06:00")/1000),
                                                            "MLE",
                                                            (Date.parse("2019-06-03T07:00")/1000)
                                                        );

                            let startNonce = 1;
                            let endNonce = 5;

                            let flightList = await dataInstance.getFlightList.call
                                                                            (
                                                                                delta, 
                                                                                startNonce, 
                                                                                endNonce, 
                                                                                {from: FlightSuretyApp.address}
                                                                            );

                            console.log('Initial airline flights registered (Delta)');
                            console.log('-----------------------------------');
                            console.log(JSON.stringify(flightList));
                            console.log('-----------------------------------\n');
                        });
                });
        });
}