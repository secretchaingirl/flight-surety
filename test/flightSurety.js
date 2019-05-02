
var Test = require('../config/testConfig.js');
var BigNumber = require('bignumber.js');

contract('Flight Surety Tests', async (accounts) => {

  var config;

  let delta = accounts[1];
  let aa = accounts[2];
  let united = accounts[3];
  let spirit = accounts[4];
  let jetblue = accounts[5];
  let norwegian = accounts[6];
  let alaskan = accounts[7];
  let british = accounts[8];

  before('setup contract', async () => {
    config = await Test.Config(accounts);

    // Boostrap the test with an initial airline
    await config.flightSuretyData.addAirline(delta, "Delta Airlines");
    await config.flightSuretyData.addVote(delta);
    await config.flightSuretyData.approveAirline(delta);

    // Use the App contract to fund 1st airline
    await config.flightSuretyApp.fundAirline({from: delta, value: web3.utils.toWei('10', 'ether')});
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
        await config.flightSuretyApp.fundAirline({from: aa, value: web3.utils.toWei('10', 'ether')});
    }

    // ASSERT
    assert.equal(flight, false, "Airline can't participate until funded with 10 ether");

  });

  it('(airline) requires 50% of airlines for registration when there are more than 5', async () => {
    
    // ARRANGE

    // ACT
    try {        
        await config.flightSuretyApp.registerAirline(united, "United Airlines", {from: delta});
        await config.flightSuretyApp.fundAirline({from: united, value: web3.utils.toWei('10', 'ether')});

        await config.flightSuretyApp.registerAirline(spirit, "Spirit", {from: delta});
        await config.flightSuretyApp.fundAirline({from: spirit, value: web3.utils.toWei('10', 'ether')});

        await config.flightSuretyApp.registerAirline(jetblue, "JetBlue", {from: delta});
        await config.flightSuretyApp.registerAirline(norwegian, "Norwegian Airlines", {from: delta});
        await config.flightSuretyApp.registerAirline(alaskan, "Alaskan Airlines", {from: delta});

        // Add votes to satisfy 50% and trigger registration approval for Jet Blue (6th airline)
        await config.flightSuretyApp.voteForAirline(norwegian, {from: aa});
        await config.flightSuretyApp.voteForAirline(norwegian, {from: united});
    }
    catch(e) {
        console.log(e.message);
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

});
