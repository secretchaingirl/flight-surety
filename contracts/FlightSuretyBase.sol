pragma solidity ^0.5.8;

// FlightSurety base contract that contains common data structures, methods, etc.

contract FlightSuretyBase {

    struct Flight {
            uint nonce;
            bytes32 key;
            string flight;
            string origin;
            uint256 departureTimestamp;
            string destination;
            uint256 arrivalTimestamp;
            uint8 statusCode;
    }

    struct FlightInsurance {
        address airline;
        uint flightNonce;
        uint insuranceAmount;
        uint amountCredited;
        bool isInsured;
        bool isPaid;
        bool isWithdrawn;
    }
}