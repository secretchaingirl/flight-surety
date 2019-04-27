
var Test = require('../config/testConfig.js');
var BigNumber = require('bignumber.js');

contract('Flight Surety Tests', async (accounts) => {

  var config;
  before('setup contract', async () => {
    config = await Test.Config(accounts);

    // Boostrap the test with an initial airline
    await config.flightSuretyData.add(config.firstAirline, config.firstAirlineName);
    await config.flightSuretyData.vote(config.firstAirline);
    await config.flightSuretyData.approve(config.firstAirline);
    //await config.flightSuretyData.fund({from: accounts[1], value: web3.utils.toWei('10', 'ether')});
  });

  /****************************************************************************************/
  /* Operations and Settings                                                              */
  /****************************************************************************************/
  it(`(multiparty) has correct initial isOperational() value`, async function () {

    // Get operating status
    let status = await config.flightSuretyData.isOperational.call();
    assert.equal(status, true, "Incorrect initial operating status value");

  });

  it(`(multiparty) can block access to setOperatingStatus() for non-Contract Owner account`, async function () {

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

  it(`(multiparty) can allow access to setOperatingStatus() for Contract Owner account`, async function () {

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

  it(`(multiparty) can block access to functions using requireIsOperational when operating status is false`, async function () {

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
        registered = await config.flightSuretyData.isAirline.call(config.firstAirline, {from: config.flightSuretyApp.address});
    }
    catch(e) {

    }

    // ASSERT
    assert.equal(registered, true, "1st airline was not registered when deployed");

  });

  it('(airline) requires 50% of airlines for registration when there are more than 5', async () => {
    
    // ARRANGE
    let aa = accounts[2];
    let united = accounts[3];
    let spirit = accounts[4];
    let jetblue = accounts[5];
    let norwegian = accounts[6];

    // ACT
    try {
        await config.flightSuretyApp.register(aa, "American Airlines", {from: config.firstAirline});
        await config.flightSuretyApp.register(united, "United Airlines", {from: config.firstAirline});
        await config.flightSuretyApp.register(spirit, "Spirit", {from: config.firstAirline});
        await config.flightSuretyApp.register(jetblue, "Jet Blue", {from: config.firstAirline});
        await config.flightSuretyApp.register(norwegian, "Norwegian Airlines", {from: config.firstAirline});
    }
    catch(e) {
        console.log(e.message);
    }

    // ASSERT
    // < 5 
    let result = await config.flightSuretyData.isRegistered.call(aa, {from: config.flightSuretyApp.address}); 
    assert.equal(result, true, "New airline should be registered automatically if < 5 airlines already registered.");

    // M of N
    result = await config.flightSuretyData.isRegistered.call(norwegian, {from: config.flightSuretyApp.address}); 
    assert.equal(result, false, "Airline shouldn't be registered unless 50% of registered airlines have voted to approve.");

  });


  it('(airline) cannot register an Airline using registerAirline() if it is not funded', async () => {
    
    // ARRANGE
    let newAirline = accounts[7];

    // ACT
    try {
        await config.flightSuretyApp.registerAirline(newAirline, {from: config.firstAirline});
    }
    catch(e) {

    }
    let result = await config.flightSuretyData.isAirline.call(newAirline, {from: config.flightSuretyApp.address}); 

    // ASSERT
    assert.equal(result, false, "Airline should not be able to register another airline if it hasn't provided funding");

  });


});
