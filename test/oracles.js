
var Test = require('../config/testConfig.js');
const truffleAssert = require('truffle-assertions');

contract('Oracles', async (accounts) => {

    const TEST_ORACLES_COUNT = 20;
    var config;                   // test configuration
    var flightKey;                // Hash of flight code and other info to generate key

    const delta = accounts[1];    // Delta Airlines

    let fundAmount = web3.utils.toWei('10', 'ether');

    const flightStatusCodes = [ 0, 10, 20, 30, 40, 50 ];

    before('setup contract', async () => {
        config = await Test.Config(accounts);

        // Boostrap the test with an initial airline
        await config.flightSuretyData.addAirline(delta, "Delta Airlines");
        await config.flightSuretyData.addVote(delta);
        await config.flightSuretyData.approveAirline(delta);

        // Use the App contract to fund 1st airline
        await config.flightSuretyApp.fundAirline(fundAmount, {from: delta, value: fundAmount});

        // Register a Delta flight
        try {
            let payload = {
                code: 'DL3893',
                origin: 'GRR',
                departure: Math.floor(Date.now() / 1000),
                destination: 'MLE',
                arrival: Math.floor(Date.now() / 1000)
            }

            let tx = await config.flightSuretyApp.registerFlight
                                                            (
                                                                payload.code,
                                                                payload.origin,
                                                                payload.departure,
                                                                payload.destination,
                                                                payload.arrival,
                                                                { from: delta, gas: 5000000}
                                                            );

            // Wait for the event
            truffleAssert.eventEmitted(tx, 'FlightRegistered', (ev) => {
                flightKey = ev.key;
                return delta === ev.airline;

            }, 'Flight registration event error.');
        }
        catch(e) {

        }
    });


    it('can register oracles', async () => {

        // ARRANGE
        let fee = await config.flightSuretyApp.REGISTRATION_FEE.call();

        // ACT
        for(let a = 1; a < TEST_ORACLES_COUNT; a++) {      
            let tx = await config.flightSuretyApp.registerOracle({ from: accounts[a], value: fee });

            // Wait for the event
            truffleAssert.eventEmitted(tx, 'OracleRegistered', (ev) => {
                return (ev.oracle === accounts[a]);

            }, 'Oracle Registration event error.');

            // Enable for debugging
            //let result = await config.flightSuretyApp.getMyIndexes.call({from: accounts[a]});
            //console.log(`Oracle Registered: ${result[0]}, ${result[1]}, ${result[2]}`);
        }
    });

    it('can request flight status', async () => {

        // ARRANGE
        let timestamp = Math.floor(Date.now() / 1000);
        // Submit a request for oracles to get status information for a flight
        let tx = await config.flightSuretyApp.fetchFlightStatus(delta, flightKey, timestamp);

        // ACT
        truffleAssert.eventEmitted(tx, 'OracleRequest', (ev) => {
            return true;
        }, 'Oracle Request event error.');

        // Since the Index assigned to each test account is opaque by design
        // loop through all the accounts and for each account, all its Indexes
        // and submit a response. The contract will reject a submission if it was
        // not requested so while sub-optimal, it's a good test of that feature

        let statusIdx = 2;      // Start with late status
        for(let a = 1; a < TEST_ORACLES_COUNT; a++) {
            // Get oracle information
            let oracleIndexes = await config.flightSuretyApp.getMyIndexes.call({ from: accounts[a]});

            try {

                // Submit a response...it will only be accepted if there is an Index match
                let tx = await config.flightSuretyApp.submitOracleResponse
                                                            (
                                                                oracleIndexes,
                                                                delta,
                                                                flightKey,
                                                                timestamp,
                                                                flightStatusCodes[statusIdx],
                                                                { from: accounts[a] }
                                                            );

                truffleAssert.eventEmitted(tx, 'FlightStatusInfo', (ev) => {
                    return(ev.airline === delta && ev.key === flightKey && ev.statusCode == flightStatusCodes[statusId]);
                }, 'Flight Status Info event error.');

                //console.log(`Oracle response accepted: ${oracleIndexes}, ${flightStatusCodes[statusIdx]}, flightKey = ${flightKey}`);
                statusIdx++;

                // Trying to cycle through the different flight status codes for variability in the test
                if (statusIdx > 5) {
                    statusIdx = 0;
                }
            }
            catch(e) {
                //console.log(`OK - Oracle response rejected: ${oracleIndexes}, flightKey = ${flightKey}`);
            }
        }
    });

    // end of Tests
});
