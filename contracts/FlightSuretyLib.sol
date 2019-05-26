pragma solidity ^0.5.8;

library FlightSuretyLib {

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

    // Airline info which includes mapping for associated flights
    struct Airline {
        uint nonce;                                             // Airline nonce or unique #
        string name;
        bool registered;
        bool funded;
        uint votes;
        uint flightNonce;                                       // to keep track of current # of registered flights for the Airline
        mapping(uint => bytes32) flightKeys;                    // mapping for flight index to flight key
        mapping(bytes32 => Flight) flights;
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

    struct FlightSurety {
        // Mapping for airline account and all relevant info, including flights
        //      Airline => Airline Struct
        //
        mapping(address => Airline) airlines;

        // Mapping for flight insurees
        //      Airline => (Flight => (Passenger => FlightInsurance))
        mapping(address => mapping(bytes32 => mapping(address => FlightSuretyLib.FlightInsurance))) flightInsurees;

        // Mapping for flight passengers with insurance
        mapping(address => mapping(bytes32 => address[])) insuredPassengers;
    }


    // Flight status codes

    function STATUS_CODE_UNKNOWN() external pure returns(uint8 code) {
        return 0;
    }


    function STATUS_CODE_ON_TIME() external pure returns(uint8 code) {
        return 10;
    }


    function STATUS_CODE_LATE_AIRLINE() external pure returns(uint8 code) {
        return 20;
    }


    function STATUS_CODE_LATE_WEATHER() external pure returns(uint8 code) {
        return 30;
    }


    function STATUS_CODE_LATE_TECHNICAL() external pure returns(uint8 code) {
        return 40;
    }


    function STATUS_CODE_LATE_OTHER() external pure returns(uint8 code) {
        return 50;
    }

}