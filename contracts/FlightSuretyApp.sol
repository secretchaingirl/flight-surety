pragma solidity ^0.4.25;

// It's important to avoid vulnerabilities due to numeric overflow bugs
// OpenZeppelin's SafeMath library, when used correctly, protects agains such bugs
// More info: https://www.nccgroup.trust/us/about-us/newsroom-and-events/blog/2018/november/smart-contract-insecurity-bad-arithmetic/

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

/************************************************** */
/* FlightSurety Smart Contract                      */
/************************************************** */
contract FlightSuretyApp {
    using SafeMath for uint256; // Allow SafeMath functions to be called for all uint256 types (similar to "prototype" in Javascript)

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;  // Account used to deploy contract
    FlightSuretyData flightSuretyData;  // this is the address of the FlightSuretyData contract
    bool private testingMode = false;   // Allows authorized callers to put the contract in testing mode
 
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
    modifier requireIsOperational() 
    {
        require(isOperational(), "Contract is not operational");
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
    modifier requireIsAirline()
    {
        require(flightSuretyData.isAirline(msg.sender), "Caller is not a valid Airline.");
        _;
    }


    /**
    * @dev Modifier that requires the function caller to be a Registered Airline
    */
    modifier requireIsRegistered()
    {
        require(flightSuretyData.isRegistered(msg.sender), "Caller is not a registered Airline.");
        _;
    }


    /**
    * @dev Modifier that requires the "Registered Airline" account to be funded
    *       Airlines can be registered, but cannot participate in the 
    *       contract unless they've provided funding of at least 10 ether
    */
    modifier requireIsFunded()
    {
        require
            (
                flightSuretyData.isFunded(msg.sender) == true, 
                "Airline cannot participate due to lack of funding (10 ether required)."
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
                                    address _dataContractAddress
                                ) 
                                public 
    {
        // Set the contract owner
        contractOwner = msg.sender;

        // Set reference to the Data contract
        flightSuretyData = FlightSuretyData(_dataContractAddress);
    }


    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
    * @dev Function that determines if the Contract is OPERATIONAL
    */
    function isOperational() 
                            public 
                            view 
                            returns(bool) 
    {
        return flightSuretyData.isOperational();
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
                            requireIsOperational
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
                            )
                            public
                            payable
                            requireIsAirline
    {
        require(msg.value >= 10 ether, "Funding requires at least 10 ether.");

        // send funds to data contract
        //  Pass msg.sender so the airline can be credited with the funds
        flightSuretyData.addFunds.value(msg.value)(msg.sender);
    }


   /**
    * @dev Add an airline to the registration queue
    *
    */   
    function registerAirline
                    (
                        address account,
                        string name
                    )
                    external
                    requireIsOperational
                    requireIsAirline
                    requireIsRegistered
                    requireIsFunded
                    returns(bool)
    {
        flightSuretyData.addAirline(account, name);

        return(
            address(this).delegatecall(
                bytes4(keccak256("voteForAirline(address)")), 
                account
            )
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
                requireIsOperational
                requireIsAirline
                requireIsRegistered
                requireIsFunded
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
        if (registrations < 5 || ((votes * 2) >= registrations)) {
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
                            string flight,
                            string origin,
                            string departure,
                            string destination,
                            string arrival
                        )
                        external
                        requireIsOperational
                        requireIsAirline
                        requireIsRegistered
                        requireIsFunded
                        returns(bool)
    {
        return(true);
    }
    
   /**
    * @dev Called after oracle has updated flight status
    *
    */  
    function processFlightStatus
                                (
                                    address airline,
                                    string memory flight,
                                    uint256 timestamp,
                                    uint8 statusCode
                                )
                                internal
                                view
                                requireIsFunded
    {
    }


    // Generate a request for oracles to fetch flight information
    function fetchFlightStatus
                        (
                            address airline,
                            string flight,
                            uint256 timestamp                            
                        )
                        external
                        requireIsFunded
    {
        uint8 index = getRandomIndex(msg.sender);

        // Generate a unique key for storing the request
        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp));
        oracleResponses[key] = ResponseInfo({
                                                requester: msg.sender,
                                                isOpen: true
                                            });

        emit OracleRequest(index, airline, flight, timestamp);
    } 


// region ORACLE MANAGEMENT

    // Incremented to add pseudo-randomness at various points
    uint8 private nonce = 0;    

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
    // Key = hash(index, flight, timestamp)
    mapping(bytes32 => ResponseInfo) private oracleResponses;

    // Event fired each time an oracle submits a response
    event FlightStatusInfo(address airline, string flight, uint256 timestamp, uint8 status);

    event OracleReport(address airline, string flight, uint256 timestamp, uint8 status);

    // Event fired when flight status request is submitted
    // Oracles track this and if they have a matching index
    // they fetch data and submit a response
    event OracleRequest(uint8 index, address airline, string flight, uint256 timestamp);


    // Register an oracle with the contract
    function registerOracle
                            (
                            )
                            external
                            payable
    {
        // Require registration fee
        require(msg.value >= REGISTRATION_FEE, "Registration fee is required");

        uint8[3] memory indexes = generateIndexes(msg.sender);

        oracles[msg.sender] = Oracle({
                                        isRegistered: true,
                                        indexes: indexes
                                    });
    }

    function getMyIndexes
                            (
                            )
                            view
                            external
                            returns(uint8[3])
    {
        require(oracles[msg.sender].isRegistered, "Not registered as an oracle");

        return oracles[msg.sender].indexes;
    }




    // Called by oracle when a response is available to an outstanding request
    // For the response to be accepted, there must be a pending request that is open
    // and matches one of the three Indexes randomly assigned to the oracle at the
    // time of registration (i.e. uninvited oracles are not welcome)
    function submitOracleResponse
                        (
                            uint8 index,
                            address airline,
                            string flight,
                            uint256 timestamp,
                            uint8 statusCode
                        )
                        external
    {
        require((oracles[msg.sender].indexes[0] == index) || (oracles[msg.sender].indexes[1] == index) || (oracles[msg.sender].indexes[2] == index), "Index does not match oracle request");


        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp)); 
        require(oracleResponses[key].isOpen, "Flight or timestamp do not match oracle request");

        oracleResponses[key].responses[statusCode].push(msg.sender);

        // Information isn't considered verified until at least MIN_RESPONSES
        // oracles respond with the *** same *** information
        emit OracleReport(airline, flight, timestamp, statusCode);
        if (oracleResponses[key].responses[statusCode].length >= MIN_RESPONSES) {

            emit FlightStatusInfo(airline, flight, timestamp, statusCode);

            // Handle flight status as appropriate
            processFlightStatus(airline, flight, timestamp, statusCode);
        }
    }


    function getFlightKey
                        (
                            address airline,
                            string flight,
                            uint256 timestamp
                        )
                        pure
                        internal
                        returns(bytes32) 
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    // Returns array of three non-duplicating integers from 0-9
    function generateIndexes
                            (                       
                                address account         
                            )
                            internal
                            returns(uint8[3])
    {
        uint8[3] memory indexes;
        indexes[0] = getRandomIndex(account);
        
        indexes[1] = indexes[0];
        while(indexes[1] == indexes[0]) {
            indexes[1] = getRandomIndex(account);
        }

        indexes[2] = indexes[1];
        while((indexes[2] == indexes[0]) || (indexes[2] == indexes[1])) {
            indexes[2] = getRandomIndex(account);
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
        uint8 random = uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - nonce++), account))) % maxValue);

        if (nonce > 250) {
            nonce = 0;  // Can only fetch blockhashes for last 256 blocks so we adapt
        }

        return random;
    }

// endregion

    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    function() 
                            external 
                            payable 
                            requireIsOperational
    {
        fundAirline();
    }
}

// Define the data contract interface

contract FlightSuretyData {
    function isOperational() public view returns(bool);

    //
    // Airline operations
    //

    function isAirline(address airline) external view returns(bool);
    function isRegistered(address airline) external view returns(bool);
    function isFunded(address airline) external view returns(bool);

    function addAirline(address airline, string name) external;
    function addVote(address airline) external returns(uint, uint);
    function approveAirline(address airline) external;
    function addFunds(address airline) public payable;

    function addFlight
                    (
                        address _airline, 
                        string _flight, 
                        string _origin, 
                        uint256 _departureTimestamp, 
                        string _destination, 
                        uint256 _arrivalTimestamp
                    )
                    external
                    returns(bytes32);
}
