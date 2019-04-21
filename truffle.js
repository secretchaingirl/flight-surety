var HDWalletProvider = require("truffle-hdwallet-provider");
// truffle ganache 7545
var mnemonic = "urge stadium swap mind air busy return door infant reason industry garment";

module.exports = {
  networks: {
    development: {
        host: "localhost",
        port: 7545,
        network_id: "*" // Match any network id
    }
  },
  compilers: {
    solc: {
      version: "^0.4.24"
    }
  }
};