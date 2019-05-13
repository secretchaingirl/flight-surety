pragma solidity ^0.5.8;

// To enable ability to return Flight struct in memory
// TODO: DO NOT use in production deployment
pragma experimental ABIEncoderV2;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./FlightSuretyLibrary.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;                              // Account used to deploy contract
    bool private operational = true;                            // Blocks all state changes throughout the contract if false

    uint balance;                                               // Records the contract balance

    uint private registeredAirlines = 0;                        // Number of airlines registered with the contract
    uint private airlineNonce = 1;                              // Starting airline nonce

    mapping(address => bool) private authorizedContracts;       // Mapping for contracts authorized to call data contract

    // Airline info which includes mapping for associated flights
    struct Airline {
        uint nonce;                                             // Airline nonce or unique #
        string name;
        bool registered;
        bool funded;
        uint votes;
        uint flightNonce;                                       // to keep track of current # of registered flights for the Airline
        mapping(uint => bytes32) flightKeys;                    // mapping for flight index to flight key
        mapping(bytes32 => FlightSuretyLibrary.Flight) flights;
    }

    // Mapping for airline account and all relevant info, including flights
    //      Airline => Airline Struct
    //
    mapping(address => Airline) private airlines;

    // Mapping for flight insurees
    //      Passenger => (Airline => (Flight => Flight Insurance))
    mapping(address => mapping(address => mapping(bytes32 => FlightSuretyLibrary.FlightInsurance))) private insurees;

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

        // Add our self to authorized contracts for calling methods that are 'external'
        authorizedContracts[address(this)] = true;
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
        return (airlines[_airline].nonce > 0) ? true : false;
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
        return airlines[_airline].registered;
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
        require(airlines[_airline].nonce > 0, "airline not found.");

        return airlines[_airline].funded;
    }


    /**
     * @dev Determines if Flight has been registered to Airline
     */
    function isFlight
                        (
                            address _airline,
                            bytes32 _flightKey
                        )
                        external
                        view
                        isAuthorized
                        returns(bool)
    {
        require(_airline != address(0), "must be a valid address.");
        require(airlines[_airline].nonce > 0, "airline not found.");

        return (airlines[_airline].flights[_flightKey].nonce > 0);
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
        return airlines[_airline].votes;
    }


   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */
    function addAirline
                            (
                                address _airline,
                                string calldata _name
                            )
                            external
                            isAuthorized
    {
        require(_airline != address(0), "must be a valid address.");
        require(airlines[_airline].nonce == 0, "airline already added.");

        airlines[_airline] = Airline({
                                nonce: airlineNonce++,
                                name: _name,
                                registered: false,
                                funded: false,
                                votes: 0,
                                flightNonce: 0
                            });
    }


   /**
    * @dev add vote for an airline registration
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
        require(airlines[_airline].nonce > 0, "airline not found.");

        airlines[_airline].votes++;

        // # of registered airlines and # of votes for this airline
        return(registeredAirlines, airlines[_airline].votes);
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
        require(airlines[_airline].nonce > 0, "airline not found.");

        airlines[_airline].registered = true;
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
        require(airlines[_airline].nonce > 0, "airline not found.");

        balance += msg.value;
        airlines[_airline].funded = true;
    }


    /**
    * @dev Add a flight to the Flight mappings
    *      Can only be called from FlightSuretyApp contract
    *
    */
    function addFlight
                            (
                                address airline,
                                string calldata _code,
                                string calldata _origin,
                                uint256 _departureTimestamp,
                                string calldata _destination,
                                uint256 _arrivalTimestamp
                            )
                            external
                            isAuthorized
                            returns(uint _nonce, bytes32 _key)
    {
        require(airline != address(0), "must be a valid address.");
        require(airlines[airline].nonce > 0, "airline not found.");

        _key = this.createFlightKey(airline, _code, _departureTimestamp, _arrivalTimestamp);

        _nonce = ++airlines[airline].flightNonce;

        airlines[airline].flightKeys[_nonce] = _key;

        airlines[airline].flights[_key] = FlightSuretyLibrary.Flight({
                                                    nonce: _nonce,
                                                    key: _key,
                                                    code: _code,
                                                    origin: _origin,
                                                    departureTimestamp: _departureTimestamp,
                                                    destination: _destination,
                                                    arrivalTimestamp: _arrivalTimestamp,
                                                    statusCode: STATUS_CODE_UNKNOWN
                                                });
    }


    /**
    * @dev Create a unique key for the flight, which is used to look it up in the mapping
    *
    */
    function createFlightKey
                        (
                            address airline,
                            string calldata code,
                            uint256 departureTimestamp,
                            uint256 arrivalTimestamp
                        )
                        external
                        view
                        isAuthorized
                        returns(bytes32)
    {
        require(airline != address(0), "must be a valid address.");

        return keccak256(abi.encodePacked(airline, code, departureTimestamp, arrivalTimestamp));
    }


    /**
    * @dev Return 1st Airline flight
    *
    */
    function getFlight
                        (
                            address airline,
                            bytes32 key
                        )
                        external
                        view
                        isAuthorized
                        returns(FlightSuretyLibrary.Flight memory flightInfo)
    {
        require(airline != address(0), "must be a valid address.");
        require(airlines[airline].nonce > 0, "airline not found.");
        require(airlines[airline].flights[key].nonce > 0, "not a valid flight key.");

        return airlines[airline].flights[key];
    }

    /**
    * @dev Get # of flights for Airline
    *
    */
    function getFlightNonce
                        (
                            address airline
                        )
                        external
                        view
                        isAuthorized
                        returns(uint)
    {
        require(airline != address(0), "must be a valid address.");
        require(airlines[airline].nonce > 0, "airline not found.");

        return airlines[airline].flightNonce;
    }

    /**
    * @dev Given a nonce, return the Flight Key
    *
    */
    function getFlightKey
                        (
                            address airline,
                            uint nonce
                        )
                        external
                        view
                        isAuthorized
                        returns(bytes32)
    {
        require(airline != address(0), "must be a valid address.");
        require(airlines[airline].nonce > 0, "airline not found.");
        require(nonce > 0 && nonce <= airlines[airline].flightNonce, "flight nonce out of range.");

        return airlines[airline].flightKeys[nonce];
    }

    /**
    * @dev Return 1st five Airline flights
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
                        isAuthorized
                        returns(FlightSuretyLibrary.Flight[] memory)
    {
        require(airline != address(0), "must be a valid address.");
        require(airlines[airline].nonce > 0, "airline not found.");
        require(startNonce > 0 && startNonce <= airlines[airline].flightNonce, "flight start nonce out of range.");
        require(startNonce < endNonce, "flight start nonce must be < end nonce.");
        require(endNonce > 0 && endNonce <= airlines[airline].flightNonce, "flight end nonce out of range.");

        FlightSuretyLibrary.Flight[] memory flightList = new FlightSuretyLibrary.Flight[](endNonce - startNonce + 1);

        uint8 index = 0;
        for (uint nonce = startNonce; nonce <= endNonce; nonce++) {
            bytes32 key = airlines[airline].flightKeys[nonce];
            flightList[index++] = airlines[airline].flights[key];
        }

        return flightList;
    }


   /**
    * @dev Buy insurance for a flight
    *
    */
    function buyFlightInsurance
                            (
                                address airline,
                                bytes32 key,
                                address passenger
                            )
                            external
                            payable
                            isAuthorized
    {
        require(airline != address(0), "must be a valid airline address.");
        require(airlines[airline].nonce > 0, "airline not found.");
        require(passenger != address(0), "passenger account must be a valid address");

        balance += msg.value;

        // Add flight insurance for passenger
        insurees[passenger][airline][key] = FlightSuretyLibrary.FlightInsurance({
            purchased: msg.value,
            payout: 0,
            isInsured: true,
            isCredited: false,
            isWithdrawn: false
        });
    }


    /**
     *  @dev Credits payouts to insurees
    */
    function getPassengerInsurance
                                (
                                    address passenger,
                                    address airline,
                                    bytes32 key
                                )
                                external
                                view
                                isAuthorized
                                returns(FlightSuretyLibrary.FlightInsurance memory insurance)
    {
        require(airline != address(0), "must be a valid airline address.");
        require(airlines[airline].nonce > 0, "airline not found.");
        require(airlines[airline].flights[key].nonce > 0, "not a valid flight key.");
        require(passenger != address(0), "passenger account must be a valid address");
        require(insurees[passenger][airline][key].purchased > 0, "passenger hasn't purchased insurance for requested flight.");

        return insurees[passenger][airline][key];
    }


    /**
     *  @dev Credits payouts to insurees
    */
    function creditFlightInsurees
                                (
                                )
                                external
                                view
                                isAuthorized
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
                            view
                            isAuthorized
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

