pragma solidity ^0.4.25;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;                              // Account used to deploy contract
    uint balance;                                               // Records the contract balance
    bool private operational = true;                            // Blocks all state changes throughout the contract if false
    uint private nonce = 1;                                     // Airline nonce

    uint private registeredAirlines = 0;                        // Number of airlines registered with the contract

    mapping(address => bool) private authorizedContracts;       // Mapping for contracts authorized to call data contract

    struct Registration {
        string name;
        bool registered;
        bool funded; 
        uint votes;   
    }

    mapping(address => uint) private airlines;                      // Mapping for storing airlines
    mapping(address => Registration) private registrations;         // Mapping for storing status of airline registrations

    // Registered flights
    struct Flight {
        address airline;
        string flight;
        string origin;
        uint256 departureTimestamp;
        string destination;
        uint256 arrivalTimestamp;
        uint8 statusCode;
    }

    mapping(bytes32 => Flight) private flights;

    // Flight status codees
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/

    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor
                                (
                                ) 
                                public 
    {
        contractOwner = msg.sender;
    }

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
        require(operational, "Contract is not operational");
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
    * @dev Modifier that requires the function caller to be authorized
    */
    modifier isAuthorized()
    {
        require(authorizedContracts[msg.sender] == true || msg.sender == contractOwner, "Caller is not authorized");
        _;
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
    * @dev Get operating status of contract
    *
    * @return A bool that is the current operating status
    */      
    function isOperational() 
                            public 
                            view 
                            returns(bool) 
    {
        return operational;
    }


    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */    
    function setOperatingStatus
                            (
                                bool mode
                            ) 
                            external
                            requireContractOwner 
    {
        operational = mode;
    }


    function authorizeCaller
                            (
                                address contractAddress
                            )
                            external
                            requireContractOwner
    {
        require(contractAddress != address(0), "must be a valid address.");
        require(!authorizedContracts[contractAddress], "Caller is already authorized.");
        authorizedContracts[contractAddress] = true;
    }


    function deauthorizeCaller
                            (
                                address contractAddress
                            )
                            external
                            requireContractOwner
    {
        require(contractAddress != address(0), "must be a valid address.");
        require(authorizedContracts[contractAddress] == true, "Caller has not been authorized.");
        delete authorizedContracts[contractAddress];
    }


    function getBalance
                        (
                        )
                        external
                        view
                        returns (uint)
    {
        return balance;
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

    /**
     * @dev Determines if Airline is registered
     */
    function isAirline
                        (
                            address _airline
                        )
                        external
                        view 
                        isAuthorized 
                        returns(bool)
    {
        require(_airline != address(0), "must be a valid address.");
        return (airlines[_airline] > 0) ? true : false;
    }


    /**
     * @dev Determines if Airline is registered
     */
    function isRegistered
                        (
                            address _airline
                        )
                        external
                        view 
                        isAuthorized 
                        returns(bool)
    {
        require(_airline != address(0), "must be a valid address.");
        return registrations[_airline].registered;
    }


    /**
     * @dev Determines if Airline is funded
     */
    function isFunded
                        (
                            address _airline
                        )
                        external
                        view 
                        isAuthorized 
                        returns(bool)
    {
        require(_airline != address(0), "must be a valid address.");
        return registrations[_airline].funded;
    }


    /**
     * @dev Get the number of currently registered airlines
     */
    function getRegistrationCount
                        (
                        )
                        external
                        view 
                        isAuthorized 
                        returns(uint)
    {
        return registeredAirlines;
    }


    /**
     * @dev Get the number of currently registered airlines
     */
    function getVoteCount
                        (
                            address _airline
                        )
                        external
                        view 
                        isAuthorized 
                        returns(uint)
    {
        return registrations[_airline].votes;
    }


   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */   
    function addAirline
                            (
                                address _airline,
                                string _name
                            )
                            external
                            isAuthorized
    {
        require(_airline != address(0), "must be a valid address.");
        require(airlines[_airline] == 0, "airline already added.");

        airlines[_airline] = nonce++;

        registrations[_airline] = Registration({
            registered: false,
            funded: false,
            name: _name,
            votes: 0
        });
    }


   /**
    * @dev add vote forn airline registration
    *   Returns the # of registrations in the contract
    *   and the # of votes this airline has received
    *
    */   
    function addVote
                    (
                        address _airline
                    )
                    external
                    isAuthorized
                    returns
                    (
                        uint, 
                        uint
                    )
    {
        require(_airline != address(0), "must be a valid address.");
        require(airlines[_airline] > 0, "airline not found.");

        registrations[_airline].votes++;

        // # of registered airlines and # of votes for this airline
        return(registeredAirlines, registrations[_airline].votes);
    }


    /**
    * @dev approve airline registration
    *   Marks the airline as 'registered' and increments the total number of registered airlines for the contract
    *
    */   
    function approveAirline
                    (
                        address _airline
                    )
                    external
                    isAuthorized
    {
        require(_airline != address(0), "must be a valid address.");
        require(airlines[_airline] > 0, "airline not found.");

        registrations[_airline].registered = true;
        registeredAirlines++;
    }


    /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */   
    function addFunds
                            (  
                                address _airline 
                            )
                            public
                            payable
                            isAuthorized
    {
        require(_airline != address(0), "must be a valid address.");
        require(airlines[_airline] > 0, "airline not found.");

        balance += msg.value;
        registrations[_airline].funded = true;
    }


    /**
    * @dev Add a flight to the Flight mappings
    *      Can only be called from FlightSuretyApp contract
    *
    */   
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
                            isAuthorized
                            returns(bytes32)
    {
        require(_airline != address(0), "must be a valid address.");
        require(airlines[_airline] > 0, "airline not found.");

        bytes32 flightKey = getFlightKey(_airline, _flight, _departureTimestamp, _arrivalTimestamp);

        flights[flightKey] = Flight({
            airline: _airline,
            flight: _flight,
            origin: _origin,
            departureTimestamp: _departureTimestamp,
            destination: _destination,
            arrivalTimestamp: _arrivalTimestamp,
            statusCode: STATUS_CODE_UNKNOWN
        });

        return flightKey;
    }


    /**
    * @dev Add a flight to the Flight mappings
    *      Can only be called from FlightSuretyApp contract
    *
    */   
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
                            isAuthorized
                            returns(bytes32)
    {
        require(_airline != address(0), "must be a valid address.");
        require(airlines[_airline] > 0, "airline not found.");

        bytes32 flightKey = getFlightKey(_airline, _flight, _departureTimestamp, _arrivalTimestamp);

        flights[flightKey] = Flight({
            airline: _airline,
            flight: _flight,
            origin: _origin,
            departureTimestamp: _departureTimestamp,
            destination: _destination,
            arrivalTimestamp: _arrivalTimestamp,
            statusCode: STATUS_CODE_UNKNOWN
        });

        return flightKey;
    }


    /**
    * @dev Make a unique key for the flight, which is used to look it up in the mapping
    *
    */
    function getFlightKey
                        (
                            address _airline,
                            string memory _flight,
                            uint256 _departureTimestamp,
                            uint256 _arrivalTimestamp
                        )
                        pure
                        internal
                        returns(bytes32) 
    {
        return keccak256(abi.encodePacked(_airline, _flight, _departureTimestamp, _arrivalTimestamp));
    }


   /**
    * @dev Buy insurance for a flight
    *
    */   
    function buyFlightInsurance
                            (                             
                            )
                            external
                            payable
    {

    }


    /**
     *  @dev Credits payouts to insurees
    */
    function creditFlightInsurees
                                (
                                )
                                external
                                pure
    {
    }
    

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function payFlightInsuree
                            (
                            )
                            external
                            pure
    {
    }


    /**
    * @dev Fallback function for funding smart contract.
    *
    *   Can only be called by the contract owner. The App contract will call the fund() method
    *   and pass the valid Airline account so it can be credited properly.
    *
    *   NOTE: the fallback function could be used by the contract owner to setup intial
    *   funding of the FlightSurety insurance program.
    */
    function() 
                            external 
                            payable 
                            requireContractOwner
                            requireIsOperational
    {
    }
}

