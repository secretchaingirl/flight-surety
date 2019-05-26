
var Test = require('../config/testConfig.js');
const truffleAssert = require('truffle-assertions');
const BN = web3.utils.BN;

contract('Flight Surety Tests', async (accounts) => {

  var config;
  let fundAmount = web3.utils.toWei('10', 'ether');
  let insuranceAmount = web3.utils.toWei('.833', 'ether');
  let tooMuchInsurance = web3.utils.toWei('2.8', 'ether');

  let delta = accounts[1];
  let aa = accounts[2];
  let united = accounts[3];
  let spirit = accounts[4];
  let jetblue = accounts[5];
  let norwegian = accounts[6];
  let alaskan = accounts[7];
  let british = accounts[8];
  let unregistered = accounts[9];
  let passenger1 = accounts[10];
  let passenger2 = accounts[11];
  let passenger3 = accounts[12];
  let passenger4 = accounts[13];

  before('setup contract', async () => {
    config = await Test.Config(accounts);

    // Boostrap the test with an initial airline
    await config.flightSuretyData.addAirline(delta, "Delta Airlines");
    await config.flightSuretyData.addVote(delta);
    await config.flightSuretyData.approveAirline(delta);

    // Use the App contract to fund 1st airline
    await config.flightSuretyApp.fundAirline(fundAmount, {from: delta, value: fundAmount});
  });

  /****************************************************************************************/
  /* Operations and Settings                                                              */
  /****************************************************************************************/
  it(`(operational) has correct initial isOperational() value`, async function () {

    // Get operating status
    let status = await config.flightSuretyData.isOperational.call();
    assert.equal(status, true, "Incorrect initial operating status value");

  });

  it(`(operational) can block access to setOperatingStatus() for non-Contract Owner account`, async function () {

      // Ensure that access is denied for non-Contract Owner account
      let accessDenied = false;
      try 
      {
          await config.flightSuretyData.setOperatingStatus(false, { from: config.testAddresses[2] });
      }
      catch(e) {
          accessDenied = true;
      }
      assert.equal(accessDenied, true, "Access not restricted to Contract Owner");
            
  });

  it(`(operational) can allow access to setOperatingStatus() for Contract Owner account`, async function () {

      // Ensure that access is allowed for Contract Owner account
      let accessDenied = false;
      try 
      {
          await config.flightSuretyData.setOperatingStatus(false);
      }
      catch(e) {
          accessDenied = true;
      }
      assert.equal(accessDenied, false, "Access not restricted to Contract Owner");
      
  });

  it(`(operational) can block access to functions using requireIsOperational when operating status is false`, async function () {

      await config.flightSuretyData.setOperatingStatus(false);

      let reverted = false;
      try 
      {
          await config.flightSuretyApp.setTestingMode(true);
      }
      catch(e) {
          reverted = true;
      }
      finally {
        // Set it back for other tests to work
        await config.flightSuretyData.setOperatingStatus(true);
      }

      assert.equal(reverted, true, "Access not blocked for requireIsOperational");      
  });

  it('(airline) 1st airline was registered when contract was deployed', async () => {

    // ARRANGE
    let registered = false;
    // ACT
    try {
        registered = await config.flightSuretyData.isAirline.call(delta, {from: config.flightSuretyApp.address});
    }
    catch(e) {

    }

    // ASSERT
    assert.equal(registered, true, "1st airline was not registered when deployed");

  });

  it('(airline) 1st airline was funded when contract was deployed', async () => {

    // ARRANGE
    let funded = false;
    // ACT
    try {
        funded = await config.flightSuretyData.isFunded.call(delta, {from: config.flightSuretyApp.address});
    }
    catch(e) {

    }

    // ASSERT
    assert.equal(funded, true, "1st airline was not funded when deployed");

  });

  it('(airline) registered airline cannot participate until funded', async () => {

    // ARRANGE
    let flight = true;

    // ACT
    try {
        await config.flightSuretyApp.registerAirline(aa, "American Airlines", {from: delta});
        await config.flightSuretyApp.registerFlight.call(
                                                            aa,
                                                            "AA4988",
                                                            "GRR",
                                                            "2019-06-01T08:30",
                                                            "MLE",
                                                            "2019-06-30T13:55",
                                                            {from: aa}
                                                        );
    }
    catch(e) {
        flight = false;
    }
    finally {
        await config.flightSuretyApp.fundAirline(fundAmount, {from: aa, value: fundAmount});
    }

    // ASSERT
    assert.equal(flight, false, "Airline can't participate until funded with 10 ether");

  });


  it('(airline) requires 50% of airlines for registration when there are more than 5', async () => {
    
    // ARRANGE
    // n/a

    // ACT
    try {        
        await config.flightSuretyApp.registerAirline(united, "United Airlines", {from: delta});
        await config.flightSuretyApp.fundAirline(fundAmount, {from: united, value: fundAmount});

        await config.flightSuretyApp.registerAirline(spirit, "Spirit", {from: delta});
        await config.flightSuretyApp.fundAirline(fundAmount, {from: spirit, value: fundAmount});

        await config.flightSuretyApp.registerAirline(jetblue, "JetBlue", {from: delta});
        await config.flightSuretyApp.registerAirline(norwegian, "Norwegian Airlines", {from: delta});
        await config.flightSuretyApp.registerAirline(alaskan, "Alaskan Airlines", {from: delta});

        // Add votes to satisfy 50% and trigger registration approval for Jet Blue (6th airline)
        await config.flightSuretyApp.voteForAirline(norwegian, {from: aa});
        await config.flightSuretyApp.voteForAirline(norwegian, {from: united});
    }
    catch(e) {

    }
   
    // ASSERT
    // < 5 should be automatically registered
    let result = await config.flightSuretyData.isRegistered.call(aa, {from: config.flightSuretyApp.address}); 
    assert.equal(result, true, "New airline should be registered automatically if < 5 airlines already registered.");

    result = await config.flightSuretyData.isRegistered.call(united, {from: config.flightSuretyApp.address}); 
    assert.equal(result, true, "New airline should be registered automatically if < 5 airlines already registered.");

    result = await config.flightSuretyData.isRegistered.call(spirit, {from: config.flightSuretyApp.address}); 
    assert.equal(result, true, "New airline should be registered automatically if < 5 airlines already registered.");

    result = await config.flightSuretyData.isRegistered.call(jetblue, {from: config.flightSuretyApp.address}); 
    assert.equal(result, true, "New airline should be registered automatically if < 5 airlines already registered.");
    
    // M of N - 50% votes or more should trigger registration
    result = await config.flightSuretyData.isRegistered.call(norwegian, {from: config.flightSuretyApp.address}); 
    assert.equal(result, true, "New airline should be registered automatically when M of N voting is satisfied.");

    // M of N - less than 50% votes and airline should note be registered
    result = await config.flightSuretyData.isRegistered.call(alaskan, {from: config.flightSuretyApp.address}); 
    assert.equal(result, false, "Airline shouldn't be registered unless 50% of registered airlines have voted to approve.");

  });


  it('(airline) registered airline cannot submit less than 10 ether for funding', async () => {

    // ARRANGE
    let funded = true;

    // ACT
    try {
        await config.flightSuretyApp.fundAirline(fundAmount - 1, {from: jetblue, value: fundAmount - 1});
    }
    catch(e) {
        funded = false;
    }

    // ASSERT
    assert.equal(funded, false, "Airline was funded with < 10 ether");

  });


  it('(airline) cannot vote for an Airline if caller is not funded', async () => {
    
    // ARRANGE
    // n/a

    // ACT
    try {
        await config.flightSuretyApp.voteForAirline(british, {from: norwegian});
    }
    catch(e) {

    }

    let airline = await config.flightSuretyData.isAirline.call(british, {from: config.flightSuretyApp.address});
    let registered = await config.flightSuretyData.isRegistered.call(british, {from: config.flightSuretyApp.address});

    // ASSERT
    assert.equal
        (
            airline == false && registered == false, 
            true, 
            "Airline should not be able to vote for an airline if it hasn't provided funding"
        );

  });

  it('(flights) non-registered airline cannot register a flight', async () => {
    // ARRANGE
    let success = true;

    let payload = {
        flight: 'UNKNOWN',
        origin: 'UNK',
        departure: Math.floor(Date.now() / 1000),
        destination: 'UNK',
        arrival: Math.floor(Date.now() / 1000)
    }

    var tx;

    // ACT
    try {
        tx = await config.flightSuretyApp.registerFlight
                                                            (
                                                                payload.flight,
                                                                payload.origin,
                                                                payload.departure,
                                                                payload.destination,
                                                                payload.arrival,
                                                                { from: unregistered, gas: 5000000}
                                                            );

    } catch {
        success = false;
    } finally {
        // ASSERT
        assert.equal(success, false, "Unregistered flight was able to add a flight.");
    }

  });

  it('(flights) can register a flight for the airline', async () => {

    // ARRANGE
    var key;
    var nonce;

    let payload = {
        code: 'DL3893',
        origin: 'GRR',
        departure: Math.floor(Date.now() / 1000),
        destination: 'MLE',
        arrival: Math.floor(Date.now() / 1000)
    }

    // ACT
    try {
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
            nonce = ev.nonce;
            key = ev.key;

            return delta === ev.airline;

        }, 'Flight registration event error.');
    }
    catch(e) {

    }

    let isFlight = await config.flightSuretyData.isFlight.call(delta, key, {from: config.flightSuretyApp.address});
    let flightInfo = await config.flightSuretyData.getFlight.call(delta, key, {from: config.flightSuretyApp.address});

    // ASSERT
    assert(isFlight, "Delta flight should have been registered.");
    
    // Check all flight info data
    assert.equal(flightInfo.nonce, nonce, "Flight Nonce should be 1.");
    assert.equal(flightInfo.code, payload.code, "Flight # should match.");
    assert.equal(flightInfo.origin, payload.origin, "Flight Origin should match.");
    assert.equal(flightInfo.departureTimestamp, payload.departure, "Flight Departure time should match.");
    assert.equal(flightInfo.destination, payload.destination, "Flight Destination should match.");
    assert.equal(flightInfo.arrivalTimestamp, payload.arrival, "Flight Arrival time should match.");
    assert.equal(flightInfo.statusCode, 0, "Flight status code should be Unknown (0)");
  });


  it('(insurance) passenger can buy flight insurance', async () => {

    // ARRANGE
    let nonce = 1;
    var key;

    // ACT
    try {
        // Get 1st Delta flight
        key = await config.flightSuretyData.getFlightKey.call(delta, nonce, {from: config.flightSuretyApp.address});

        let tx = await config.flightSuretyApp.buyFlightInsurance
                                                            (
                                                                delta,
                                                                key,
                                                                insuranceAmount,
                                                                { from: passenger1, value: insuranceAmount, gas: 5000000}
                                                            );                                                 

        // Wait for the event
        truffleAssert.eventEmitted(tx, 'FlightInsurancePurchased', (ev) => {
            // Verify all emitted data matches
            return passenger1 === ev.passenger && 
                    delta === ev.airline && 
                    key === ev.key && 
                    insuranceAmount === ev.amount.toString();

        }, 'Flight insurance purchased event error.');
    }
    catch(e) {

    }

    // ASSERT
    let insurance = await config.flightSuretyData.getPassengerInsurance.call(delta, key, passenger1, {from: config.flightSuretyApp.address});
    
    assert.equal(insuranceAmount, insurance[0], "Flight insurance amount not correct.");
    assert.equal("0", insurance[1], "Flight Insurance payout should be 0.");
    assert.equal(true, insurance[2], "Passenger isn't insured.");
    assert.equal(false, insurance[3], "Passenger insurance shouldn't be credited.");
    assert.equal(false, insurance[4], "Passenger insurance hasn't been withdrawn");
  });

  it('(insurance) passenger can buy flight insurance ONLY once', async () => {

    // ARRANGE
    let nonce = 1;
    var key;

    // ACT
    try {
        // Get 1st Delta flight
        key = await config.flightSuretyData.getFlightKey.call(delta, nonce, {from: config.flightSuretyApp.address});

        let tx = await config.flightSuretyApp.buyFlightInsurance
                                                            (
                                                                delta,
                                                                key,
                                                                insuranceAmount,
                                                                { from: passenger1, value: insuranceAmount, gas: 5000000}
                                                            );                                                 
        
        // Wait for the event
        truffleAssert.eventEmitted(tx, 'FlightInsurancePurchased', (ev) => {
            return false;

        }, 'Flight insurance purchased event should not have been emitted.');
    }
    catch(e) {

    }

    // ASSERT
    let insurance = await config.flightSuretyData.getPassengerInsurance.call(delta, key, passenger1, {from: config.flightSuretyApp.address});
    
    assert.equal(insuranceAmount, insurance[0], "Flight insurance amount should be the same.");
  });

  it('(insurance) can get list of insured passengers for flight', async () => {

    // ARRANGE
    let nonce = 1;
    var key;

    // ACT
    try {
        // Get 1st Delta flight
        key = await config.flightSuretyData.getFlightKey.call(delta, nonce, {from: config.flightSuretyApp.address});
                                                            
        await config.flightSuretyApp.buyFlightInsurance
                                                    (
                                                        delta,
                                                        key,
                                                        insuranceAmount,
                                                        { from: passenger2, value: insuranceAmount, gas: 5000000}
                                                    ); 

        // Wait for the event
        truffleAssert.eventEmitted(tx, 'FlightInsurancePurchased', (ev) => {
            // Verify all emitted data matches
            return passenger1 === ev.passenger && 
                    delta === ev.airline && 
                    key === ev.key && 
                    insuranceAmount === ev.amount.toString();

        }, 'Flight insurance purchased event error.');

        await config.flightSuretyApp.buyFlightInsurance
                                                    (
                                                        delta,
                                                        key,
                                                        insuranceAmount,
                                                        { from: passenger3, value: insuranceAmount, gas: 5000000}
                                                    );

        // Wait for the event
        truffleAssert.eventEmitted(tx, 'FlightInsurancePurchased', (ev) => {
            // Verify all emitted data matches
            return passenger1 === ev.passenger && 
                    delta === ev.airline && 
                    key === ev.key && 
                    insuranceAmount === ev.amount.toString();

        }, 'Flight insurance purchased event error.');
    }
    catch(e) {

    }

    // ASSERT
    let insurees = await config.flightSuretyData.getInsuredPassengers.call(delta, key, {from: config.flightSuretyApp.address});
    assert.equal(insurees[0], passenger1, "Passenger1 is not in the flight insurees list");
    assert.equal(insurees[1], passenger2, "Passenger2 is not in the flight insurees list");
  });

  it('(insurance) passenger cannot buy flight insurance for more than 1 ether', async () => {

    // ARRANGE
    let nonce = 1;
    let purchased = true;

    // ACT
    try {
        // Get 1st Delta flight
        let flightKey = await config.flightSuretyData.getFlightKey.call(delta, nonce, {from: config.flightSuretyApp.address});

        await config.flightSuretyApp.buyFlightInsurance
                                                            (
                                                                delta,
                                                                flightKey,
                                                                tooMuchInsurance,
                                                                { from: passenger4, value: insuranceAmount, gas: 5000000}
                                                            );
    }
    catch {
        purchased = false;
    }

    // ASSERT
    assert.equal(purchased, false, "Passenger was able to buy more than 1 ether in flight insurance.");

  });

});
