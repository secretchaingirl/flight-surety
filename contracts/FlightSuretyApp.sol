pragma solidity ^0.5.8;

// Needed to work with Flight struct as returned memory argument for FlightSuretyData.getFlight() call
pragma experimental ABIEncoderV2;

// It's important to avoid vulnerabilities due to numeric overflow bugs
// OpenZeppelin's SafeMath library, when used correctly, protects agains such bugs
// More info: https://www.nccgroup.trust/us/about-us/newsroom-and-events/blog/2018/november/smart-contract-insecurity-bad-arithmetic/

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./FlightSuretyLib.sol";

/************************************************** */
/* FlightSurety Smart Contract                      */
/************************************************** */
contract FlightSuretyApp {

    using SafeMath for uint256; // Allow SafeMath functions to be called for all uint256 types (similar to "prototype" in Javascript)

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;      // Account used to deploy contract
    FlightSuretyData flightSuretyData;  // this is the address of the FlightSuretyData contract
    bool private testingMode = false;   // Allows authorized callers to put the contract in testing mode
    uint private balance = 0;           // Contract balance

    // Maximum number of flights to be retrieved by Contract
    uint8 private constant GET_FLIGHTS_MAX = 5;

    // Mapping for flight status codes
    mapping(uint8 => string) private flightStatusCodes;

    using FlightSuretyLib for FlightSuretyLib.FlightSurety;
    FlightSuretyLib.FlightSurety private flightSurety;

    /********************************************************************************************/
    /*                                       EVENTS                                             */
    /********************************************************************************************/

    event FlightRegistered
                        (
                            address airline,
                            uint nonce,
                            bytes32 key
                        );

    event FlightInsurancePurchased
                            (
                                address passenger,
                                address airline,
                                bytes32 key,
                                uint amount
                            );

    event FlightDelayed(address airline, bytes32 key);

    event InsuredPassengerPayout
                            (
                                address airline,
                                bytes32 key,
                                address passenger,
                                uint amountToPayout
                            );

    event PassengerInsuranceWithdrawal(address passenger, uint amountWithdrawn);

    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
    * @dev Modifier that requires the "operational" boolean variable to be "true"
    *      This is used on all state changing functions to pause the contract in
    *      the event there is an issue that needs to be fixed
    */
    modifier requireOperational()
    {
        require(flightSuretyData.isOperational(), "Contract is not operational");
        _;
    }


    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }


    /**
    * @dev Modifier that requires the function caller to be an Airline
    */
    modifier requireAirline()
    {
        require(flightSuretyData.isAirline(msg.sender), "Caller is not a valid Airline.");
        _;
    }


    /**
    * @dev Modifier that requires the function caller to be a Registered Airline
    */
    modifier requireRegistered()
    {
        require(flightSuretyData.isRegistered(msg.sender), "Caller is not a registered Airline.");
        _;
    }


    /**
    * @dev Modifier that requires the "Registered Airline" account to be funded
    *       Airlines can be registered, but cannot participate in the
    *       contract unless they've provided funding of at least 10 ether
    */
    modifier requireFunded()
    {
        require
            (
                flightSuretyData.isFunded(msg.sender) == true,
                "Airline cannot participate due to lack of funding (10 ether required)."
            );
        _;
    }


    /**
    * @dev Modifier that requires the "Registered Airline" account to be funded
    *       Airlines can be registered, but cannot participate in the
    *       contract unless they've provided funding of at least 10 ether
    */
    modifier requireFlight(address airline, bytes32 key)
    {
        require
            (
                flightSuretyData.isFlight(airline, key) == true,
                "Specified Flight Key is not valid."
            );
        _;
    }


    /**
    * @dev Modifier that requires the Flight Status code to be valid
    */
    modifier requireFlightStatus(uint8 status)
    {
        require
            (
                status == FlightSuretyLib.STATUS_CODE_UNKNOWN() ||
                status == FlightSuretyLib.STATUS_CODE_ON_TIME() ||
                status == FlightSuretyLib.STATUS_CODE_LATE_AIRLINE() ||
                status == FlightSuretyLib.STATUS_CODE_LATE_WEATHER() ||
                status == FlightSuretyLib.STATUS_CODE_LATE_TECHNICAL() ||
                status == FlightSuretyLib.STATUS_CODE_LATE_OTHER(),
                "Invalid Flight Status code."
            );
        _;
    }


    /********************************************************************************************/
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/

    /**
    * @dev Contract constructor
    *
    */
    constructor
                                (
                                    address dataContractAddress
                                )
                                public
    {
        // Set the contract owner
        contractOwner = msg.sender;

        // Setup flight status code mappings
        flightStatusCodes[FlightSuretyLib.STATUS_CODE_UNKNOWN()] = "Unknown";
        flightStatusCodes[FlightSuretyLib.STATUS_CODE_ON_TIME()] = "On Time";
        flightStatusCodes[FlightSuretyLib.STATUS_CODE_LATE_AIRLINE()] = "Late Airline";
        flightStatusCodes[FlightSuretyLib.STATUS_CODE_LATE_WEATHER()] = "Late Weather";
        flightStatusCodes[FlightSuretyLib.STATUS_CODE_LATE_TECHNICAL()] = "Late Technical";
        flightStatusCodes[FlightSuretyLib.STATUS_CODE_LATE_OTHER()] = "Late Other";

        // Set reference to the Data contract
        flightSuretyData = FlightSuretyData(dataContractAddress);
    }


    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
    * @dev Determine if FlightSuretyData contract is operational
    */
    function isOperational() external view returns(bool)
    {
        bool operational = flightSuretyData.isOperational();
        return(operational);
    }

    /**
    * @dev Determine if FlightSuretyData contract is operational
    */
    function getBalance() external view returns(uint)
    {
        return(flightSuretyData.getBalance());
    }

    /**
    * @dev Allows the Contract to be put in Testing mode
    */
    function setTestingMode
                            (
                                bool _testingMode
                            )
                            external
                            requireContractOwner
                            requireOperational
    {
        testingMode = _testingMode;
    }


    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

  /**
    * @dev Allows calling Airline to provide funding and be able to participate in the contract.
    *   This method implements a business rule:
    *       funding >= 10 ether
    *
    */
    function fundAirline
                    (
                        uint fundAmount
                    )
                    public
                    payable
                    requireOperational
                    requireAirline
    {
        require(msg.value >= 10 ether, "Funding requires at least 10 ether.");
        require(msg.value == fundAmount, "Funding amount must match transaction value.");

        address airline = msg.sender;

        // send funds to data contract
        //  Pass msg.sender so the airline can be credited with the funds
        flightSuretyData.addFunds.value(msg.value)(airline);
    }


   /**
    * @dev Add an airline to the registration queue
    *
    */
    function registerAirline
                    (
                        address account,
                        string calldata name
                    )
                    external
                    requireOperational
                    requireAirline
                    requireRegistered
                    requireFunded
                    returns(bool success, bytes memory data)
    {
        flightSuretyData.addAirline(account, name);

        // Call voteForAirline() as callee of registerAirline()
        return address(this).delegatecall
                                    (
                                        abi.encodeWithSignature("voteForAirline(address)", account)
                                    );
    }


    /**
    * @dev Multi-party Consensus requires 50% consensus to register an airline
    *   Registered airlines submit a vote and approval is triggered when M of N is satisfied
    *
    */
    function voteForAirline
                (
                    address account
                )
                external
                requireOperational
                requireAirline
                requireRegistered
                requireFunded
                returns(bool)
    {
        require(flightSuretyData.isAirline(account) == true, "Can't vote for Airline that doesn't exist.");
        require(flightSuretyData.isRegistered(account) == false, "Can't vote for Airline that's already been registered.");

        uint registrations;
        uint votes;

        (registrations, votes) = flightSuretyData.addVote(account);

        // Approve the registration is there are less than 5 airlines currently registered
        //  OR
        // When the airline has received 50% of the vote
        if (registrations < 5 || ((votes.mul(2)) >= registrations)) {
            flightSuretyData.approveAirline(account);
            return(true);
        }
        return(false);
    }


   /**
    * @dev Register a future flight for insuring.
    *
    */
    function registerFlight
                        (
                            string calldata code,
                            string calldata origin,
                            uint256 departure,
                            string calldata destination,
                            uint256 arrival
                        )
                        external
                        requireOperational
                        requireAirline
                        requireRegistered
                        requireFunded
    {
        address airline = msg.sender;
        uint nonce;
        bytes32 key;

        (nonce, key) = flightSuretyData.addFlight
                                (
                                    airline,
                                    code,
                                    origin,
                                    departure,
                                    destination,
                                    arrival
                                );

        emit FlightRegistered(airline, nonce, key);
    }

    /**
    * @dev Get registered Flights (only returns the 1st five).
    *
    * TODO: modify to use startIndex and count, up to 20 at a time for paging in a dApp
    *
    */
    function getFlightList
                        (
                            address airline,
                            uint startNonce,
                            uint endNonce
                        )
                        external
                        view
                        requireOperational
                        returns(FlightSuretyLib.Flight[] memory)
    {
        require(flightSuretyData.isAirline(airline), "not a valid airline.");

        uint flightNonce = flightSuretyData.getFlightNonce(airline);

        require(startNonce > 0 && startNonce <= flightNonce, "flight start nonce out of range.");
        require(endNonce > 0 && endNonce <= flightNonce, "flight end nonce out of range.");
        require(startNonce <= endNonce, "flight start nonce must be less than or equal to the end nonce.");
        require(endNonce.sub(startNonce) <= GET_FLIGHTS_MAX, "# of flights requested exceeds max.");

        return flightSuretyData.getFlightList(airline, startNonce, endNonce);
    }


    /**
    * @dev Allows calling Passenger to purchase flight insurance.
    *   This method implements a business rule:
    *       insurance <= 1 ether
    *
    */
    function buyFlightInsurance
                            (
                                address airline,
                                bytes32 key,
                                uint amount
                            )
                            public
                            payable
                            requireOperational
                            requireFlight(airline, key)
    {
        FlightSuretyLib.FlightInsurance memory insurance = flightSuretyData.getPassengerInsurance(airline, key, msg.sender);
        require(insurance.isInsured == false, "Passenger has already purchased insurance for this flight.");
        require(msg.value == amount, "Not enough funds to purchase insurance amount requested.");
        require(msg.value <= 1 ether, "Maximum allow insurance amount is 1 ether.");

        // Pass msg.sender so the passenger can be credited with the insurance purchase and added to the insurees
        address passenger = msg.sender;

        // send funds to data contract
        flightSuretyData.buyFlightInsurance.value(amount)(airline, key, passenger);

        emit FlightInsurancePurchased(passenger, airline, key, amount);
    }


   /**
    * @dev Called after oracle has updated flight status and handles 'late' airline flights and insurance payouts
    *
    */
    function processFlightStatus
                                (
                                    address airline,
                                    bytes32 key,
                                    uint8 statusCode
                                )
                                internal
                                requireOperational
                                requireFlight(airline, key)
    {
        if (statusCode != FlightSuretyLib.STATUS_CODE_UNKNOWN() && statusCode != FlightSuretyLib.STATUS_CODE_ON_TIME()) {

            emit FlightDelayed(airline, key);

            address[] memory passengers;

            passengers = flightSuretyData.getInsuredPassengers(airline, key);
            for (uint i = 0; i < passengers.length; i++) {
                FlightSuretyLib.FlightInsurance memory insurance;
                uint amountToPayout;

                insurance = flightSuretyData.getPassengerInsurance(airline, key, passengers[i]);

                // Only credit passenger for this flight if not already done
                if (insurance.isCredited == false) {
                    amountToPayout = insurance.purchased.add(insurance.purchased.div(2));

                    flightSuretyData.creditFlightInsuree(airline, key, passengers[i], amountToPayout);

                    // Emit the payout event so passenger can do the withdraw
                    emit InsuredPassengerPayout(airline, key, passengers[i], amountToPayout);
                }
            }
        }
    }


    /**
    * @dev After payout, insured passenger issues the withdraw request to get the payout in their wallet
    *
    */
    function payFlightInsuree
                                (
                                    address airline,
                                    bytes32 key,
                                    address payable passenger
                                )
                                external
                                payable
                                requireOperational
                                requireFlight(airline, key)
    {
        uint amountWithdrawn = flightSuretyData.payFlightInsuree(airline, key, passenger);

        emit PassengerInsuranceWithdrawal(passenger, amountWithdrawn);
    }


    // Generate a request for oracles to fetch flight information
    function fetchFlightStatus
                        (
                            address airline,
                            bytes32 key,
                            uint256 timestamp
                        )
                        external
                        requireOperational
    {
        require(flightSuretyData.isFlight(airline, key), "Flight does not exist.");

        uint8[3] memory indexes = generateIndexes(msg.sender);

        oracleResponses[key] = ResponseInfo({
                                                requester: msg.sender,
                                                isOpen: true
                                            });

        emit OracleRequest(indexes, airline, key, timestamp);
    }


