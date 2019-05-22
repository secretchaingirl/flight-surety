
import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import Config from './config.json';
import Web3 from 'web3';
import express from 'express';

class Contract {

    constructor(network) {
        let config = Config[network];

        this.web3 = new Web3(new Web3.providers.WebsocketProvider(config.url.replace('http', 'ws')));
        this.web3.eth.defaultAccount = this.web3.eth.accounts[0];

        this.flightSuretyApp = new this.web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);

        this.oracles = [];
    }

    initialize() {
        let self = this;
        self.flightSuretyApp.events.OracleRequest({
            toBlock: 'latest',
            fromBlock: 'latest'
        }, function (error, ev) {
            if (error) console.log(error);
            let payload = {
                indexes: ev.returnValues.indexes,
                airline: ev.returnValues.airline,
                key: ev.returnValues.key,
                timestamp: ev.returnValues.timestamp
            }
            self.oracleRequest(payload.indexes, payload.airline, payload.key, payload.timestamp);
        });
    }

    oracleRequest = (async (indexes, airline, key, timestamp) => {
        console.log(`OracleRequest: (${indexes}, ${airline}, ${key}, ${timestamp})`);
        let self = this;

        for (let o = 0; o < self.oracles.length; o++) {
            let matches = 0;
            for (let i = 0; i < 3; i++) {
                if (indexes[i] === self.oracles[o].indexes[0] ||
                    indexes[i] === self.oracles[o].indexes[1] ||
                    indexes[i] === self.oracles[o].indexes[2]) {
                        matches++;
                }
            }
            if (matches >= 1) {
                // This Oracle's indexes match at least (1) of the indexes from the FlightSuretyApp oracle request
                console.log(`Oracle (${self.oracles[o].address}) - index match: ${self.oracles[o].indexes}`);

                //
                // Generate one of the flight status codes:
                //  Unknown (0)
                //  On Time (10)
                //  Late Airline (20)
                //  Late Weather (30)
                //  Late Technical (40)
                //  Late Other (50)
                let status = Math.floor(Math.random() * 5) * 10; 

                try {
                    // Submit Oracle response
                    self.flightSuretyApp.methods.submitOracleResponse
                            (
                                self.oracles[o].indexes,
                                airline,
                                key,
                                timestamp,
                                status
                            ).send({ from: self.oracles[o].address, gas: 500000 }, (error, result) => {
                                let oracle_msg = `(${self.oracles[o].address}, ${self.oracles[o].indexes}, - ${status})`;
                                if (error) {
                                    //console.log(error);
                                    console.log(`Oracle response rejected: ${oracle_msg}`);
                                }
                                
                                else {
                                    console.log(`Oracle response accepted: ${oracle_msg}`);
                                }
                            });   
                }
                catch(e) {
                    console.log(e.message);
                }
            }
        }
    });

    registerOracles = (async () => {
        let self = this;
        let fee = await self.flightSuretyApp.methods.REGISTRATION_FEE.call();
    
        let accounts = await self.web3.eth.getAccounts();

        for(let i = 10; i < 40; i++) { 
            self.flightSuretyApp.methods.registerOracle.send
                    (
                        { 
                            from: accounts[i],
                            gas: 5000000,
                            value: fee
                        }, 
                        async (error, result) => {
                            if (error) console.log(error);
                            else {
                                let result = await self.flightSuretyApp.methods.getMyIndexes.call({from: accounts[i]});
                                console.log(`Oracle Registered: (${accounts[i]}) - ${result[0]}, ${result[1]}, ${result[2]}`);

                                // Persist Oracles in memory
                                self.oracles.push({ address: accounts[i], indexes: result});
                            }
                    });
            
        }
    });

}

//
// Create express app server
//
const app = express();

//
// Initialize contract and setup event watching
//
const contract = new Contract('localhost');
contract.initialize();

app.get('/', (req, res) => {
    res.send
        (
            '<H1>Welcome to the FlightSurety Oracle server app!</H1>' +
            '<p>To get started, tell the Oracles to register with the FlightSuretyApp contract: api/oracles/register.</p>'
        )
})

app.get('/api', (req, res) => {
    res.send({
        message: 'Route options: api/oracles/register'
    })
})

app.get('/api/oracles/register', (req, res) => {
    try {
        contract.registerOracles();
        res.send({ message: 'OK - RegisterOracles request received'})
    } catch (e) {
        res.status(500).send(e.message);
    }
})

app.use((err, req, res, next) => {
    console.error(err.stack)
    res.status(500).send('Server error')
  })

export default app;
