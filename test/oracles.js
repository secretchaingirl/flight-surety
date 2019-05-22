
var Test = require('../config/testConfig.js');
const truffleAssert = require('truffle-assertions');

contract('Oracles', async (accounts) => {

    const TEST_ORACLES_COUNT = 20;
    var config;                   // test configuration
    var flightKey;                // Hash of flight code and other info to generate key

    const delta = accounts[1];    // Delta Airlines

    let fundAmount = web3.utils.toWei('10', 'ether');

    // Watch contract events
    const STATUS_CODE_UNKNOWN = 0;
    const STATUS_CODE_ON_TIME = 10;
    const STATUS_CODE_LATE_AIRLINE = 20;
    const STATUS_CODE_LATE_WEATHER = 30;
    const STATUS_CODE_LATE_TECHNICAL = 40;
    const STATUS_CODE_LATE_OTHER = 50;

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
            console.log(e);
        }
    });


    it('can register oracles', async () => {

        // ARRANGE
        let fee = await config.flightSuretyApp.REGISTRATION_FEE.call();

        // ACT
        for(let a = 1; a < TEST_ORACLES_COUNT; a++) {      
            await config.flightSuretyApp.registerOracle({ from: accounts[a], value: fee });
            let result = await config.flightSuretyApp.getMyIndexes.call({from: accounts[a]});
            console.log(`Oracle Registered: ${result[0]}, ${result[1]}, ${result[2]}`);
        }
    });

    it('can request flight status', async () => {

        // ARRANGE
        let timestamp = Math.floor(Date.now() / 1000);

        // Submit a request for oracles to get status information for a flight
        await config.flightSuretyApp.fetchFlightStatus(delta, flightKey, timestamp);
        // ACT

        // Since the Index assigned to each test account is opaque by design
        // loop through all the accounts and for each account, all its Indexes
        // and submit a response. The contract will reject a submission if it was
        // not requested so while sub-optimal, it's a good test of that feature

        for(let a = 1; a < TEST_ORACLES_COUNT; a++) {

            // Get oracle information
            let oracleIndexes = await config.flightSuretyApp.getMyIndexes.call({ from: accounts[a]});
            for(let idx = 0;idx < 3;idx++) {

                try {
                    // Submit a response...it will only be accepted if there is an Index match
                    await config.flightSuretyApp.submitOracleResponse
                                                                (
                                                                    oracleIndexes[idx],
                                                                    delta,
                                                                    flightKey,
                                                                    timestamp,
                                                                    STATUS_CODE_ON_TIME,
                                                                    { from: accounts[a] }
                                                                );
                }
                catch(e) {
                    // Enable this when debugging
                    // console.log('\nError', idx, oracleIndexes[idx].toNumber(), flightKey, timestamp);
                }
            }
        }
    });

    // end of Tests
});
