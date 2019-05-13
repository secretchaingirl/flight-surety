pragma solidity ^0.5.8;

library FlightSuretyLibrary {

    // Flight info
    struct Flight {
            uint nonce;
            bytes32 key;
            string code;
            string origin;
            uint256 departureTimestamp;
            string destination;
            uint256 arrivalTimestamp;
            uint8 statusCode;
    }

    // Struct for managing Flight Insurance per Passenger
    //
    struct FlightInsurance {
        uint purchased;
        uint payout;
        bool isInsured;
        bool isCredited;
        bool isWithdrawn;
    }

}