// region ORACLE MANAGEMENT

    // Incremented to add pseudo-randomness at various points
    uint8 private oracleNonce;
    uint private oracleBalance = 0;

    // Fee to be paid when registering oracle
    uint256 public constant REGISTRATION_FEE = 1 ether;

    // Number of oracles that must respond for valid status
    uint256 private constant MIN_RESPONSES = 3;

    struct Oracle {
        bool isRegistered;
        uint8[3] indexes;
    }

    // Track all registered oracles
    mapping(address => Oracle) private oracles;

    // Model for responses from oracles
    struct ResponseInfo {
        address requester;                              // Account that requested status
        bool isOpen;                                    // If open, oracle responses are accepted
        mapping(uint8 => address[]) responses;          // Mapping key is the status code reported
                                                        // This lets us group responses and identify
                                                        // the response that majority of the oracles
    }

    // Track all oracle responses
    // Flight Key => Oracle ResponseInfo
    mapping(bytes32 => ResponseInfo) private oracleResponses;

    // Event is fired when the minimum Oracle responses are received and a flight status update can be issued
    event FlightStatusInfo(address airline, bytes32 key, uint256 timestamp, uint8 statusCode, string status);

    // Event fired each time an oracle submits a response
    event OracleReport(address airline, bytes32 key, uint256 timestamp, uint8 statusCode, string status);

    // Event fired when flight status request is submitted
    // Oracles track this and if they have a matching index
    // they fetch data and submit a response
    event OracleRequest(uint8[3] indexes, address airline, bytes32 key, uint256 timestamp);

    // Event that fires when an Oracle registers
    event OracleRegistered(address oracle, uint8 index1, uint8 index2, uint8 index3);


    // Register an oracle with the contract
    function registerOracle
                            (
                            )
                            external
                            payable
    {
        // Require registration fee
        require(msg.value >= REGISTRATION_FEE, "Registration fee is required");

        oracleBalance = oracleBalance.add(msg.value);

        uint8[3] memory indexes = generateIndexes(msg.sender);

        oracles[msg.sender] = Oracle({
                                        isRegistered: true,
                                        indexes: indexes
                                    });

        emit OracleRegistered(msg.sender, indexes[0], indexes[1], indexes[2]);
    }

    function getMyIndexes
                            (
                            )
                            external
                            view
                            returns(uint8[3] memory)
    {
        require(oracles[msg.sender].isRegistered, "Not registered as an oracle");

        return oracles[msg.sender].indexes;
    }


    // Called by oracle when a response is available to an outstanding request
    // For the response to be accepted, there must be a pending request that is open
    // and matches all three Indexes randomly assigned to the oracle at the
    // time of registration (i.e. uninvited oracles are not welcome)
    function submitOracleResponse
                        (
                            uint8[3] calldata indexes,
                            address airline,
                            bytes32 key,
                            uint256 timestamp,
                            uint8 statusCode
                        )
                        external
                        //requireFlightStatus(statusCode)
    {
        require((
            oracles[msg.sender].indexes[0] == indexes[0]) &&
            (oracles[msg.sender].indexes[1] == indexes[1]) &&
            (oracles[msg.sender].indexes[2] == indexes[2]),
            "Oracle index is not valid."
        );
        require(oracleResponses[key].isOpen, "Oracle request for flight doesn't exist.");

        oracleResponses[key].responses[statusCode].push(msg.sender);

        // Information isn't considered verified until at least MIN_RESPONSES
        // oracles respond with the *** same *** information
        // When consensus is reached on flight status, close the oracle flight status request

        emit OracleReport(airline, key, timestamp, statusCode, flightStatusCodes[statusCode]);

        if (oracleResponses[key].responses[statusCode].length >= MIN_RESPONSES) {

            // Close the flight status request
            oracleResponses[key].isOpen = false;

            // Remove the flight key oracle responses
            delete oracleResponses[key].responses[FlightSuretyLib.STATUS_CODE_UNKNOWN()];
            delete oracleResponses[key].responses[FlightSuretyLib.STATUS_CODE_ON_TIME()];
            delete oracleResponses[key].responses[FlightSuretyLib.STATUS_CODE_LATE_AIRLINE()];
            delete oracleResponses[key].responses[FlightSuretyLib.STATUS_CODE_LATE_WEATHER()];
            delete oracleResponses[key].responses[FlightSuretyLib.STATUS_CODE_LATE_TECHNICAL()];
            delete oracleResponses[key].responses[FlightSuretyLib.STATUS_CODE_LATE_OTHER()];

            emit FlightStatusInfo(airline, key, timestamp, statusCode, flightStatusCodes[statusCode]);

            // Handle flight status as appropriate
            processFlightStatus(airline, key, statusCode);
        }
    }


    // Returns array of three non-duplicating integers from 0-9
    function generateIndexes
                            (
                                address account
                            )
                            internal
                            returns(uint8[3] memory)
    {
        uint8[3] memory indexes;
        uint8 index;

        oracleNonce = 0;

        indexes[0] = getRandomIndex(account);

        indexes[1] = indexes[0];
        while(indexes[1] == indexes[0]) {
            indexes[1] = getRandomIndex(account);
        }

        indexes[2] = indexes[1];
        while((indexes[2] == indexes[0]) || (indexes[2] == indexes[1])) {
            indexes[2] = getRandomIndex(account);
        }

        index = indexes[0];
        while (indexes[0] == index) {
            indexes[0] = getRandomIndex(account);
        }

        return indexes;
    }


    // Returns array of three non-duplicating integers from 0-9
    function getRandomIndex
                            (
                                address account
                            )
                            internal
                            returns (uint8)
    {
        uint8 maxValue = 10;

        // Pseudo random number...the incrementing nonce adds variation
        uint8 random = uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - oracleNonce++), account))) % maxValue);

        if (oracleNonce > 250) {
            oracleNonce = 0;  // Can only fetch blockhashes for last 256 blocks so we adapt
        }

        return random;
    }

