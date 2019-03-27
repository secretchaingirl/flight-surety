var HDWalletProvider = require("truffle-hdwallet-provider");
var mnemonic = "urge stadium swap mind air busy return door infant reason industry garment";

module.exports = {
  networks: {
    development: {
      provider: function() {
        return new HDWalletProvider(mnemonic, "http://127.0.0.1:7545/", 0, 50);
      },
      network_id: '*',
//      gas: 9999999
    }
  },
  compilers: {
    solc: {
      version: "^0.4.24"
    }
  }
};