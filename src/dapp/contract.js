import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import Config from './config.json';
import Web3 from 'web3';

export default class Contract {
    constructor(network, callback) {

        let config = Config[network];
        //this.web3 = new Web3(new Web3.providers.HttpProvider(config.url));
        // Have to use web sockets to be able to watch for contract events
        this.web3 = new Web3(new Web3.providers.WebsocketProvider(config.url.replace('http', 'ws')));
        this.BN = this.web3.utils.BN;
        this.flightSuretyApp = new this.web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);
        this.owner = null;
        this.airlines = [];
        this.passengers = [];
        this.initialize(callback);
    }

    initialize(callback) {
        this.web3.eth.getAccounts()
            .then((accts) => {
                let self = this;
                self.owner = accts[0];

                let counter = 1;
                
                while(self.airlines.length < 5) {
                    self.airlines.push(accts[counter++]);
                }

                while(self.passengers.length < 5) {
                    self.passengers.push(accts[counter++]);
                }

                callback();
            });
    }

    // 
    // Define event methods - when triggered, then invoke the callback method with the error and event parameters
    //

    FlightRegistered(callback) {
        let self = this;
        self.flightSuretyApp.events.FlightRegistered({
            fromBlock: 'latest', 
            toBlock: 'latest'
          }, (error, event) => {
            callback(error, event);
        });
    }

    FlightInsurancePurchased(callback) {
        let self = this;
        self.flightSuretyApp.events.FlightInsurancePurchased({
            fromBlock: 'latest', 
            toBlock: 'latest'
          }, (error, event) => {
            callback(error, event);
        });
    }

    OracleRegistered(callback) {
        let self = this;
        self.flightSuretyApp.events.OracleRegistered({
            fromBlock: 'latest',
            toBlock: 'latest',
        }, (error, event) => {
            callback(error, event);
        });
    }

    OracleRequest(callback) {
        let self = this;
        self.flightSuretyApp.events.OracleRequest({
            fromBlock: 'latest',
            toBlock: 'latest',
        }, (error, event) => {
            callback(error, event);
        });
    }

    FlightStatusInfo(callback) {
        let self = this;
        self.flightSuretyApp.events.FlightStatusInfo({
            fromBlock: 'latest',
            toBlock: 'latest',
        }, (error, event) => {
            callback(error, event);
        });
    }

    FlightDelayed(callback) {
        let self = this;
        self.flightSuretyApp.events.FlightDelayed({
            fromBlock: 'latest',
            toBlock: 'latest',
        }, (error, event) => {
            callback(error, event);
        });
    }

    InsuredPassengerPayout(callback) {
        let self = this;
        self.flightSuretyApp.events.InsuredPassengerPayout({
            fromBlock: 'latest',
            toBlock: 'latest',
        }, (error, event) => {
            callback(error, event);
        });
    }

    PassengerInsuranceWithdrawal(callback) {
        let self = this;
        self.flightSuretyApp.events.PassengerInsuranceWithdrawal({
            fromBlock: 'latest',
            toBlock: 'latest',
        }, (error, event) => {
            callback(error, event);
        });
    }

    //
    // FlightSuretyApp contract calls
    //

    isOperational(callback) {
       let self = this;
       self.flightSuretyApp.methods
            .isOperational()
            .call({ from: self.owner}, callback);
    }

    getBalance(callback) {
        let self = this;
        self.flightSuretyApp.methods
            .getBalance()
            .call({from: self.owner}, (error, result) => {
                callback(error, this.web3.utils.toBN(result).toString());
            });
    }

    registerAirline(airline, name, callback) {
        let self = this;
        let payload = {
            airline: airline,
            name: name
        }

        self.flightSuretyApp.methods
            .registerAirline(payload.airline, payload.name)
            .send({ from: self.airlines[0], gas: 5000000}, (error, result) => {
                callback(error, result);
            });
    }

    fundAirline(airline, callback) {
        let self = this;
        let fundAmount = this.web3.utils.toWei('10', 'ether');

        self.flightSuretyApp.methods
            .fundAirline(fundAmount)
            .send({ from: airline, gas: 5000000, value: fundAmount}, (error, result) => {
                callback(error, result);
            });
    }

    registerFlight(airline, flight, origin, departure, destination, arrival, callback) {
        let self = this;
        let payload = {
            airline: airline,
            flight: flight,
            origin: origin,
            departure: (new Date(departure).getTime()/1000),
            destination: destination,
            arrival: (new Date(arrival).getTime()/1000)
        }

        self.flightSuretyApp.methods
            .registerFlight(payload.flight, payload.origin, payload.departure, payload.destination, payload.arrival)
            .send({ from: payload.airline, gas: 5000000}, (error, result) => {
                callback(error, result);
            });
    }

    getFlightList(airline, callback) {
        let self = this;
        let startNonce = 1;
        let endNonce = 5;

        self.flightSuretyApp.methods
            .getFlightList(airline, startNonce, endNonce)
            .call({ from: self.owner}, (error, result) => {
                callback(error, result);
            });
    }

    purchaseInsurance(key, amount, passenger, callback) {
        let self = this;

        let payload = {
            airline: self.airlines[0],
            key: key,
            amount: this.web3.utils.toWei(amount, 'ether'),
            passenger: passenger
        }

        // airline, key, amount
        self.flightSuretyApp.methods
            .buyFlightInsurance(payload.airline, payload.key, payload.amount)
            .send({ from: payload.passenger, value: payload.amount, gas: 5000000}, (error, result) => {
                callback(error, result);
            });
    }

    payFlightInsuree(key, passenger, callback) {
        let self = this;

        let payload = {
            airline: self.airlines[0],
            key: key,
            passenger: passenger
        } 

        // airline, key, amount
        self.flightSuretyApp.methods
            .payFlightInsuree(payload.airline, payload.key, payload.passenger)
            .send({ from: payload.passenger, gas: 5000000}, (error, result) => {
                callback(error, result);
            });
    }

    fetchFlightStatus(key, callback) {
        let self = this;

        let payload = {
            airline: self.airlines[0],
            key: key,
            timestamp: Math.floor(Date.now() / 1000)
        } 

        self.flightSuretyApp.methods
            .fetchFlightStatus(payload.airline, payload.key, payload.timestamp)
            .send({ from: self.owner, gas: 5000000}, (error, result) => {
                callback(error, payload);
            });
    }
}