// endregion

}

// Define the data contract interface

contract FlightSuretyData {

    function isOperational() public view returns(bool);
    function getBalance() external view returns (uint);

    //
    // Airline operations
    //

    function isAirline(address airline) external view returns(bool);
    function isRegistered(address airline) external view returns(bool);
    function isFunded(address airline) external view returns(bool);

    function addAirline(address airline, string calldata name) external;
    function addVote(address airline) external returns(uint, uint);
    function approveAirline(address airline) external;
    function addFunds(address airline) public payable;

    //
    // Flight operations
    //

    function createFlightKey
                        (
                            address airline,
                            string calldata code,
                            uint256 departureTimestamp,
                            uint256 arrivalTimestamp
                        )
                        external
                        view
                        returns(bytes32);

    function addFlight
                    (
                        address airline,
                        string calldata code,
                        string calldata origin,
                        uint256 departureTimestamp,
                        string calldata destination,
                        uint256 arrivalTimestamp
                    )
                    external
                    returns(uint nonce, bytes32 key);

    function isFlight(address airline, bytes32 key) external returns(bool);
    function getFlight(address airline, bytes32 key) external returns(FlightSuretyLib.Flight memory flightInfo);
    function getFlightKey(address airline, uint nonce) external returns(bytes32);
    function getFlightNonce(address airline) external view returns(uint);
    function getFlightList
                        (
                            address airline,
                            uint startNonce,
                            uint endNonce
                        )
                        external
                        view
                        returns(FlightSuretyLib.Flight[] memory flightList);

    function buyFlightInsurance
                            (
                                address airline,
                                bytes32 key,
                                address passenger
                            )
                            external
                            payable;

    function getPassengerInsurance
                                (
                                    address airline,
                                    bytes32 key,
                                    address passenger
                                )
                                external
                                view
                                returns(FlightSuretyLib.FlightInsurance memory insuree);

    function getInsuredPassengers
                            (
                                address airline,
                                bytes32 key
                            )
                            external
                            view
                            returns(address[] memory passengers);

    function creditFlightInsuree
                                (
                                    address airline,
                                    bytes32 key,
                                    address passenger,
                                    uint amountToPayout
                                )
                                external;

    function payFlightInsuree
                            (
                                address airline,
                                bytes32 key,
                                address payable passenger
                            )
                            external
                            returns(uint);
}

