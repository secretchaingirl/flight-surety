//import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
const Web3 = require('web3');

class Contract {

	constructor() {
		this.oracles = [];
		this.message = 'hello world!';
	}

	init() {
		let self = this;
		console.log(`self.oracles = ${self.oracles}, self.message = ${self.message}`);

		setTimeout(() => {
			console.log('timeout');
			console.log(`self.oracles = ${self.oracles}, self.message = ${self.message}`);
			self.oracleRequest();
		}, 1000);
		
	}

	oracleRequest() {
		let self = this;
		console.log('oracleRequest');
		console.log(`self.oracles = ${self.oracles}, self.message = ${self.message}`);

		for (let i = 0; i < self.oracles.length; i++) {
			console.log(self.oracles[i]);
		}
	}


}

let c = new Contract();
c.init();
